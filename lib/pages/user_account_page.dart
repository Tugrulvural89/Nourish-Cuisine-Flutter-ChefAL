import 'dart:async';
import 'dart:core';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:localization/localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/authentication/authentication_bloc.dart';
import '../helpers/ad_helper.dart';
import '../services/revenuecat_api.dart';
import '../utils/constant.dart';
import 'recipe_generator.dart';
import 'views/update_pass.dart';

class UserAccountWidget extends StatefulWidget {
  const UserAccountWidget({super.key});

  @override
  _UserAccountWidgetState createState() => _UserAccountWidgetState();
}

class _UserAccountWidgetState extends State<UserAccountWidget> {
  User? user;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool isSubscription = false;
  final RevenueApi memberShip = RevenueApi();
  BannerAd? _bannerAd;
  late StreamSubscription<User?> _userChangesSubscription;
  late String timeString;
  late String userName;
  bool isLoggedIn = true;
  double buttonWidthSize = 0.50;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _userChangesSubscription = _auth.userChanges().listen((User? user) {
      setState(() {
        this.user = user;
      });
    });

    Purchases.addCustomerInfoUpdateListener((info) {
      if (info.entitlements.all.containsKey('Pro')) {
        if (info.entitlements.all['Pro'] != null) {
          isSubscription = info.entitlements.all['Pro']!.isActive;
        }
      }
    });
    if (isSubscription == false) {
      // Load first banner ad
      _loadFirstBannerAd();
    }
  }

  Future<void> _deleteUser(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('delete-user'.i18n()),
          content: Text('are-you-sure-delete-this-user'.i18n()),
          actions: <Widget>[
            TextButton(
              child: Text('cancel'.i18n()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('are-you-sure'.i18n()),
              onPressed: () async {
                try {
                  BlocProvider.of<AuthenticationBloc>(context).logOut();
                  await user?.delete();
                  isLoggedIn = await _googleSignIn.isSignedIn();
                  if (isLoggedIn == true) {
                    await _googleSignIn.signOut();
                  }
                  isLoggedIn = FirebaseAuth.instance.currentUser != null;
                  if (isLoggedIn == true) {
                    await _auth.signOut();
                  }
                  if (isLoggedIn == false) {
                    setState(() {
                      isLoggedIn = false;
                    });
                  }
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecipeGenerator(),
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('error: $e'),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> initPlatformState() async {
    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      var androidKey = dotenv.get('REVENUECATANDROIDKEY');
      configuration = PurchasesConfiguration(androidKey);
      await Purchases.configure(configuration);
    } else if (Platform.isIOS) {
      var iosKey = dotenv.get('REVENUECATIOSKEY');
      configuration = PurchasesConfiguration(iosKey);
      await Purchases.configure(
        configuration..appUserID = FirebaseAuth.instance.currentUser!.uid,
      );
      // Later log in provided user Id
    }
  }

  String getName(User? user) {
    if (user != null) {
      userName = user.email ?? 'not-available'.i18n();
    } else {
      userName = 'unknown';
    }
    setState(() {
      userName = userName;
    });
    return userName;
  }

  String getTime(User? user) {
    if (user != null) {
      timeString = user.metadata.creationTime != null
          ? DateFormat.yMMMd().format(user.metadata.creationTime!)
          : 'not-available'.i18n();
    } else {
      timeString = 'unkown';
    }
    setState(() {
      timeString = timeString;
    });

    return timeString;
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

  Future<bool> restorePurchase() async {
    try {
      var customerInfo = await Purchases.restorePurchases();
      // ... check restored purchaserInfo to see if entitlement is now active
      if (customerInfo.entitlements.all.containsKey('Pro')) {
        if (customerInfo.entitlements.all['Pro'] != null) {
          setState(() {
            isSubscription = customerInfo.entitlements.all['Pro']!.isActive;
          });
        }
      }
    } on PlatformException catch (e) {
      isSubscription = false;
    }
    return isSubscription;
  }


  void showDialogPurchaseSuccessful() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('congratulations'.i18n()),
          content: Text('successful-purchase'.i18n()),
          actions: [
            TextButton(
              child: Text('ok'.i18n()),
              onPressed: () {
                Navigator.of(context).pushNamed('/recipes');
              },
            ),
          ],
        );
      },
    );
  }


  void showDialogPurchase(error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('error'.i18n()),
          content: Text('error-purchase $error'.i18n()),
          actions: [
            TextButton(
              child: Text('ok'.i18n()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _userChangesSubscription.cancel(); // Cancel the subscription
    super.dispose();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> _launchUrl(_url) async {
    final url = Uri.parse(_url);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalWidth = MediaQuery.of(context).size.width;
    if (totalWidth>600){
      buttonWidthSize = 0.4;
    } else {
      buttonWidthSize = 0.7;
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/recipes',
              (route) => false,
            );
          },
          icon: const FaIcon(
            FontAwesomeIcons.house,
            color: Colors.white,
          ),
        ),
        title: Text('account'.i18n()),
        actions: [
          IconButton(
            onPressed: () async {
              await signOut().then((_) {
                BlocProvider.of<AuthenticationBloc>(context).logOut();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecipeGenerator(),
                  ),
                );
              });
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('email'.i18n()),
            subtitle: Text(getName(user)),
          ),
          ListTile(
            title: Text('register-on'.i18n()),
            subtitle: Text(getTime(user)),
          ),
          ListTile(
            title: Text('active-sub-bool'.i18n()),
            subtitle:
                isSubscription ? Text('$isSubscription') : Text('no'.i18n()),
          ),
          // if (_activeSubscriptions.isNotEmpty)
          //   for (String itemActive in _activeSubscriptions)
          //     ListTile(
          //       title: Text(itemActive),
          //     ),
          const SizedBox(
            height: 20,
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * buttonWidthSize,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 4,
                ),
                onPressed: () async {
                  await restorePurchase().then(
                        (value) {
                      if(value == true){
                        showDialogPurchaseSuccessful();
                      } else {
                        showDialogPurchase(
                            'restore-purchase-unsuccessful'.i18n(),
                        );
                      }
                    },
                  );
                },
                child: Text('restore-purchase'.i18n()),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * buttonWidthSize,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 4,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UpdatePasswordScreen(),
                    ),
                  );
                },
                child: Text('forgot-password'.i18n()),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * buttonWidthSize,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 4,
                ),
                onPressed: () {
                  _deleteUser(context);
                },
                child: Text('delete-user'.i18n()),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  //canLaunchUrl(Uri.parse(policyUrl));
                  _launchUrl(policyUrl);
                },
                child: Text('privacy-policy'.i18n()),
              ),
              TextButton(
                onPressed: () {
                  _launchUrl(eulaUrl);
                },
                child: Text('terms-and-conditions'.i18n()),
              )
            ],
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
        ],
      ),
    );
  }
}
