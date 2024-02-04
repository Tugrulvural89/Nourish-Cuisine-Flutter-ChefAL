import 'dart:io';

import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:localization/localization.dart';
import 'package:lottie/lottie.dart';
import 'package:nourish/pages/chat/chat_detail.dart';
import 'package:page_transition/page_transition.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../bloc/authentication/authentication_bloc.dart';
import '../pages/recipe_generator.dart';
import '../services/firebase_api.dart';
import '../store_config.dart';
import '../utils/constant.dart';
import 'firebase_options.dart';
import 'pages/diet/diet_list_screen.dart';
import 'pages/diet/diyet_screen.dart';
import 'pages/generate_with_ai_page.dart';
import 'pages/notes/notes_page.dart';
import 'pages/search/food_search.dart';
import 'pages/search/search_form.dart';
import 'pages/subs_list.dart';
import 'pages/user_account_page.dart';
import 'pages/views/email_verification_page.dart';
import 'pages/views/login_page.dart';
import 'pages/views/sign_up.dart';

void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await MobileAds.instance.initialize();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await dotenv.load();
    var appleApiKey = dotenv.get('appleApiKey');
    var googleApiKey = dotenv.get('googleApiKey');
    if (Platform.isIOS) {
      StoreConfig(store: Store.appStore, apiKey: appleApiKey);
    } else if (Platform.isAndroid) {
      StoreConfig(store: Store.playStore, apiKey: googleApiKey);
    }
    Future.delayed(const Duration(seconds: 3), FirebaseApi.initNotifications);
    runApp(const MyApp());

}


class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    LocalJsonLocalization.delegate.directories = ['lib/i18n'];
    return BlocProvider<AuthenticationBloc>(
      create: (context) => AuthenticationBloc(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          // delegate from flutter_localization
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          // delegate from localization package.
          LocalJsonLocalization.delegate,
        ],
        supportedLocales: const <Locale>[
          Locale('en'),
          Locale('tr'),
          Locale('fr'),
          Locale('it'),
          Locale('es'),
          Locale('de'),

        ],
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)
          ],
          initialRoute: '/',
          routes: {
            '/recipes': (context) => const RecipeGenerator(),
            '/login': (context) => const LoginPage(),
            '/notes': (context) => const NotesPage(),
            '/createDiet': (context) => const DietForm(),
            '/emailVerification': (context) => const EmailVerificationScreen(),
            '/signUp': (context) => const SignUpPage(),
            '/dietsList': (context) => const DietListWidget(),
            '/payWall' : (context) => const Paywall(),
            '/foodSearch': (context) => const FoodSearch(),
            '/generatorAI': (context) => const RecipeGeneratorWithAi(),
            '/recipeSearch': (context) => const RecipeSearchFormWidget(),
            '/userPage': (context) => const UserAccountWidget(),
            '/chat' : (context) => const ChatDetailPageWidget(),
          },
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: const ColorScheme.light(
                primary: Colors.green,
                secondary: Colors.black,
                onSecondary: Colors.white,
            ),
            appBarTheme: AppBarTheme(
              color: Colors.green.shade800,
            ),
            inputDecorationTheme: const InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
            ),
            cardTheme: const CardTheme(
              elevation: 4,
              shadowColor: Colors.grey,
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all<Color>(Colors.green.shade800),
                foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                textStyle: MaterialStateProperty.all<TextStyle>(
                  const TextStyle(fontSize: 16),
                ),
                shape: MaterialStateProperty.all<OutlinedBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all<Color>(Colors.black),
                padding: MaterialStateProperty.all<EdgeInsets>(
                    const EdgeInsets.all(10),
                ),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                ),
              ),
            ),
            textTheme: const TextTheme(
                titleLarge: TextStyle(fontSize: 26,
                    fontWeight: FontWeight.bold,
                ),
                titleMedium: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.normal,
                ),
                bodySmall : TextStyle(fontSize:12,
                    fontWeight: FontWeight.normal,
                ),
                titleSmall: TextStyle(fontSize:10,
                    fontWeight: FontWeight.bold, color: Colors.white,
                ),
              labelSmall: TextStyle(fontSize: 9,
                  fontWeight:FontWeight.bold, color: Colors.white,
              ),
              bodyLarge: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
              ),
            ),
          ),
          home: const SplashPage(),
        ),
    );

  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});


  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      splash: SizedBox(
        height: 500,
        width: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/splashanim.json'),
              Center(
                child: Text(
                  'splash-welcome-text'.i18n(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],



          ),
        ),
      ),
      splashTransition: SplashTransition.fadeTransition,
      duration: 2000,
      splashIconSize: double.infinity,
      pageTransitionType: PageTransitionType.fade,
       nextScreen: const RecipeGenerator(),
    );
  }
}
