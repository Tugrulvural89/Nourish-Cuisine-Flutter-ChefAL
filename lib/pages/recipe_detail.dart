import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:localization/localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../bloc/authentication/authentication_bloc.dart';
import '../generated/assets.dart';
import '../helpers/ad_helper.dart';
import '../helpers/translation_helper.dart';
import '../models/notes_model.dart';
import '../services/firestore_service.dart';
import '../services/revenuecat_api.dart';
import '../utils/share_plus.dart';
import 'notes/notes_page.dart';

class RecipeDetails extends StatefulWidget {
  final String uri;

  const RecipeDetails({super.key, required this.uri});

  @override
  _RecipeDetailsState createState() => _RecipeDetailsState();
}

class _RecipeDetailsState extends State<RecipeDetails> {
  final commonTextStyle = const TextStyle(fontSize: 12.0);
  final double optionsHeight = 100.0;
  final int crossAxisCount = 1;
  final double titleSize = 18.0;

  String? recipeTitle;
  String? recipeImage;
  List<dynamic> recipeIngredient = [];
  List<dynamic> healthLabels = [];
  List<dynamic> cautions = [];
  double? calories;
  int? totalCO2Emissions;
  String? co2EmissionsClass;
  int? totalWeight;
  double? totalTime;
  List<dynamic> mealType = [];
  String? urlSource;
  List<dynamic> cuisineType = [];
  List<dynamic> dishType = [];
  double? totalNutrients;
  double? sugar;
  String? myRecipe;
  bool _isListVisible = false;
  bool _isLabelVisible = false;
  List<dynamic> totalNutrientsList = [];
  String? userId;
  bool isLoggedIn = false;
  User? user;
  InterstitialAd? _interstitialAd;

  final RevenueApi memberShip = RevenueApi();

  bool isSubscription = false;

  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    fetchDetail(widget.uri);


    isSubscription = memberShip.isSubscribedCheckSync();

