import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:localization/localization.dart';

import '../../bloc/authentication/authentication_bloc.dart';
import '../../helpers/ad_helper.dart';
import '../../helpers/translation_helper.dart';
import '../../services/revenuecat_api.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/custom_bottombar.dart';
import '../recipe_detail.dart';

class RecipeSearchFormWidget extends StatefulWidget {
  const RecipeSearchFormWidget({super.key});

  @override
  _RecipeSearchFormWidgetState createState() => _RecipeSearchFormWidgetState();
}

class _RecipeSearchFormWidgetState extends State<RecipeSearchFormWidget> {


  late String keyword;
  bool isEdamamData = false;
  List<dynamic> recipes = [];

  List<dynamic> mealType = [''];

  User? user = FirebaseAuth.instance.currentUser;

  final ScrollController _scrollController = ScrollController();

  bool _showSearch = true;

  bool _showNoResultText = false;

  String? nextPageUrl;

  bool isSubscription = false;

  final RevenueApi memberShip = RevenueApi();


  BannerAd? _bannerAd;

  bool isLoggedIn = false;
  @override
  void initState() {
    super.initState();


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



      if (isSubscription == true) {
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

    _scrollController.addListener(() {
      if (_scrollController.position.atEdge) {
        if (_scrollController.position.pixels == 0) {
        } else {
          fetchRecipes(keyword, nextPage: true);
        }
      }
    });


  }

  @override
  void dispose() {

    if ( _bannerAd != null) {
      _bannerAd?.dispose();
    }


    super.dispose();
  }

  Future<void> fetchRecipes(String searchKeyword,
      {bool nextPage = false,}) async {

    final apiKey = dotenv.get('EDANAMAPIKEY');
    final apiId = dotenv.get('EDANAMAPIID');

    String url;

    if (nextPage && nextPageUrl != null) {
      url = nextPageUrl!;
    } else {
      url =
          'https://api.edamam.com/api/recipes/v2?type=public&app_id='
              '$apiId&app_key=$apiKey&q=$searchKeyword&imageSize=LARGE';
    }

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      nextPageUrl = data['_links']['next']?['href'];
      setState(() {
        if (nextPage) {
          recipes.addAll(
              data['hits'],);
        } else {
          recipes =
              data['hits'];
        }
        isEdamamData = true;

        mealType = data['hits']?[0]?['recipe']?['mealType'] ?? [''];

        if (recipes.isEmpty) {
          _showNoResultText = true;
        }
      });
    }
  }



  TranslationHelper translationHelper = TranslationHelper();


  String convertToSlug(String text) {
    var result = text.toLowerCase().replaceAll(' ', '-');
    return result;
  }


  @override
  Widget build(BuildContext context) {
    // Determine the number of columns based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600; // Adjust the threshold as needed
    final columnCount = isTablet ? 4 : 2;
    final cardTitleSize = isTablet ? 0.01 : 0.04;


    var myLocale = Localizations.localeOf(context);
    return Scaffold(
      appBar:  CustomAppBar(
        isHomePage: false,
        isLoggedIn:isLoggedIn,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification is ScrollStartNotification) {
            if (notification.metrics.pixels > 0) {
              if (notification.metrics.pixels >
                  notification.metrics.maxScrollExtent / 2) {
                setState(() {
                  _showSearch = false;
                });
              } else {
                setState(() {
                  _showSearch = true;
                });
              }
            }
          }
          return true;
        },
        child: ListView(
          controller: _scrollController,
          children: [
            if (_showSearch)
              Column(
                children: [
                  const SizedBox(height: 10),
                  if (_bannerAd != null)
                    Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: _bannerAd!.size.width.toDouble(),
                        height: _bannerAd!.size.height.toDouble(),
                        child: AdWidget(ad: _bannerAd!),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      style: Theme.of(context).textTheme.bodyLarge,
                      onChanged: (value) {
                        keyword = value;
                      },
                      decoration:  InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: 'search-for-recipes'.i18n(),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        labelStyle: Theme.of(context).textTheme.bodyLarge,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(15.0)),
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () async  {
                      if ( myLocale.languageCode == 'en') {
                        await fetchRecipes(keyword);
                      } else {
                         await translationHelper.translateText(keyword, 'en',
                             myLocale.languageCode,).then((translatedKeyword) {
                          setState(() {
                            keyword = translatedKeyword;

                          });
                          fetchRecipes(keyword);
                        });

                      }
                    },
                    child:  Text('search'.i18n()),
                  ),

                ],
              ),
            if (isEdamamData)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:  SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnCount,
                ),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index]['recipe'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RecipeDetails(uri: recipe['uri'] ?? '/'),
                            ),
                          );
                        },
                        child: Column(
                          children: <Widget>[
                            Expanded(
                              flex: 4,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15.0),
                                  topRight: Radius.circular(15.0),
                                ),
                                child: Image.network(
                                  recipe['image'],
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (BuildContext context,
                                      Object exception,
                                      StackTrace? stackTrace,) {
                                    return Image.asset(
                                      'assets/images/default.png',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 120.0,
                                    );
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(5.0),
                                child:  FutureBuilder<String>(
                                  future: translationHelper
                                      .translateTextAndCache(
                                      recipe['label'],
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
                                          '${"errror".i18n()}: '
                                              '${snapshot.error}',);
                                    } else {
                                      return Text(
                                        snapshot.data ?? '',
                                        style:  TextStyle(fontSize:
                                        MediaQuery.of(context)
                                            .size.width * cardTitleSize,),
                                        softWrap: true,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Text(
                                          '${recipe['calories']
                                              .toStringAsFixed(2)} '
                                              '${"calc".i18n()}',
                                          style:
                                          const TextStyle(fontSize: 9.0),
                                          softWrap: true,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(convertToSlug(mealType[0]).i18n(),
                                            style: const TextStyle(
                                                fontSize: 8.0,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,),
                                      ],
                                    ),
                            ),
                            const SizedBox(
                              height: 6,
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (_showNoResultText)
               Padding(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                    child: Text(
                  'no-recipes'.i18n(),
                  style: const TextStyle(fontSize: 14),
                ),),
              ),
          ],
        ),
      ),
      bottomNavigationBar:  CustomBottomBar(isSubscription: isSubscription),
    );
  }


}
