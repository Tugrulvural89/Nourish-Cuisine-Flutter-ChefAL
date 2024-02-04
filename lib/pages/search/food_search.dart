import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:localization/localization.dart';
import 'package:translator/translator.dart';
import '../../bloc/authentication/authentication_bloc.dart';
import '../../helpers/ad_helper.dart';
import '../../helpers/translation_helper.dart';
import '../../services/revenuecat_api.dart';
import '../../widgets/custom_bottombar.dart';
import '../../widgets/info_popup.dart';

class FoodSearch extends StatefulWidget {
  const FoodSearch({super.key});

  @override
  _FoodSearchState createState() => _FoodSearchState();
}

class _FoodSearchState extends State<FoodSearch> {
  BannerAd? _bannerAd;
  List<String> suggestions = [];
  String selectedFood = '';
  Map<String, dynamic> foodDetails = {};
  bool showNutrients = true;
  bool isLoggedIn = false;

  String baseUrlApi = 'https://api.edamam.com';

  Future<dynamic> fetchDataFromAPI(String apiUrl) async {
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
  }

  final translator = GoogleTranslator();

  Future<List<String>> fetchSuggestions(String query, String lang) async {
    var searchTranslated = query;
    if (lang == 'en') {
    } else {
      var translation = await translator.translate(query, from: lang);
      searchTranslated = translation.toString();
    }

    var apiKey = dotenv.get('EDANAMAPIFOODKEY');
    var apiId = dotenv.get('EDANAMAPIFOODID');

    final apiUrl =
        '$baseUrlApi/auto-complete?q=$searchTranslated&app_id=$apiId&app_key=$apiKey';

    final jsonResponse = await fetchDataFromAPI(apiUrl);

    if (lang == 'en') {
      return List<String>.from(jsonResponse);
    } else {
      var translationFuturesInput = <Future<String>>[];
      for (var item in jsonResponse) {
        var translation =
            await translator.translate(item, from: 'en', to: lang);
        var translatedItem = translation.text;
        translationFuturesInput.add(Future.value(translatedItem));
      }
      final translatedListInput = await Future.wait(translationFuturesInput);

      return List<String>.from(translatedListInput);
    }
  }

  Future<Map<String, dynamic>> fetchFoodDetails(
    String food,
    String apiKey,
    String apiId,
  ) async {
    final encodedQuery = Uri.encodeComponent(food);
    final apiUrl = '$baseUrlApi/api/food-database/v2/parser?'
        'ingr=$encodedQuery&nutrition-type=cooking'
        '&app_id=$apiId&app_key=$apiKey';

    return await fetchDataFromAPI(apiUrl);
  }

  Future<void> searchFood(String query, String lang) async {
    if (query.length > 2) {
      final suggestions = await fetchSuggestions(query, lang);
      setState(() {
        this.suggestions = suggestions;
      });
    } else {
      setState(() {
        suggestions = [];
      });
    }
  }

  List<Future<String>> translationFutures = [];

  Future<void> getFoodDetails(String food, String lang) async {
    var apiKey = dotenv.get('EDANAMAPIFOODKEY');
    var apiId = dotenv.get('EDANAMAPIFOODID');

    final details = await fetchFoodDetails(food, apiKey, apiId);
    setState(() {
      foodDetails = details;
    });

    if (lang == 'en') {
    } else {
      for (var hint in foodDetails['hints']) {
        final food = hint['food'];
        final label = food['label'];
        final categoryLabel = food['categoryLabel'];
        final category = food['category'];

        translationFutures
            .add(translationHelper.translateText(label, lang, 'en'));
        translationFutures
            .add(translationHelper.translateText(categoryLabel, lang, 'en'));
        translationFutures
            .add(translationHelper.translateText(category, lang, 'en'));
      }
    }
  }

  User? user;

  final RevenueApi memberShip = RevenueApi();

  bool isSubscription = false;

