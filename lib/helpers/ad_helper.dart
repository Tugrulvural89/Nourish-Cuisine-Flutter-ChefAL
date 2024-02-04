import 'dart:io';

class AdHelper {

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3023241293141783/1703536009';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3023241293141783/1817455760';
    } else {
      throw  UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3023241293141783/7803445465';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3023241293141783/4816784503';
    } else {
      throw  UnsupportedError('Unsupported platform');
    }
  }

  static String get altBannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3023241293141783/7792107649';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3023241293141783/2731352659';
    } else {
      throw  UnsupportedError('Unsupported platform');
    }
  }

}