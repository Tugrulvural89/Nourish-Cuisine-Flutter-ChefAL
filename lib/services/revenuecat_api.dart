import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueApi {
  bool isSubscribed = false;
  Future<bool> initPlatformState() async {
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
    isSubscribed = await isSubscribedCheck();
    return isSubscribed;
  }

  Future<bool> isSubscribedCheck() async {
    var customerInfo = await Purchases.getCustomerInfo();
    if (customerInfo.entitlements.all.containsKey('Pro')) {
      if (customerInfo.entitlements.all['Pro'] != null) {
        isSubscribed = customerInfo.entitlements.all['Pro']!.isActive;
      }
    }
    return isSubscribed;
  }

  bool isSubscribedCheckSync() {
    Purchases.addCustomerInfoUpdateListener((info) {
      // handle any changes to customerInfo
      if (info.entitlements.all.containsKey('Pro')) {
        if (info.entitlements.all['Pro'] != null) {
          isSubscribed = info.entitlements.all['Pro']!.isActive;
        }
      }
    });
    return isSubscribed;
  }


}
