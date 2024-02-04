import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:localization/localization.dart';
import 'package:share_plus/share_plus.dart';

import '../bloc/authentication/authentication_bloc.dart';
import '../bloc/authentication/authentication_state.dart';
import '../helpers/ad_helper.dart';
import '../services/revenuecat_api.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/custom_bottombar.dart';
import '../widgets/info_popup.dart';
import '../widgets/pre_alert_dialog.dart';
import 'notes/notes_page.dart';

class RecipeGeneratorWithAi extends StatefulWidget {
  const RecipeGeneratorWithAi({super.key});

  @override
  _RecipeGeneratorWithAiState createState() => _RecipeGeneratorWithAiState();
}

class _RecipeGeneratorWithAiState extends State<RecipeGeneratorWithAi> {
  final FlutterTts flutterTts = FlutterTts();
  String recipe = '';
  String imageUrl = '';
  bool isLoading = false;
  late List<dynamic> recipes = [];
  bool isPlaying = false;
  bool isLarge = false;
  bool isEdamamData = false;
  User? user = FirebaseAuth.instance.currentUser;
  bool isLoggedIn = false;
  InterstitialAd? _interstitialAd;
  BannerAd? _bannerAd;
  final String errorMessage = 'error-message-openai-loading'.i18n();
  final RevenueApi memberShip = RevenueApi();
  late bool isSubscription;
  int limitForUserText = 1;
  String? myLanguage;
  bool isStreaming = false;
  late CollectionReference textGenerationActionsCollection;

