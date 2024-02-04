import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:localization/localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/authentication/authentication_bloc.dart';
import '../generated/assets.dart';
import '../helpers/ad_helper.dart';
import '../helpers/translation_helper.dart';
import '../models/food_item.dart';
import '../pages/recipe_detail.dart';
import '../services/edanan_api_service.dart';
import '../services/revenuecat_api.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/custom_bottombar.dart';
import '../widgets/recipes_swip_form.dart';
import 'chat/chat_detail.dart';

class RecipeGenerator extends StatefulWidget {
  const RecipeGenerator({super.key});

  @override
  _RecipeGeneratorState createState() => _RecipeGeneratorState();
}

class _RecipeGeneratorState extends State<RecipeGenerator> {
  BannerAd? _bannerAd;
  BannerAd? _altBannerAd;
  InterstitialAd? _interstitialAd;

  final FlutterTts flutterTts = FlutterTts();
  String recipe = '';
  String imageUrl = '';
  bool isLoading = false;
  late List<dynamic> recipes = [];
  bool isPlaying = false;
  bool isLarge = false;
  bool isEdamamData = true;
  User? user = FirebaseAuth.instance.currentUser;
  bool isLoggedIn = false;
  bool isHomePage = false;

  final ApiService apiService = ApiService();
  final RevenueApi memberShip = RevenueApi();
  late Future<List<FoodItem>> _foodItemsFuture;
  late bool isEmailVerified;
  bool isSubscription = false;
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  
  @override
  void initState() {
    super.initState();

    isSubscription = memberShip.isSubscribedCheckSync();
    if (isSubscription == false) {
      _loadInterstitialAd();
      _loadFirstBannerAd();
      _loadSecondBannerAd();
    }
    try {
      user =  FirebaseAuth.instance.currentUser;
          isLoggedIn = (user != null);
          if (isLoggedIn) {
            BlocProvider.of<AuthenticationBloc>(context).logIn(user!.uid);
          }
    } on FirebaseAuthException catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
    _fetchRandomFoods();
    isHomePage = true;
    syncPurchase();
    showMainWidget().then((isSuccess) {
      if(isSuccess) {
        if (mounted) {
          showDialog(context: context, builder: (BuildContext ctx) {
            return AlertDialog(
              title: Text('splash-welcome-text'.i18n(),
                style: Theme.of(ctx)
                    .textTheme.titleMedium,),
              content: SizedBox(
                height: MediaQuery.of(ctx).size.height *  0.4,
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('main-guideline-body'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        const SizedBox(
                          height: 8,
                        ),
                        for (var item in itemsList)
                          Row(
                            children: [
                              const Icon(
                                Icons.fiber_manual_record,
                                size: 6,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(child: Text(item,
                                style: Theme.of(ctx)
                                    .textTheme.bodySmall,),),
                            ],
                          ),
                        const SizedBox(
                          height: 8,
                        ),
                        Text('main-guideline-item8'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        SizedBox(
                          child: Image.asset(Assets.imagesSampleAppBar,),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        Text('main-guideline-item9'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        Text('main-guideline-item10'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        Text('main-guideline-item11'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        const SizedBox(
                          height: 8,
                        ),
                        Text('main-guideline-item12'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        const SizedBox(
                          height: 8,
                        ),
                        Image.asset(Assets.imagesSampleCustomBar),
                        const SizedBox(
                          height: 8,
                        ),
                        Text('main-guideline-item13'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        Text('main-guideline-item14'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        Text('main-guideline-item15'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        Text('main-guideline-item16'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        const SizedBox(
                          height: 8,
                        ),
                        Image.asset(Assets.imagesProductDetail),
                        const SizedBox(
                          height: 8,
                        ),
                        Text('main-guideline-item17'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        const SizedBox(
                          height: 8,
                        ),
                        Image.asset(Assets.imagesProductDetailSub),
                        const SizedBox(
                          height: 8,
                        ),
                        Text('main-guideline-item18'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        const SizedBox(
                          height: 8,
                        ),
                        Text('main-guideline-item19'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        const SizedBox(
                          height: 8,
                        ),
                        Text('main-guideline-item20'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        Text('main-guideline-item21'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        const SizedBox(
                          height: 8,
                        ),
                        Text('main-guideline-item22'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        const SizedBox(
                          height: 8,
                        ),
                        Text('main-guideline-item23'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        Text('main-guideline-item24'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,),
                        Text('main-guideline-item25'.i18n(),
                          style: Theme.of(ctx)
                              .textTheme.bodySmall,)
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: Text('close'.i18n(),
                    style: Theme.of(ctx)
                        .textTheme.bodySmall,),
                ),
                TextButton(
                  onPressed: () {
                    _prefs.then(
                          (value)
                        {
                          value.setBool('main_guideline', false);
                          Navigator.pop(ctx);
                        }
                      ,);

                  },
                  child: Text('dont-show-again'.i18n(),
                    style: Theme.of(ctx)
                        .textTheme.bodySmall,),
                ),
              ],
            );
          },
          );
        }

      }
    });
  }

  TranslationHelper translationHelper = TranslationHelper();

  Future<void> _fetchRandomFoods() async {
    _foodItemsFuture = apiService.fetchRandomFoods();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              //  Navigator.pushNamed(context, '/recipes');
            },
          );

          setState(() {
            _interstitialAd = ad;
          });
        },
        onAdFailedToLoad: (err) {
          FirebaseCrashlytics.instance.recordError(err, null);
        },
      ),
    );
  }


  Future<void> syncPurchase() async {
    await dotenv.load(fileName: './.env');
    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      final androidId = dotenv.get('REVENUECATANDROIDKEY');
      configuration = PurchasesConfiguration(androidId);
      await Purchases.configure(configuration);
    } else if (Platform.isIOS) {
      final iosId = dotenv.get('REVENUECATIOSKEY');
      configuration = PurchasesConfiguration(iosId);
      await Purchases.configure(configuration);
    }
    try {
      if (user != null) {
        await Purchases.logIn(user!.uid);
      }
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(e, null);
    }

  }

  void _loadFirstBannerAd() {
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

  void _loadSecondBannerAd() {
    BannerAd(
      adUnitId: AdHelper.altBannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _altBannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    ).load();
  }
  Future<bool> checkEmailVerified() async {
    var user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    if (user != null) {
      setState(() {
        isEmailVerified = user.emailVerified;
      });
    } else {
      setState(() {
        isEmailVerified = false;
      });
    }

    if (isEmailVerified == false && user != null) {
      //todo: add email verification dialog
      return true;
    } else {
      return false;
    }
  }

  @override
  void dispose() {
    if (_altBannerAd != null) {
      _altBannerAd?.dispose();
    }
    if (_bannerAd != null) {
      _bannerAd?.dispose();
    }
    if (_interstitialAd != null) {
      _interstitialAd?.dispose();
    }
    //_authStateSubscription?.cancel();
    super.dispose();
  }

  List<String> itemsList = [
    'main-guideline-item1'.i18n(),
    'main-guideline-item2'.i18n(),
    'main-guideline-item3'.i18n(),
    'main-guideline-item4'.i18n(),
    'main-guideline-item5'.i18n(),
    'main-guideline-item6'.i18n(),
    'main-guideline-item7'.i18n(),
  ];

  Future<bool> showMainWidget() async {
    var prefs = await SharedPreferences.getInstance();
    var showPopup = prefs.getBool('main_guideline') ?? true;
    return showPopup;
  }


  @override
  Widget build(BuildContext context) {
    var myLocale = Localizations.localeOf(context);
    return Scaffold(
      appBar: CustomAppBar(
        isHomePage: isHomePage,
        isLoggedIn: isLoggedIn,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(
              height: 10,
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
             const SizedBox(
               height: 20,
             ),
             Text('Welcome to Chef AI',
               style: Theme.of(context).textTheme.titleLarge,),
             const SizedBox(
               height: 10,
             ),
             SizedBox(
               width: MediaQuery.of(context).size.width * 0.75,
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   SizedBox(
                     width: MediaQuery.of(context).size.width * 0.30,
                     child: ElevatedButton(
                       onPressed: () {
                         Navigator.of(context).pushNamed('/chat');
                       },
                       style: ElevatedButton.styleFrom(
                         elevation: 4,
                         backgroundColor: Colors.green.shade800,
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(4.0),
                         ),
                       ),
                       child:  const Text('Chef AI'),
                     ),
                   ),
                   SizedBox(
                     width: MediaQuery.of(context).size.width * 0.30,
                     child: ElevatedButton(onPressed: () {
                       Navigator.of(context).pushNamed('/createDiet');
                     },
                       style: ElevatedButton.styleFrom(
                         elevation: 4,
                         backgroundColor: Colors.green.shade800,
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(4.0),
                         ),
                       ),
                       child: const Text('Diet AI'),
                     ),
                   ),
                 ],
               ),
             ),
            const SizedBox(
              height: 20,
            ),
            const RecipeSearchForm(),
            const SizedBox(
              height: 10,
            ),
            if (_altBannerAd != null && isSubscription == false)
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: _altBannerAd!.size.width.toDouble(),
                  height: _altBannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _altBannerAd!),
                ),
              ),
            const SizedBox(
              height: 20,
            ),
            Text('recipe-day'.i18n(),
              style: Theme.of(context).textTheme.titleLarge,),
            const SizedBox(
              height: 20,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 230,
                child: isEdamamData
                    ? FutureBuilder<List<FoodItem>>(
                  future: _foodItemsFuture,
                  builder: (content, snapshot) {
                    if (snapshot.hasData) {
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: snapshot.data!.length > 19 ? 20 : 0,
                        itemBuilder: (context, index) {
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                10.0,
                              ),
                            ),
                            elevation: 2,
                            child: InkWell(
                              onTap: () {
                                if (isSubscription == false) {
                                  if (_interstitialAd != null) {
                                    _interstitialAd?.show();
                                  }
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RecipeDetails(
                                      uri: snapshot.data![index].uri,
                                    ),
                                  ),
                                );
                              },
                              child: SizedBox(
                                width: 170,
                                child: Column(
                                  children: <Widget>[
                                    FractionallySizedBox(
                                      widthFactor: 1.0,
                                      child: Image.network(
                                        snapshot.data![index].image,
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
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: Padding(
                                          padding:
                                          const EdgeInsets.all(1.0),
                                          child: Padding(
                                            padding:
                                            const EdgeInsets.symmetric(
                                              vertical: 2,
                                              horizontal: 10,
                                            ),
                                            child: FutureBuilder<String>(
                                              future: translationHelper
                                                  .translateTextAndCache(
                                                snapshot.data![index].label,
                                                myLocale.languageCode,
                                                'en',
                                              ),
                                              builder: (
                                                  BuildContext context,
                                                  AsyncSnapshot<String>
                                                  snapshot,
                                                  ) {
                                                if (snapshot
                                                    .connectionState ==
                                                    ConnectionState
                                                        .waiting) {
                                                  return const CircularProgressIndicator();
                                                } else if (snapshot
                                                    .hasError) {
                                                  return Text(
                                                    '${snapshot.error}',
                                                  );
                                                } else {
                                                  return Text(
                                                    snapshot.data ?? '',
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    } else if (snapshot.hasError) {
                      return Text('${"error".i18n()} ${snapshot.error}');
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                )
                    : const Center(child: LinearProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomBar(isSubscription: isSubscription),
      floatingActionButton:
          FloatingActionButton(
              elevation: 4,
              tooltip: 'Chef AI',
              backgroundColor: Colors.pink.shade800,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatDetailPageWidget(),
                  ),
                );
              },
              child: Image.asset(Assets.imagesChef),
            ),
    );
  }
}
