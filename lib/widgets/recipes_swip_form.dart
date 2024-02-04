import 'dart:convert';

import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:localization/localization.dart';
import 'package:translator/translator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../generated/assets.dart';
import '../helpers/ad_helper.dart';
import '../helpers/translation_helper.dart';
import '../pages/recipe_detail.dart';
import '../services/revenuecat_api.dart';

class SwipeableRecipes extends StatefulWidget {
  final String apiUrl;
  const SwipeableRecipes({super.key, required this.apiUrl});

  @override
  _SwipeableRecipesState createState() => _SwipeableRecipesState();
}

class _SwipeableRecipesState extends State<SwipeableRecipes> {
  List<Recipe> recipes = [];

  bool isSubscription = false;
  bool dataLength = true;
  final double listBuilderHeight = 0.30;



  String convertToSlug(String text) {
    var result = text.toLowerCase().replaceAll(' ', '-');
    return result;
  }

  final _translator = GoogleTranslator();

  TranslationHelper translationHelper = TranslationHelper();

  Future<String> translateText(
      String text, String targetLanguage, String fromLanguage,) async {
    final translation = await _translator.translate(text,
        to: targetLanguage, from: fromLanguage,);
    return translation.text;
  }

  String preUrl = '';
  Future<void> fetchRecipes() async {
    final apiKey = dotenv.get('EDANAMAPIKEY');
    final apiId = dotenv.get('EDANAMAPIID');
    final baseUrl = 'https://api.edamam.com/api/recipes/v2?'
        'type=public&app_id=$apiId&app_key=$apiKey';
    final url = '$baseUrl${widget.apiUrl}';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        recipes = List<Recipe>.from(data['hits'].map((recipe) => Recipe(
              label: decodeText(recipe['recipe']['label']),
              image: recipe['recipe']['images']['LARGE']['url'],
              calories: recipe['recipe']['calories'],
              recipeIngredient: recipe['recipe']['ingredients'],
              healthLabels: recipe['recipe']['healthLabels'],
              mealType: recipe['recipe']['mealType'],
              dishType: recipe['recipe']['dishType'],
              cuisineType: recipe['recipe']['cuisineType'],
              totalTime: recipe['recipe']['totalTime'],
              sugar: recipe['recipe']['totalNutrients']['SUGAR']['quantity'],
              totalNutrients: recipe['recipe']['totalNutrients']['ENERC_KCAL']
                  ['quantity'],
              urlSource: recipe['recipe']['url'],
            ),),);

        if (data['hits'].length > 0) {
          dataLength = true;
        } else {
          dataLength = false;
        }
      });
    }
  }


  InterstitialAd? _interstitialAd;

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


  final RevenueApi memberShip = RevenueApi();

  @override
  void initState() {
    super.initState();
    fetchRecipes();
    isSubscription = memberShip.isSubscribedCheckSync();

    if (isSubscription == false) {
        _loadInterstitialAd();
    }
  }



  String decodeText(String text) {
    var decodedText = utf8.decode(text.runes.toList());
    return decodedText;
  }

  List<dynamic> floatActionRecipes = [];
  String? floatActionTitle;

  @override
  void dispose(){
    _interstitialAd?.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    var myLocale = Localizations.localeOf(context);
    return Scaffold(
      body: dataLength
          ? Swiper(
              containerWidth: MediaQuery.of(context).size.width  * 1,
              onIndexChanged: (int index) {
                if (index != 0) {
                  setState(() {
                    floatActionRecipes = recipes[index].recipeIngredient ?? [];
                  });
                }
              },
              itemBuilder: (BuildContext context, int index) {
                return Card(
                    margin: EdgeInsets.zero, // Remove margins of the Card
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                    clipBehavior: Clip.antiAlias, // Add this line
                    child: Stack(
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Expanded(
                            flex: 3,
                            child: Image.network(
                              recipes[index].image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset('assets/images/default.png');
                              },
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Column(children: [
                                  const SizedBox(
                                    height: 6,
                                  ),
                                  FutureBuilder<String>(
                                    future: translationHelper
                                        .translateTextAndCache(
                                        recipes[index].label,
                                        myLocale
                                            .languageCode, 'en',),
                                    builder: (BuildContext context,
                                        AsyncSnapshot<String> snapshot,) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                            child: LinearProgressIndicator(),);
                                      } else if (snapshot.hasError) {
                                        return Text(
                                            '${"error".i18n()}:'
                                                ' ${snapshot.error}',);
                                      } else {

                                         floatActionTitle = snapshot.data;

                                         preUrl = Uri.parse(recipes[index]
                                             .urlSource ?? 'https://edamam.com',)
                                             .toString();

                                        return Padding(
                                          padding: const EdgeInsets
                                              .only(left:12.0,
                                              right: 8.0, ),
                                          child: Center(
                                            child: Padding(
                                              padding:
                                              const EdgeInsets.all(12.0),
                                              child: Text(
                                                snapshot.data ?? recipes[index]
                                                    .label,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text(
                                        "${'calories'.i18n()} : ${recipes[index]
                                            .calories!.round().toString()}",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,),
                                      ),
                                      Text(
                                          "${'time'.i18n()} : ${recipes[index]
                                              .totalTime!.round().toString()}",
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple,),),
                                      Text(
                                          "${'sugar'.i18n()} : ${recipes[index]
                                              .sugar!.round().toString()}",
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,),),
                                      IconButton(
                                        icon: FaIcon(
                                          FontAwesomeIcons.circlePlay,
                                          color: Colors.green.shade800,
                                        ),
                                        onPressed: () async {
                                          if (isSubscription == false) {
                                            await _interstitialAd?.show();
                                          }
                                          final productUrl =recipes[index].urlSource;

                                          try {
                                            await _launchUrl(productUrl);
                                          } catch (e) {
                                            await showUrlErrorDialog();
                                          }

                                        },

                                      )
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 2,
                                  ),
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height
                                        * listBuilderHeight,
                                    child: ListView.builder(
                                      itemCount:
                                          recipes[index]
                                              .recipeIngredient!.length,
                                      itemBuilder: (context, ingredientIndex) {
                                        final text = recipes[index]
                                          .recipeIngredient![ingredientIndex]
                                            ['text'];
                                        final quantity = recipes[index]
                                            .recipeIngredient![ingredientIndex]
                                                ['quantity']
                                            .toString();
                                        final food = recipes[index]
                                         .recipeIngredient![ingredientIndex]
                                            ['food'];
                                        final weight = recipes[index]
                                          .recipeIngredient![ingredientIndex]
                                            ['weight'].toStringAsFixed(2);
                                        final foodCategory = recipes[index]
                                          .recipeIngredient![ingredientIndex]
                                            ['foodCategory'];
                                        final imageUrl = recipes[index]
                                           .recipeIngredient![ingredientIndex]
                                            ['image'];
                                        return Column(
                                          children: [
                                            ListTile(
                                              leading:
                                                  const Icon(Icons.arrow_right),
                                              subtitle: FutureBuilder<String>(
                                                  future: translationHelper
                                                      .translateTextAndCache(
                                                          '$food  quantity:'
                                                       ' $quantity weight: '
                                                      '$weight category:'
                                                              ' $foodCategory',
                                                          myLocale.languageCode,
                                                      'en',),
                                             builder: (BuildContext context,
                                                      AsyncSnapshot<String>
                                                          snapshot,) {
                                                if (snapshot.connectionState ==
                                                   ConnectionState.waiting) {
                                                  return const Center(child:
                                                 LinearProgressIndicator(),);
                                               } else if (snapshot.hasError) {
                                                      return Text(
                                                          '${"error"
                                                              .i18n()}: '
                                                      '${snapshot.error}');
                                                    } else {
                                                      return Text(
                                                          snapshot.data ?? '',);
                                                    }
                                                  },),
                                              trailing: GestureDetector(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder:
                                                        (BuildContext context) {
                                                      return AlertDialog(
                                                        content: Image.network(
                                                          imageUrl,
                                                          errorBuilder:
                                                       (BuildContext context,
                                                            Object exception,
                                                                  StackTrace?
                                                                stackTrace,) {
                                                            return Image.asset(
                                                 Assets.imagesDefault,
                                                         fit: BoxFit.cover,);
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
                                                        decodeText(text),
                                                        myLocale
                                                    .languageCode, 'en',),
                                                builder: (BuildContext context,
                                                    AsyncSnapshot<String>
                                                        snapshot,) {
                                            if (snapshot.connectionState ==
                                                      ConnectionState.waiting) {
                                                    return const Center(
                                                        child:
                                                 LinearProgressIndicator(),);
                                               } else if (snapshot.hasError) {
                                                    return Text(
                                                        '${"error".i18n()}:'
                                                   ' ${snapshot.error}');
                                                  } else {
                                                    return Text(
                                                        snapshot.data ?? '',
                                                      style: Theme.of(context)
                                                  .textTheme.bodySmall,);
                                                  }
                                                },
                                              ),
                                            ),
                                            const Divider(),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        SizedBox(
                                     width: MediaQuery.of(context).size.width
                                              * listBuilderHeight,
                                          child: Column(
                                            children: [
                                              const FaIcon(
                                                FontAwesomeIcons.breadSlice,
                                                color: Color(0xFFF57F62),
                                              ),
                                         if (recipes[index].mealType != null)
                                              Align(
                                                child: Text(
                                                    convertToSlug(
                                                            recipes[index]
                                                                .mealType?[0],)
                                                        .i18n(),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall, maxLines: 2,
                                              overflow: TextOverflow.ellipsis,),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                    width: MediaQuery.of(context).size.width
                                              * listBuilderHeight,
                                          child: Column(
                                            children: [
                                              const FaIcon(
                                                FontAwesomeIcons.bowlFood,
                                                color: Color(0xFFAE4429),
                                              ),
                                         if (recipes[index].dishType != null)
                                              Text(
                                                  convertToSlug(
                                                          recipes[index]
                                                              .dishType?[0],)
                                                      .i18n(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall, maxLines: 1,
                                        overflow: TextOverflow.ellipsis,),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                   width: MediaQuery.of(context).size.width
                                              * listBuilderHeight,
                                          child: Column(
                                            children: [
                                              const FaIcon(
                                                FontAwesomeIcons.mapLocation,
                                                color: Color(0xFF93ACF5),
                                              ),
                                              if (recipes[index]
                                                  .cuisineType != null)
                                              Text(
                                                  convertToSlug(recipes[index]
                                                          .cuisineType?[0],)
                                                      .i18n(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall, maxLines: 1,
                                                overflow:
                                                  TextOverflow.ellipsis,),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],),),
                          ),
                        ],),
                        Padding(
                          padding: const EdgeInsets.only(left:20.0, top:60.0),
                          child: Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                color: Colors.green.shade800,
                            ),
                            alignment: Alignment.center,
                            height:40,
                            width: 40,
                            child:  IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.arrow_back,
                                color: Colors.white,),
                            ),
                          ),
                        ),
                      ],
                    ),);
              },
              itemCount: recipes.length,
              control: const SwiperControl(color: Colors.green),
            )
          : Center(
              child: SizedBox(
                height: 200,
                child: Column(
                  children: [
                    TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/recipes');
                        },
                        child: const Text('No recipes found :( '),),
                  ],
                ),
              ),
            ),
      floatingActionButton: SocialMediaFAB(
          recipeIngredient: floatActionRecipes,
          recipeTitle: floatActionTitle ?? 'Recipes', preUrl: preUrl,),
    );
  }
}

class Recipe {
  final String label;
  final String image;
  final double? calories;
  List<dynamic>? recipeIngredient;
  List<dynamic>? healthLabels;
  List<dynamic>? mealType;
  List<dynamic>? dishType;
  final double? totalTime;
  List<dynamic>? cuisineType;
  List<dynamic>? dietLabels;
  final double? sugar;
  final double? totalNutrients;
  final String? urlSource;

  Recipe({
    required this.label,
    required this.image,
    this.calories,
    this.recipeIngredient,
    this.healthLabels,
    this.mealType,
    this.dishType,
    this.totalTime,
    this.cuisineType,
    this.sugar,
    this.totalNutrients,
    this.dietLabels,
    required this.urlSource,
  });
}

class RecipeSearchForm extends StatefulWidget {
  const RecipeSearchForm({super.key});

  @override
  _RecipeSearchFormState createState() => _RecipeSearchFormState();
}

class _RecipeSearchFormState extends State<RecipeSearchForm> {
  String? recipeDropValue;

  final List<String> recipeList = [
    'alcohol-cocktail',
    'alcohol-free',
    'celery-free',
    'crustacean-free',
    'dairy-free',
    'DASH',
    'egg-free',
    'fish-free',
    'fodmap-free',
    'gluten-free',
    'immuno-supportive',
    'keto-friendly',
    'kidney-friendly',
    'kosher',
    'low-potassium',
    'low-sugar',
    'lupine-free',
    'Mediterranean',
    'mollusk-free',
    'mustard-free',
    'no-oil-added',
    'paleo',
    'peanut-free',
    'pescatarian',
    'pork-free',
    'red-meat-free',
    'sesame-free',
    'shellfish-free',
    'soy-free',
    'sugar-conscious',
    'sulfite-free',
    'tree-nut-free',
    'vegan',
    'vegetarian',
    'wheat-free',
  ];

  final List<String> diet = [
    'balanced',
    'high-fiber',
    'high-protein',
    'low-carb',
    'low-fat',
    'low-sodium',
  ];

  final List<String> dishType = [
    'Biscuits and cookies',
    'Bread',
    'Cereals',
    'Condiments and sauces',
    'Desserts',
    'Drinks',
    'Main course',
    'Pancake',
    'Preps',
    'Preserve',
    'Salad',
    'Sandwiches',
    'Side dish',
    'Soup',
    'Starter',
    'Sweets',
  ];

  final List<String> mealType = [
    'Breakfast',
    'Dinner',
    'Lunch',
    'Snack',
    'Teatime',
  ];

  final List<String> cuisineType = [
    'American',
    'Asian',
    'British',
    'Caribbean',
    'Central Europe',
    'Chinese',
    'Eastern Europe',
    'French',
    'Indian',
    'Italian',
    'Japanese',
    'Kosher',
    'Mediterranean',
    'Mexican',
    'Middle Eastern',
    'Nordic',
    'South American',
    'South East Asian',
  ];

  String? dietDropValue;
  String? dishTypeDropValue;
  String? mealTypeDropValue;
  String? cuisineTypeDropValue;

  bool _filterVisibility = false;

  String filterText = 'Filters'.i18n();
  String resetText = 'ResetFilter'.i18n();
  String mealText = 'mealType'.i18n();
  String dietText = 'dietType'.i18n();
  String dishText = 'dishType'.i18n();
  String cuisineText = 'cuisineType'.i18n();

  String getApiUrl() {
    final dietValue =
        dietDropValue != null ? '&diet=$dietDropValue' : '';
    final dishTypeValue =
        dishTypeDropValue != null ? '&dishType=$dishTypeDropValue' : '';
    final mealTypeValue =
        mealTypeDropValue != null ? '&mealType=$mealTypeDropValue' : '';
    final cuisineTypeValue = cuisineTypeDropValue != null
        ? '&cuisineType=$cuisineTypeDropValue'
        : '';
    return '$dietValue$dishTypeValue$mealTypeValue$cuisineTypeValue'
        '&imageSize=LARGE&random=true';
  }

  void formInputs() {
    final apiUrl = getApiUrl();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SwipeableRecipes(
          apiUrl: apiUrl,
        ),
      ),
    );
  }

  String convertToSlug(String text) {
    var slug = text.toLowerCase().replaceAll(' ', '-');
    return slug;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(
              height: 20,
            ),
            Text(
              'main-filter-title'.i18n(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(
              height: 5,
            ),
            Text('click-random-button-title'.i18n(), style:
            Theme.of(context).textTheme.bodySmall,),
            const SizedBox(
              height: 10,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _filterVisibility = !_filterVisibility;
                        });
                      },
                      child: Row(
                        children: [
                          Text(
                            filterText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Icon(Icons.arrow_downward,
                            color: Colors.black,),
                        ],
                      ),),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        dietDropValue = null;
                        dishTypeDropValue = null;
                        mealTypeDropValue = null;
                        cuisineTypeDropValue = null;
                      });
                    },
                    child: Text(resetText),),
                ],
              ),
            ),
            Visibility(
              visible: _filterVisibility,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, bottom: 10.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(dietText,
                        style: const TextStyle(fontSize: 12),),),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: DropdownButton<String>(
                            iconEnabledColor: Colors.black,
                            isExpanded: true,
                            value: dietDropValue,
                            icon: const Icon(Icons.arrow_downward),
                            elevation: 16,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            underline: Container(
                              height: 2,
                              color: Colors.white,
                            ),
                            onChanged: (String? newValue) {
                              setState(() {
                                dietDropValue = newValue;
                              });
                            },
                            items: diet
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(convertToSlug(value).i18n(),
                                  style:
                                  const TextStyle(color: Colors.black),),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, bottom: 10.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(dishText,
                        style: const TextStyle(fontSize: 12),),),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: DropdownButton<String>(
                            iconEnabledColor: Colors.black,
                            isExpanded: true,
                            value: dishTypeDropValue,
                            icon: const Icon(Icons.arrow_downward),
                            elevation: 16,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            underline: Container(
                              height: 2,
                              color: Colors.white,
                            ),
                            onChanged: (String? newValue) {
                              setState(() {
                                dishTypeDropValue = newValue;
                              });
                            },
                            items: dishType
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(convertToSlug(value).i18n(),
                                  style:
                                  const TextStyle(color: Colors.black),),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, bottom: 10.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(mealText,
                        style: const TextStyle(fontSize: 12),),),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: DropdownButton<String>(
                            iconEnabledColor: Colors.black,
                            isExpanded: true,
                            value: mealTypeDropValue,
                            icon: const Icon(Icons.arrow_downward),
                            elevation: 16,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            underline: Container(
                              height: 2,
                              color: Colors.white,
                            ),
                            onChanged: (String? newValue) {
                              setState(() {
                                mealTypeDropValue = newValue;
                              });
                            },
                            items: mealType
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(convertToSlug(value).i18n(),
                                  style:
                                  const TextStyle(color: Colors.black),),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, bottom: 10.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(cuisineText,
                        style: const TextStyle(fontSize: 12),),),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: DropdownButton<String>(
                            iconEnabledColor: Colors.black,
                            isExpanded: true,
                            value: cuisineTypeDropValue,
                            icon: const Icon(Icons.arrow_downward),
                            elevation: 16,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            underline: Container(
                              height: 2,
                              color: Colors.white,
                            ),
                            onChanged: (String? newValue) {
                              setState(() {
                                cuisineTypeDropValue = newValue;
                              });
                            },
                            items: cuisineType
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(convertToSlug(value).i18n(),
                                  style:
                                  const TextStyle(color: Colors.black),),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300], // out color of cycle
              ),
              padding: const EdgeInsets.all(
                  10,), // empty space of generator button green line
              child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[250], // inline color of cycle
                  ),
                  padding: const EdgeInsets.all(
                      10,), //  button and inline cycle empty space
                  child: Center(
                    child: SizedBox(
                      height: 100,
                      width: 100,
                      child: FittedBox(
                        child: Material(
                          type: MaterialType.circle, // To make it circular
                          color: Colors.green.shade800, // Button color
                          elevation: 4, // Shadow
                          child: InkWell(
                            onTap: formInputs,
                            child: const Padding(
                              padding: EdgeInsets.all(20), // For icon padding
                              child:
                                  Icon(Icons.restaurant, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),),
            ),
            const SizedBox(
              height: 40,
            ),
          ],),
    );
  }
}




class ErrorScreen extends StatelessWidget {
  final String errorMessage;

  const ErrorScreen({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('error'.i18n()),
      ),
      backgroundColor: Colors.green,
      body: Center(
        child: Text(
          errorMessage,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