  @override
  void initState() {
    super.initState();
    isSubscription = memberShip.isSubscribedCheckSync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InfoPopup.show(
        context,
        'random-tariff-title'.i18n(),
        'random-tariff-body'.i18n(),
        'GenerateAI',
      );
    });


    try {
      user = FirebaseAuth.instance.currentUser;
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
    }

    textGenerationActionsCollection =
        FirebaseFirestore.instance.collection('text_generation_actions');
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

  Future<void> resetDailyUsageForTomorrow() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var today = DateTime.now();

    await textGenerationActionsCollection
        .doc(user.uid)
        .update({'daily_usage': 0, 'last_action_date': today.toUtc()});
  }

  Future<bool> canUserGenerateText() async {

    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    var textGenerationSnapshot =
        await textGenerationActionsCollection.doc(user.uid).get();

    if (!textGenerationSnapshot.exists) {
      await textGenerationActionsCollection.doc(user.uid).set({
        'last_action_date': DateTime.now().toUtc(), // Initial action date
        'daily_usage': 0,
      });
      // Set the textGenerationSnapshot to the new document
      textGenerationSnapshot =
          await textGenerationActionsCollection.doc(user.uid).get();
    }

    DateTime? textGenerationLastActionDate = (textGenerationSnapshot.data()
            as Map<String, dynamic>?)?['last_action_date']
        ?.toDate();

    int textGenerationDailyUsage = (textGenerationSnapshot.data()
            as Map<String, dynamic>)['daily_usage'] ??
        0;

    if (!_isSameDay(textGenerationLastActionDate, DateTime.now())) {
      // Reset the daily usage for tomorrow
      await resetDailyUsageForTomorrow();
      textGenerationDailyUsage=0;
    }
    // handle any changes to customerInfo
    final dietMaxLimit = int.parse(dotenv.get('MAXAIRANDOM'));
    final dietMinLimit = int.parse(dotenv.get('MINAIRANDOM'));
    isSubscription = memberShip
        .isSubscribedCheckSync(); // Check if the user is subscribed or not
    if (isSubscription == false) {
      limitForUserText = dietMinLimit; //dietMinLimit;
    } else {
      // Handle the case when the user is subscribed
      limitForUserText = dietMaxLimit;
    }
    return textGenerationDailyUsage < limitForUserText;
  }

  bool _isSameDay(DateTime? date1, DateTime date2) {
    if (date1 == null) return false;
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void showCustomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomAlertDialog(isSubscription: isSubscription);
      },
    );
  }


  Future<void> generateText() async {
    setState(() {
      isStreaming = true;
    });
    var canGenerate = await canUserGenerateText();
    if (canGenerate) {
      var user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        var nowUtc = DateTime.now().toUtc();
        await textGenerationActionsCollection.doc(user.uid).update({
          'daily_usage': FieldValue.increment(1),
          'last_action_date': nowUtc
        });
        await getRecipe();
      }
    } else {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        showCustomDialog(context);
      }
    }
    setState(() {
      isStreaming = false;
    });
  }

  Future<void> getRecipe() async {
    setState(() {
      isLoading = true;
      recipe = '';
    });
    await flutterTts.stop();
    await Future.delayed(const Duration(seconds: 2));
    try {
      OpenAI.apiKey = dotenv.get('GPTAPIKEY');
      var promptText = 'generator-input-receipts'.i18n();
      var secondMainText = 'write-random-delicious-recipes'.i18n();
      var chatStream =  OpenAI.instance.chat.createStream(
        model: 'gpt-3.5-turbo',
        messages: [
          //Write random delicious recipes
           OpenAIChatCompletionChoiceMessageModel(
            content: secondMainText,
            role: OpenAIChatMessageRole.system,
          ),
          OpenAIChatCompletionChoiceMessageModel(
            content: promptText,
            role: OpenAIChatMessageRole.user,
          )
        ],
      );
      chatStream.listen((streamChatCompletion) {
        final content = streamChatCompletion.choices.first.delta.content;
        setState(() {
          recipe += content ?? '';
        });
      }) .onDone(() {
        setState(() {
          isLoading = false;
        });
      });
    } on RequestFailedException catch (e) {
      isLoading = false;
    }
  }


  Future<void> logout() async {
    try {
      Navigator.pop(context, 'logout-success'.i18n());
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack);
    }
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    flutterTts.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String getLang() {
      var myLocale = Localizations.localeOf(context);
      switch (myLocale.languageCode) {
        case 'en':
          return 'en-Us';
        case 'tr':
          return 'tr-Tr';
        case 'de':
          return 'de-DE';
        case 'fr':
          return 'fr-FR';
        case 'it':
          return 'it-IT';
        case 'es':
          return 'es-ES';
        default:
          return 'en-US';
      }
    }

    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return Scaffold(
            appBar: CustomAppBar(isHomePage: false, isLoggedIn: isLoggedIn),
            body: SingleChildScrollView(
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      height: 50,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10.0, right: 10.0),
                        child: Center(
                          child: Text(
                            'generator-title'.i18n(),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(
                        child: isStreaming ?
                        const CircularProgressIndicator(color: Colors.green,)
                            : (recipe.isEmpty)
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 100),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey[300],
                                      ),
                                      padding: const EdgeInsets.all(10),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey[250],
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        child: Center(
                                          child: SizedBox(
                                            height: 100,
                                            width: 100,
                                            child: FittedBox(
                                              child: Material(
                                                type: MaterialType.circle,
                                                color: Colors.green
                                                    .shade800, // Button color
                                                elevation: 4, // Shadow
                                                child: InkWell(
                                                  onTap: isStreaming ? null
                                                        : generateText,
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(
                                                      20,
                                                    ),
                                                    child: FaIcon(
                                                      FontAwesomeIcons.robot,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey[250],
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey[200],
                                          ),
                                          padding: const EdgeInsets.all(10),
                                          child: FloatingActionButton(
                                            onPressed: () async {
                                              isSubscription = memberShip
                                                  .isSubscribedCheckSync();
                                              myLanguage = getLang();
                                              await flutterTts.setLanguage(
                                                myLanguage ?? 'en-US',
                                              );
                                              await flutterTts
                                                  .setSpeechRate(0.5);

                                              if (!isPlaying) {
                                                setState(() {
                                                  isPlaying = true;
                                                });
                                                await flutterTts.speak(recipe);
                                              } else {
                                                await flutterTts.pause();
                                                setState(() {
                                                  isPlaying = false;
                                                });
                                              }
                                            },
                                            tooltip: isPlaying
                                                ? 'pause.recipe'.i18n()
                                                : 'read-recipe'.i18n(),
                                            child: Icon(
                                              isPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SingleChildScrollView(
                                        // Avoid overflow
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: <Widget>[
                                            Padding(
                                              padding: const EdgeInsets
                                                  .all(8.0),
                                              child: Text(
                                                recipe,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                            ),
                                            SizedBox(
                                              width: 200,
                                              height: 50,
                                              child: (isStreaming &&
                                                  recipes.length>20) ?
                                              const SizedBox.shrink() :
                                              IconButton(
                                                onPressed: isLoading ? null
                                                    : () async {
                                                  await Share.share(recipe);

                                                }, icon: const Icon(Icons.share),
                                                
                                              ),
                                            ),
                                            SizedBox(
                                              width: MediaQuery.of(context).size.width*0.65,
                                              height: 50,
                                              child: (isStreaming &&
                                                  recipes.length>20) ?
                                              const SizedBox.shrink() :
                                                ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                      15,
                                                    ), // rounded corners
                                                  ),
                                                  elevation: 5, // add shadow
                                                  backgroundColor:
                                                  isLoading ? Colors.grey :
                                                  Colors.green.shade800,
                                                ),
                                                onPressed: isLoading ? null
                                                    : () async {
                                                  isSubscription = memberShip
                                                      .isSubscribedCheckSync();
                                                  if (isSubscription == false
                                                      && _interstitialAd
                                                          != null) {
                                                await _interstitialAd?.show();
                                                  }

                                                  setState(() {
                                                    recipe = '';
                                                    isPlaying = false;
                                                  });


                                                  await flutterTts.pause();
                                                },
                                                  child: Align(
                                                  child: Text(
                                                    'generator-other-button'
                                                      .i18n(),),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                    const SizedBox(
                      height: 50,
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
                    Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Center(
                        child: Text(
                          'generator-warning-text'.i18n(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar:
                CustomBottomBar(
                  isSubscription: isSubscription,
                  flutterTts: flutterTts,
                ),
          );
        } else {
          return const RedirectLoginPage();
        }
      },
    );
  }
}