  @override
  void initState() {
    super.initState();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      InfoPopup.show(
        context,
        'food-search-screen-popup-main-text'.i18n(),
        'food-search-screen-popup-secondary-text'.i18n(),
        'FoodSearchv2',
      );
    });

    isSubscription = memberShip.isSubscribedCheckSync();

    try {
      user =  FirebaseAuth.instance.currentUser;
      setState(() {
        isLoggedIn = (user != null);
        if (isLoggedIn) {
          BlocProvider.of<AuthenticationBloc>(context).logIn(user!.uid);
        }
      });

    } on FirebaseAuthException catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }

      if (isSubscription == false) {
        BannerAd(
          adUnitId: AdHelper.bannerAdUnitId,
          request: const AdRequest(),
          size: AdSize.banner,
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              setState(() {
                _bannerAd = ad as BannerAd;
              });
            },
            onAdFailedToLoad: (ad, err) {
              ad.dispose();
            },
          ),
        ).load();
      }

  }

  TranslationHelper translationHelper = TranslationHelper();

  Future<String> convertLang(String text, Locale locale) async {
    var convertedText =
        await translationHelper.translateText(text, locale.languageCode, 'en');
    return convertedText;
  }

  String recipeTitleDefault = '';

  Future<void> myFunction(String text, String localeText) async {
    if (localeText != 'en') {
      var translatedText =
          await translationHelper.translateText(text, localeText, 'en');
      setState(() {
        recipeTitleDefault = translatedText;
      });
    } else {
      setState(() {
        recipeTitleDefault = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var myLocale = Localizations.localeOf(context);

    // Reusable nutrient widget to keep the code clean
    Widget buildNutrient(
      String title,
      String value,
      IconData icon,
      Color color,
    ) {
      return Container(
        padding: const EdgeInsets.all(8.0),
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 2), // changes position of shadow
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(icon, color: Colors.white),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/recipes', (route) => false,);
          },
          icon: const FaIcon(
            FontAwesomeIcons.house,
            color: Colors.white,
          ),
        ),
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Center(
              child: TextField(
                onChanged: (value) => searchFood(value, myLocale.languageCode),
                decoration: InputDecoration.collapsed(
                  hintText: 'search-food-content'.i18n(),
                  hintStyle: Theme.of(context).textTheme.bodyLarge,
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            children: [
              const SizedBox(
                height: 20,
              ),
              if (_bannerAd != null && isSubscription == false)
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
              if (selectedFood.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        recipeTitleDefault.toUpperCase(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16.0),
                      // Nutrition information
                      if (showNutrients &&
                          foodDetails['parsed'] != null &&
                          foodDetails['parsed'].isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      10,
                                    ),
                                  ),
                                  child: Center(
                                    child: Image.network(
                                      foodDetails['parsed'][0]['food']['image'],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              const SizedBox(height: 8.0),
                              buildNutrient(
                                'calories'.i18n(),
                                '${foodDetails['parsed'][0]['food']
                                ['nutrients']['ENERC_KCAL'] ?? 'N/A'}',
                                MaterialCommunityIcons.food_apple,
                                Colors.red,
                              ),
                              const SizedBox(height: 8.0),
                              buildNutrient(
                                'protein'.i18n(),
                                '${foodDetails['parsed'][0]['food']
                                ['nutrients']['PROCNT'] ?? 'N/A'}',
                                MaterialCommunityIcons.cookie,
                                Colors.green,
                              ),
                              const SizedBox(height: 8.0),
                              buildNutrient(
                                'fat'.i18n(),
                                '${foodDetails['parsed'][0]['food']
                                ['nutrients']['FAT'] ?? 'N/A'}',
                                MaterialCommunityIcons.shaker,
                                Colors.blue,
                              ),
                              const SizedBox(height: 8.0),
                              buildNutrient(
                                'carbs'.i18n(),
                                '${foodDetails['parsed'][0]['food']
                                ['nutrients']['CHOCDF'] ?? 'N/A'}',
                                MaterialCommunityIcons.bread_slice,
                                Colors.orange,
                              ),
                              const SizedBox(height: 20.0),
                              if (translationFutures.isNotEmpty)
                                FutureBuilder<List<String>>(
                                  future: Future.wait(translationFutures),
                                  builder: (
                                    BuildContext context,
                                    AsyncSnapshot<List<String>> snapshot,
                                  ) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const LinearProgressIndicator();
                                    } else if (snapshot.hasError) {
                                      return Text('Error: ${snapshot.error}');
                                    } else if (snapshot.hasData) {
                                      final translations = snapshot.data!;

                                      return SingleChildScrollView(
                                        child: ListView.builder(
                                          physics:
                                         const NeverScrollableScrollPhysics(),
                                          shrinkWrap: true,
                                          itemCount:
                                              foodDetails['hints'].length,
                                          itemBuilder: (
                                            BuildContext context,
                                            int index,
                                          ) {
                                            final food = foodDetails['hints']
                                                [index]['food'];
                                            final label =
                                                translations[index * 3];
                                            final categoryLabel =
                                                translations[index * 3 + 1];
                                            final category =
                                                translations[index * 3 + 2];

                                            return ListTile(
                                              title: Text(label),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text('${"calories".i18n()} : '
                                                      '${food['nutrients']
                                                  ['ENERC_KCAL']
                                                      .toStringAsFixed(2)}'),
                                                  Text(
                                                    '${"protein".i18n()}: '
                                                    '${food['nutrients']
                                                    ['PROCNT']
                                                        .toStringAsFixed(2)}',
                                                  ),
                                                  Text(
                                                    '${"fat".i18n()}: '
                                                    '${food['nutrients']
                                                    ['FAT']
                                                        .toStringAsFixed(2)}',
                                                  ),
                                                  Text(
                                                    '${"carbs".i18n()}:'
                                                    '${food['nutrients']
                                                    ['CHOCDF']
                                                        .toStringAsFixed(2)}',
                                                  ),
                                                  Text(
                                                    '${"category".i18n()}: '
                                                    '$category',
                                                  ),
                                                  Text(
                                                    '${"cat-label".i18n()} '
                                                    'Label: $categoryLabel',
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    } else {
                                      return  Text('no-data'.i18n());
                                    }
                                  },
                                ),
                              if (translationFutures.isEmpty)
                                SingleChildScrollView(
                                  child: ListView.builder(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: foodDetails['hints'].length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final food =
                                          foodDetails['hints'][index]['food'];
                                      final label = food['label'];
                                      final categoryLabel =
                                          food['categoryLabel'];
                                      final category = food['category'];

                                      return ListTile(
                                        title: Text(label),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${"calories".i18n()} :'
                                              ' ${food['nutrients']
                                              ['ENERC_KCAL']
                                                  .toStringAsFixed(2)}',
                                            ),
                                            Text(
                                              '${"protein".i18n()}:'
                                              ' ${food['nutrients']
                                              ['PROCNT']
                                                  .toStringAsFixed(2)}',
                                            ),
                                            Text(
                                              '${"fat".i18n()}:'
                                              ' ${food['nutrients']
                                              ['FAT']
                                                  .toStringAsFixed(2)}',
                                            ),
                                            Text(
                                              '${"carbs".i18n()}:'
                                              ' ${food['nutrients']
                                              ['CHOCDF']
                                                  .toStringAsFixed(2)}',
                                            ),
                                            Text(
                                              '${"category".i18n()}: '
                                              '$category',
                                            ),
                                            Text(
                                              '${"cat-label".i18n()}'
                                              ' Label: $categoryLabel',
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                )
                            ],
                          ),
                        ),
                      const SizedBox(height: 12.0),
                    ],
                  ),
                ),
            ],
          ),
          if (suggestions.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Theme.of(context).colorScheme.onPrimary,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return ListTile(
                      title: Text(
                        suggestion,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      onTap: () async {
                        if (myLocale.languageCode != 'en') {
                          await myFunction(suggestion, myLocale.languageCode);
                        } else {
                          setState(() {
                            recipeTitleDefault = suggestion;
                          });
                        }

                        setState(() {
                          selectedFood = suggestion;
                          foodDetails = {};
                          suggestions = [];
                        });
                        if (myLocale.languageCode != 'en') {
                          var transText = await translator.translate(
                            selectedFood,
                            from: myLocale.languageCode,
                          );
                          var translationTextSelected = transText.toString();

                          await getFoodDetails(
                            translationTextSelected,
                            myLocale.languageCode,
                          );
                        } else {
                          await getFoodDetails(
                            selectedFood,
                            myLocale.languageCode,
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(isSubscription: isSubscription),
    );
  }

  @override
  void dispose() {
    if (_bannerAd != null) {
      _bannerAd?.dispose();
    }
    super.dispose();
  }
}
