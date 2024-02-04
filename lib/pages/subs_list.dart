import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:localization/localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../helpers/ad_helper.dart';
import '../utils/constant.dart';

class Paywall extends StatefulWidget {
  const Paywall({super.key});

  @override
  _PaywallState createState() => _PaywallState();
}

class _PaywallState extends State<Paywall> {
  Offering? offering;
  bool isSubscribed = false;
  bool isLoading = false;
  late double buttonWidthSize;

  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    isSubscribedCheck();

    if (isSubscribed == false) {
      _loadFirstBannerAd();
    }
  }

  Future<void> getOffer() async {
    try {
      var offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        setState(() {
          offering = offerings.current!;
        });
      }
    } on PlatformException catch (e, stackTrace) {
      // Handle the error as per your requirements
      await FirebaseCrashlytics.instance.recordError(e, stackTrace);
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

  Future<void> initPlatformState() async {
    await dotenv.load(fileName: './.env');
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
    }
    await getOffer();
  }

  Future<String> isSubscribedCheck() async {
    var customerInfo = await Purchases.getCustomerInfo();
    if (customerInfo.entitlements.all.containsKey('Pro')) {
      if (customerInfo.entitlements.all['Pro'] != null) {
        setState(() {
          isSubscribed = customerInfo.entitlements.all['Pro']!.isActive;
        });
      }
    }
    return customerInfo.toString();
  }

  Future<bool> restorePurchase() async {
    try {
      var customerInfo = await Purchases.restorePurchases();
      // ... check restored purchaserInfo to see if entitlement is now active
      if (customerInfo.entitlements.all.containsKey('Pro')) {
        if (customerInfo.entitlements.all['Pro'] != null) {
          setState(() {
            isSubscribed = customerInfo.entitlements.all['Pro']!.isActive;
          });
        }
      }
    } on PlatformException catch (e) {
      isSubscribed = false;
    }
    return isSubscribed;
  }

  Future<void> makePurchase(int index) async {
    setState(() {
      isLoading = true;
    });
    try {
      var offerings = await Purchases.getOfferings();
      if (offerings.current != null &&
          offerings.current?.availablePackages != null) {
        var package = offerings.current!.availablePackages[index];
        await Purchases.purchasePackage(package).then(
          (value) {
            addPackageToFirestore(package, FirebaseAuth.instance.currentUser!);
            Navigator.pushNamed(context, '/recipes');
          },
          onError: showDialogPurchase,
        );
      } else {
        await Fluttertoast.showToast(msg: 'purchases-unsuccessful'.i18n());
      }
    } on PlatformException catch (e) {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('error'.i18n()),
            content: Text('error-purchase $e'.i18n()),
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
    setState(() {
      isLoading = false;
    });
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

  @override
  void dispose() {
    if (_bannerAd != null) {
      _bannerAd?.dispose();
    }
    super.dispose();
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addPackageToFirestore(Package package, User user) async {
    final timestamp = Timestamp.now(); // Generate a timestamp
    final packageData = {
      'identifier': package.identifier,
      'packageType': package.packageType.toString(),
      'timestamp': timestamp,
      'storeProduct': {
        'identifier': package.storeProduct.identifier,
        'description': package.storeProduct.description,
        'title': package.storeProduct.title,
        'price': package.storeProduct.price,
        'priceString': package.storeProduct.priceString,
        'currencyCode': package.storeProduct.currencyCode,
        'introductoryPrice': {
          'price': package.storeProduct.introductoryPrice?.price,
          'priceString': package.storeProduct.introductoryPrice?.priceString,
          'period': package.storeProduct.introductoryPrice?.period.toString(),
          'cycles': package.storeProduct.introductoryPrice?.cycles,
          'periodUnit':
              package.storeProduct.introductoryPrice?.periodUnit.toString(),
          'periodNumberOfUnits':
              package.storeProduct.introductoryPrice?.periodNumberOfUnits,
        },
        'discounts': package.storeProduct.discounts,
        'productCategory': package.storeProduct.productCategory.toString(),
      },
      'offeringIdentifier': package.offeringIdentifier,
      'subscriptionPeriod': package.storeProduct.subscriptionPeriod.toString(),
    };
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('packages')
        .add(packageData);
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
    if (totalWidth > 600) {
      buttonWidthSize = 0.4;
    } else {
      buttonWidthSize = 0.7;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('premium-purchase'.i18n()),
      ),
      body: SingleChildScrollView(
        child: isLoading
            ? SizedBox(
                child: Center(
                  child: LoadingAnimationWidget.staggeredDotsWave(
                    size: 50,
                    color: Colors.green,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(
                        height: 9,
                      ),
                      Text('text-purchase-screen-title'.i18n()),
                      const SizedBox(
                        height: 9,
                      ),
                      Text('text-purchase-screen-body'.i18n()),
                      const SizedBox(
                        height: 9,
                      ),
                      Column(
                        children: [
                          const SizedBox(
                            height: 9,
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.red),
                              Expanded(
                                child:
                                    Text('text-purchase-screen-body1'.i18n()),
                              )
                            ],
                          ),
                          const SizedBox(
                            height: 9,
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.red),
                              Expanded(
                                child:
                                    Text('text-purchase-screen-body2'.i18n()),
                              )
                            ],
                          ),
                          const SizedBox(
                            height: 9,
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.red),
                              Expanded(
                                child:
                                    Text('text-purchase-screen-body3'.i18n()),
                              )
                            ],
                          ),
                          const SizedBox(
                            height: 9,
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.red),
                              Expanded(
                                child:
                                    Text('text-purchase-screen-body4'.i18n()),
                              )
                            ],
                          ),
                          const SizedBox(
                            height: 9,
                          ),
                        ],
                      ),
                      (offering != null)
                          ? ListView.builder(
                              itemCount: offering!.availablePackages.length,
                              shrinkWrap: true,
                              physics: const ClampingScrollPhysics(),
                              itemBuilder: (BuildContext context, int index) {
                                var myProductList = offering!.availablePackages;
                                //TODO: reject sub
                                return Card(
                                  elevation: 7,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Column(
                                      children: <Widget>[
                                        ListTile(
                                          title: Text(
                                            myProductList[index]
                                                .storeProduct
                                                .title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          subtitle: Text(
                                            myProductList[index]
                                                .storeProduct
                                                .description,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                          trailing: Text(
                                            myProductList[index]
                                                .storeProduct
                                                .priceString,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            await makePurchase(index);
                                          },
                                          child: Text('get-now'.i18n()),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : Column(
                              children: [
                                Center(
                                  child: LoadingAnimationWidget.waveDots(
                                    size: 50,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
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
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width *
                                buttonWidthSize,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/recipes',
                                  (route) => false,
                                );
                              },
                              child: Text('continue-without-purchase'.i18n()),
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width *
                                buttonWidthSize,
                            child: ElevatedButton(
                              onPressed: () async {
                                await restorePurchase().then(
                                  (value) {
                                    if(value == true){
                                      showDialogPurchaseSuccessful();
                                    } else {
                                      showDialogPurchase('restore-purchase-unsuccessful'.i18n());
                                    }
                                  },
                                  onError: showDialogPurchase,
                                );
                              },
                              child: Text('restore-purchase'.i18n()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 9,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
