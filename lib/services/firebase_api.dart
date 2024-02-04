import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firestore_service.dart';

class FirebaseApi {
  static FirebaseMessaging messaging = FirebaseMessaging.instance;
  static FirestoreService firestoreService = FirestoreService();
  static FirebaseAuth auth = FirebaseAuth.instance;

  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {}

  static Future<void> initNotifications() async {
    var user = auth.currentUser;
    var currentUserId = user?.uid;
    // Subscribe to the Firebase Auth state change stream.
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      // If the user is signed in, subscribe to the topic "news".
      if (user != null) {
        FirebaseMessaging.instance.subscribeToTopic('login');
      } else {
        FirebaseMessaging.instance.unsubscribeFromTopic('anonymous');
      }
    });

    var settings = await messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      var fcmToken = await messaging.getToken();
      if (user != null && fcmToken != null) {
        await firestoreService.saveFCMToken(fcmToken, currentUserId!);
      }
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {});
    }
  }
}


