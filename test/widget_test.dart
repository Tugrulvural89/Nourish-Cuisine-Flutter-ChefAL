// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nourish/pages/search/search_form.dart';
import 'package:nourish/services/firebase_api.dart';
import 'package:nourish/store_config.dart';
import 'package:nourish/utils/constant.dart';
import 'package:purchases_flutter/models/store.dart';
void main() {
  setUpAll(() async {
    // Firebase initialization
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    // Get the instance of FirebaseCrashlytics
    FirebaseCrashlytics.instance;

    // Enable Crashlytics data collection feature
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    // Enable automatic error capturing feature
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

    // Initialize Firebase Messaging
    await FirebaseApi.initNotifications();

    // Other Firebase initialization steps specific to your project

    // Set StoreConfig based on platform
    if (Platform.isIOS) {
      // Set StoreConfig for iOS platform
      StoreConfig(store: Store.appStore, apiKey: appleApiKey);
    } else if (Platform.isAndroid) {
      // Set StoreConfig for Android platform
      StoreConfig(store: Store.playStore, apiKey: googleApiKey);
    }
  });

  testWidgets('Test recipe search form widget', (WidgetTester tester) async {
    // Build the widget
    await tester.pumpWidget(const RecipeSearchFormWidget());

    // Verify that the banner ad is loaded
    expect(find.byType(BannerAd), findsOneWidget);
  });
}