    try {
      user =  FirebaseAuth.instance.currentUser;
      setState(() {
        isLoggedIn = (user != null);
        userId = user?.uid;
        if (isLoggedIn) {
          BlocProvider.of<AuthenticationBloc>(context).logIn(user!.uid);
        }
      });

    } on FirebaseAuthException catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }

    if (isSubscription == false) {
      _loadInterstitialAd();
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
    } else {
      // Handle the case when the user is subscribed
    }
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
            },
          );
          setState(() {
            _interstitialAd = ad;
          });
        },
        onAdFailedToLoad: (err) {},
      ),
    );
  }

  String capitalizeSentence(String sentence) {
    final words = sentence.split(' ');
    final capitalizedWords = words.map((word) {
      final firstLetter = word.substring(0, 1).toUpperCase();
      final remainingLetters = word.substring(1).toLowerCase();
      return '$firstLetter$remainingLetters';
    });
    return capitalizedWords.join(' ');
  }

  final ScrollController _scrollController = ScrollController();

  TranslationHelper translationHelper = TranslationHelper();

  String recipeTitleDefault = '';

  Future<void> myFunction(String text, Locale localeText) async {
    var translatedText = await translationHelper.translateText(
      text,
      localeText.languageCode,
      'en',
    );

    setState(() {
      recipeTitle = translatedText;
    });
  }

  Future<void> fetchDetail(String uris) async {
    var apiKey = dotenv.get('EDANAMAPIKEY');
    var apiId = dotenv.get('EDANAMAPIID');
    var encodedUrl = Uri.encodeComponent(uris);
    final url = 'https://api.edamam.com/api/recipes/v2/by-uri?'
        'type=public&uri=$encodedUrl&app_key=$apiKey&app_id=$apiId';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      var recipe = data['hits'][0]['recipe'];

      setState(() {
        var myLocale = Localizations.localeOf(context);
        recipeTitleDefault = capitalizeSentence(decodeText(recipe['label']));
        myFunction(recipeTitleDefault, myLocale);
        recipeImage = recipe['images']['LARGE']['url'];
        recipeIngredient = recipe['ingredients'];
        healthLabels = recipe['healthLabels'];
        calories = recipe['calories'];
        totalNutrients =
            recipe['totalNutrients']?['ENERC_KCAL']?['quantity'] ?? 0.00;
        totalTime = recipe['totalTime'];
        sugar = recipe['totalNutrients']['SUGAR']['quantity'] ?? 0.00;

        recipe['totalNutrients'].forEach((key, value) async {
          var label = await translationHelper.translateText(
            value['label'],
            myLocale.languageCode,
            'en',
          );

          totalNutrientsList.add({
            'label': label,
            'quantity': value['quantity'],
            'unit': value['unit']
          });
        });

        urlSource = recipe['url'] ??
            'https://www.edamam.com/results/recipes/?search=salad';
        mealType = recipe['mealType'] ?? ' ';
        dishType = recipe['dishType'] ?? ' ';
        cuisineType = recipe['cuisineType'] ?? ' ';
      });
    } else {}
  }

  Future<void> _launchUrl(_url) async {
    if (_url.startsWith('http:')) {
      _url = _url.replaceFirst(
        'http:',
        'https:',
      );
    }
    final url = Uri.parse(_url);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> showUrlErrorDialog() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('error'.i18n()),
          content: Text('error'.i18n()),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('ok'.i18n()),
            ),
          ],
        );
      },
    );
  }

  Future<ImageProvider> downloadImage() async {
    return NetworkImage(recipeImage!);
  }

  String decodeText(String text) {
    var decodedText = utf8.decode(text.runes.toList());
    return decodedText;
  }

  String convertToSlug(String text) {
    var result = text.toLowerCase().replaceAll(' ', '-');
    return result;
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var myLocale = Localizations.localeOf(context);
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
    }
    return Scaffold(
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.4,
                      color: Colors.grey.shade200,
                      child: recipeImage == null
                          ? Image.asset(
                              'assets/images/default.png',
                              fit: BoxFit.cover,
                              errorBuilder: (
                                BuildContext context,
                                Object exception,
                                StackTrace? stackTrace,
                              ) {
                                return Image.asset(
                                  Assets.imagesDefault,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : FutureBuilder<void>(
                              future: precacheImage(
                                NetworkImage(recipeImage!),
                                context,
                              ),
                              builder: (
                                BuildContext context,
                                AsyncSnapshot<void> snapshot,
                              ) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: LinearProgressIndicator(),
                                  );
                                } else if (snapshot.hasError) {
                                  return Image.asset(
                                    Assets.imagesDefault,
                                    fit: BoxFit.cover,
                                  );
                                } else {
                                  return Image.network(
                                    recipeImage!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      BuildContext context,
                                      Object exception,
                                      StackTrace? stackTrace,
                                    ) {
                                      return Image.asset(
                                        Assets.imagesDefault,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  );
                                }
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, top: 60.0),
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: Colors.green.shade800,),
                        alignment: Alignment.center,
                        height: 40,
                        width: 40,
                        child: IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).size.height * 0.0,
                        right: 20,
                        left: 20,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 50.0,
                              left: 20.0,
                              right: 20.0,
                              bottom: 20.0,
                            ),
                            child: Text(
                              recipeTitle ?? 'recipe-detail'.i18n(),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
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
                          Column(
                            children:
                                List.generate(recipeIngredient.length, (index) {
                              final text =
                                  decodeText(recipeIngredient[index]['text']);
                              final quantity = (recipeIngredient[index]
                                      ['quantity'] as double)
                                  .toStringAsFixed(2);
                              final food =
                                  decodeText(recipeIngredient[index]['food']);
                              final weight =
                                  (recipeIngredient[index]['weight'] as double)
                                      .toStringAsFixed(2);
                              final foodCategory =
                                  recipeIngredient[index]['foodCategory'];
                              final imageUrl = recipeIngredient[index]['image'];

                              return Column(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.arrow_right),
                                    subtitle: FutureBuilder<String>(
                                      future: translationHelper
                                          .translateTextAndCache(
                                        '$food  quantity: $quantity weight: '
                                            '$weight category: $foodCategory',
                                        myLocale.languageCode,
                                        'en',
                                      ),
                                      builder: (
                                        BuildContext context,
                                        AsyncSnapshot<String> snapshot,
                                      ) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const Center(
                                            child: LinearProgressIndicator(),
                                          );
                                        } else if (snapshot.hasError) {
                                          return Text(
                                            '${'error'.i18n()}:'
                                            ' ${snapshot.error}',
                                          );
                                        } else {
                                          return Text(snapshot.data ?? '');
                                        }
                                      },
                                    ),
                                    trailing: GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              content: Image.network(
                                                imageUrl,
                                                errorBuilder: (
                                                  BuildContext context,
                                                  Object exception,
                                                  StackTrace? stackTrace,
                                                ) {
                                                  return Image.asset(
                                                    Assets.imagesDefault,
                                                    fit: BoxFit.cover,
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      child: Icon(
                                        Icons.info,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                    title: FutureBuilder<String>(
                                      future: translationHelper
                                          .translateTextAndCache(
                                        text,
                                        myLocale.languageCode,
                                        'en',
                                      ),
                                      builder: (
                                        BuildContext context,
                                        AsyncSnapshot<String> snapshot,
                                      ) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const Center(
                                            child: LinearProgressIndicator(),
                                          );
                                        } else if (snapshot.hasError) {
                                          return Text(
                                            '${"error".i18n()}:'
                                            ' ${snapshot.error}',
                                          );
                                        } else {
                                          return Text(snapshot.data ?? '');
                                        }
                                      },
                                    ),
                                  ),
                                  const Divider(),
                                ],
                              );
                            }),
                          ),
                          const SizedBox(
                            height: 50,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (mealType.isNotEmpty)
                                Column(
                                  children: [
                                    const FaIcon(
                                      FontAwesomeIcons.breadSlice,
                                      color: Color(0xFFF57F62),
                                    ),
                                    Text(
                                      convertToSlug(mealType[0]).i18n(),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              if (dishType.isNotEmpty)
                                Column(
                                  children: [
                                    const FaIcon(
                                      FontAwesomeIcons.bowlFood,
                                      color: Color(0xFFAE4429),
                                    ),
                                    Text(
                                      convertToSlug(dishType[0]).i18n(),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              if (cuisineType.isNotEmpty)
                                Column(
                                  children: [
                                    const FaIcon(
                                      FontAwesomeIcons.mapLocation,
                                      color: Color(0xFF93ACF5),
                                    ),
                                    Text(
                                      convertToSlug(cuisineType[0]).i18n(),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(
                            height: 50,
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 1,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isListVisible = !_isListVisible;
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        'total-nutrients-list'.i18n(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      _isListVisible
                                          ? Row(
                                              children: [
                                                const Icon(
                                                  Icons.arrow_drop_down,
                                                ),
                                                Text(
                                                  'Hide'.i18n(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                )
                                              ],
                                            )
                                          : Row(
                                              children: [
                                                const Icon(Icons.arrow_right),
                                                Text(
                                                  'Show'.i18n(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                )
                                              ],
                                            ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Visibility(
                            visible: _isListVisible,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.75,
                              child: Center(
                                child: ListView.builder(
                                  controller: _scrollController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: totalNutrientsList.length,
                                  itemBuilder: (context, index) {
                                    final nutrient = totalNutrientsList[index];
                                    final quantity =
                                        nutrient['quantity'].toStringAsFixed(
                                      2,
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.center,
                                            end: Alignment.topLeft,
                                            colors: [
                                              Colors.white,
                                              Colors.white
                                            ],
                                          ),
                                          image: const DecorationImage(
                                            image: AssetImage(
                                              Assets.imagesNeubacksecond,
                                            ),
                                            fit: BoxFit.fitHeight,
                                            alignment: Alignment.centerRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              offset: const Offset(0, 2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Card(
                                          elevation: 0,
                                          color: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10.0),
                                          ),
                                          child: ListTile(
                                            leading: const FaIcon(
                                              FontAwesomeIcons.boltLightning,
                                              color: Colors.green,
                                            ),
                                            title: Text(
                                              nutrient['label'],
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge,
                                            ),
                                            subtitle: Text(
                                              '$quantity ${nutrient['unit']}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 1,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isLabelVisible = !_isLabelVisible;
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        'total-health-label'.i18n(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      _isLabelVisible
                                          ? Row(
                                              children: [
                                                const Icon(
                                                  Icons.arrow_drop_down,
                                                ),
                                                Text(
                                                  'Hide'.i18n(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                )
                                              ],
                                            )
                                          : Row(
                                              children: [
                                                const Icon(Icons.arrow_right),
                                                Text(
                                                  'Show'.i18n(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                )
                                              ],
                                            ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Visibility(
                            visible: _isLabelVisible,
                            child: SizedBox(
                              width: 300,
                              child: GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                childAspectRatio: 2.5,
                                mainAxisSpacing: 8.0,
                                crossAxisSpacing: 8.0,
                                children: List.generate(
                                  healthLabels.length,
                                  (index) {
                                    // Generate a random color
                                    final randomColor = Color(
                                      (Random().nextDouble() * 0xFFFFFF)
                                          .toInt(),
                                    ).withOpacity(1.0);

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: randomColor,
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          healthLabels[index],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 30,
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
            // The following is the Stacked icon object areas.
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4 - 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.green.shade800,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          SizedBox(
                            height: 30,
                            width: 30,
                            child: IconButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.weightScale,
                                color: Colors.white,
                              ),
                              onPressed: () {},
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Text(
                      "${calories?.round().toInt().toString() ?? "n/a"} "
                          "${'calc'.i18n()}",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      ),
                      Column(
                        children: [
                          SizedBox(
                            height: 30,
                            width: 30,
                            child: IconButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.clock,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                // Handle your logic here
                              },
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Text(
                                "${totalTime?.round().toInt().toString() ??
                                    "n/a"} min",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      ),
                      Column(
                        children: [
                          SizedBox(
                            height: 30,
                            width: 30,
                            child: IconButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.candyCane,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                // Handle your logic here
                              },
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Text(
                                "${sugar?.round().toInt().toString() ?? "0"} "
                                "${'sugar'.i18n()} g",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      ),
                      Column(
                        children: [
                          SizedBox(
                            height: 30,
                            width: 50,
                            child: IconButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.circlePlay,
                                color: Colors.white,
                              ),
                              onPressed: () async {
                                if (isSubscription == false &&
                                    _interstitialAd != null) {
                                  await _interstitialAd?.show();
                                }

                                try {
                                  await _launchUrl(urlSource);
                                } catch (e) {
                                  await showUrlErrorDialog();
                                }

                              },
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Text(
                                'preparation'.i18n(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: SocialMediaFAB(
        recipeIngredient: recipeIngredient,
        recipeTitle: recipeTitle ?? 'Ingredient',
        preUrl: urlSource ?? 'https://www.edamam.com',
      ),
    );
  }
}

class SocialMediaFAB extends StatefulWidget {
  final List<dynamic> recipeIngredient;
  final String recipeTitle;
  final String preUrl;
  const SocialMediaFAB({
    super.key,
    required this.recipeIngredient,
    required this.recipeTitle,
    required this.preUrl,
  });

  @override
  _SocialMediaFABState createState() => _SocialMediaFABState();
}

class _SocialMediaFABState extends State<SocialMediaFAB>
    with SingleTickerProviderStateMixin {
  bool isOpened = false;
  late AnimationController _animationController;
  late Animation<Color?> _buttonColor;
  late Animation<double> _animateIcon;
  late Animation<double> _translateButton;
  final Curve _curve = Curves.easeOut;
  final double _fabHeight = 56.0;

  Color myColor = const Color(0xFFB74093);
  TranslationHelper translationHelper = TranslationHelper();

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });
    _animateIcon =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _buttonColor = ColorTween(
      begin: Colors.deepOrangeAccent,
      end: Colors.red,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.00,
          1.00,
        ),
      ),
    );
    _translateButton = Tween<double>(
      begin: _fabHeight,
      end: -14.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          0.0,
          0.75,
          curve: _curve,
        ),
      ),
    );
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void animate() {
    if (!isOpened) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    isOpened = !isOpened;
  }

  Future<void> shareToWhatsApp() async {
    print("ss");
    var myLocale = Localizations.localeOf(context);
    var translatedIngredients =
        widget.recipeIngredient.map<Future<String>>((ingredient) async {
      final food = ingredient['food'];
      final weight = (ingredient['weight'] as double).toStringAsFixed(2);
      final quantity = (ingredient['quantity'] as double).toStringAsFixed(2);
      final foodCategory = ingredient['foodCategory'];

      final translation = await translationHelper.translateTextAndCache(
        '$food  quantity: $quantity weight: $weight category: $foodCategory',
        myLocale.languageCode,
        'en',
      );
      return translation;
    }).toList();

    var translatedIngredientList = await Future.wait(translatedIngredients);

    var translateTitle = await translationHelper.translateTextAndCache(
      widget.recipeTitle,
      myLocale.languageCode,
      'en',
    );
    var newPreUrl = widget.preUrl.replaceAll('http:', 'https:');
    var message = "${'share-title'.i18n()}:\n\n";
    message += '$translateTitle \n\n';
    message += "${'ingredients'.i18n()}: \n";
    message += translatedIngredientList.map((item) => item).join('\n');
    message += '\n\n';
    message += ' ${"prepare".i18n()} :\n\n';
    message += newPreUrl;
    var encodedMessage = Uri.encodeComponent(message);
    var url = 'https://wa.me/?text=$encodedMessage';
    final finalUrl = Uri.parse(url);
    print(finalUrl);
    if (await canLaunchUrl(finalUrl)) {
      await launchUrl(finalUrl);
    } else {
      AlertDialog(
        title: const Text('error'),
        content: const Text('error'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('ok'),
          ),
        ],
      );
    }

  }

  Widget add() {
    return FloatingActionButton(
      elevation: 8,
      heroTag: 'add',
      onPressed: shareToWhatsApp,
      tooltip: 'Add',
      child: const FaIcon(
        FontAwesomeIcons.whatsapp,
      ),
    );
  }

  Future<void> shareToTwitter() async {
    var myLocale = Localizations.localeOf(context);
    var translatedIngredients =
        widget.recipeIngredient.map<Future<String>>((ingredient) async {
      final food = ingredient['food'];
      final weight = (ingredient['weight'] as double).toStringAsFixed(2);
      final quantity = (ingredient['quantity'] as double).toStringAsFixed(2);
      final foodCategory = ingredient['foodCategory'];

      final translation = await translationHelper.translateTextAndCache(
        '$food  quantity: $quantity weight: $weight category: $foodCategory',
        myLocale.languageCode,
        'en',
      );
      return translation;
    }).toList();

    var translatedIngredientList = await Future.wait(translatedIngredients);

    var translateTitle = await translationHelper.translateTextAndCache(
      widget.recipeTitle,
      myLocale.languageCode,
      'en',
    );

    var newPreUrl = widget.preUrl.replaceAll('http:', 'https:');
    var message = "${'share-title'.i18n()}:\n\n";
    message += '$translateTitle \n\n';
    message += "${'ingredients'.i18n()}: \n";
    message += translatedIngredientList.map((item) => item).join('\n');
    message += '\n\n';
    message += ' ${"prepare".i18n()} :\n\n';
    message += newPreUrl;
    Share.share(message);
  }

  Widget inbox() {
    return FloatingActionButton(
      elevation: 8,
      heroTag: 'inbox',
      onPressed: shareToTwitter,
      tooltip: 'Inbox',
      child: const FaIcon(
        FontAwesomeIcons.share,
      ),
    );
  }

  Widget addNote(recipeIngredient, recipeTitle) {
    void showMyDialog() {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          // return object of type Dialog
          return AlertDialog(
            title: Text('add-success'.i18n()),
            content: Text('recipe-list-added'.i18n()),
            actions: <Widget>[
              TextButton(
                child: Text('close'.i18n()),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('redirect-notes'.i18n()),
                onPressed: () {
                  Navigator.pushNamed(context, '/notes');
                },
              ),
            ],
          );
        },
      );
    }

    var myLocale = Localizations.localeOf(context);
    return FloatingActionButton(
      heroTag: 'addNote',
      onPressed: () async {
        final db = FirestoreService();
        var user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          var userId = user.uid;
          List<Future<String>> translatedIngredients =
              recipeIngredient.map<Future<String>>((ingredient) async {
            final food = ingredient['food'];
            final weight = (ingredient['weight'] as double).toStringAsFixed(2);
            final quantity =
                (ingredient['quantity'] as double).toStringAsFixed(2);
            final foodCategory = ingredient['foodCategory'];

            final translation = await translationHelper.translateTextAndCache(
              '$food  quantity: $quantity weight:'
                  ' $weight category: $foodCategory',
              myLocale.languageCode,
              'en',
            );
            return translation;
          }).toList();

          var translatedIngredientList =
              await Future.wait(translatedIngredients);

          final note = Note(
            id: const Uuid().v1(),
            title: recipeTitle ?? 'The Recipe',
            time: DateTime.now().toString(),
            items: translatedIngredientList,
          );

          try {
            await db.saveNote(userId, note);
            showMyDialog();
          } on FirebaseException catch (e, stackTrace) {
            await FirebaseCrashlytics.instance.recordError(e, stackTrace);
          }
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RedirectLoginPage()),
          );
        }
      },
      tooltip: 'Add Note',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FaIcon(
            FontAwesomeIcons.noteSticky,
          ),
          Text('save'.i18n(), style: Theme.of(context).textTheme.labelSmall)
        ],
      ),
    );
  }

  Widget toggle() {
    return FloatingActionButton(
      elevation: 8,
      heroTag: 'floatAction',
      backgroundColor: _buttonColor.value,
      onPressed: animate,
      tooltip: 'Toggle',
      child: AnimatedIcon(
        icon: AnimatedIcons.menu_close,
        progress: _animateIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Transform(
          transform: Matrix4.translationValues(
            0.0,
            _translateButton.value * 3.0,
            0.0,
          ),
          child: addNote(widget.recipeIngredient, widget.recipeTitle),
        ),
        Transform(
          transform: Matrix4.translationValues(
            0.0,
            _translateButton.value * 2.0,
            0.0,
          ),
          child: add(),
        ),
        Transform(
          transform: Matrix4.translationValues(
            0.0,
            _translateButton.value,
            0.0,
          ),
          child: inbox(),
        ),
        toggle(),
      ],
    );
  }
}
