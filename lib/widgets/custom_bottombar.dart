import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:localization/localization.dart';

import '../helpers/ad_helper.dart';
import '../pages/diet/diyet_screen.dart';

class CustomBottomBar extends StatefulWidget {
  final bool isSubscription;
  final FlutterTts? flutterTts;
  const CustomBottomBar({super.key,
  required this.isSubscription, this.flutterTts,
  });


  @override
   _CustomBottomBarState createState() => _CustomBottomBarState() ;

}

class _CustomBottomBarState  extends State<CustomBottomBar> {


  InterstitialAd? _interstitialAd;



  @override
  void initState () {
    super.initState();
    if (widget.flutterTts != null) {
      widget.flutterTts?.pause();
    }
    if (widget.isSubscription==false) {
      if (_interstitialAd == null) {
        _loadInterstitialAd();
      }
    }

  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    if (widget.flutterTts != null) {
      widget.flutterTts?.pause();
    }
    super.dispose();
  }

  
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              //redirect callbacks close the ads
            },
          );

          setState(() {
            _interstitialAd = ad;
          });
        },
        onAdFailedToLoad: (err) {
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 80,
      color: Colors.green.shade800,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          height:  70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  IconButton(
                    onPressed: () {
                       _showAds();
                       Navigator.push(context,
                       MaterialPageRoute(
                           builder: (context)=> const DietForm(),),);
                    },
                    icon: const Icon(Icons.add),
                    color: Colors.white,
                  ),
                  Text('diet'.i18n(),
                    style: Theme.of(context).textTheme.titleSmall,)
                ],
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: () {
                      _showAds();
                      Navigator.of(context).pushNamed('/foodSearch');
                    },
                    icon: const FaIcon(
                      FontAwesomeIcons.searchengin,
                    ),
                    color: Colors.white,
                  ),
                  Text('food-search'.i18n(), style: Theme.of(context)
                      .textTheme.titleSmall,)
                ],
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: () {
                      _showAds();
                      Navigator.of(context).pushNamed('/generatorAI');
                    },
                    icon: const FaIcon(
                      FontAwesomeIcons.robot,
                    ),
                    color: Colors.white,
                  ),
                  Text('generate-ai'.i18n(), style: Theme.of(context)
                      .textTheme.titleSmall,)
                ],
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: () {
                      _showAds();
                      Navigator.of(context).pushNamed('/recipeSearch');
                    },
                    icon: const Icon(Icons.search),
                    color: Colors.white,
                  ),
                  Text('search-recipe'.i18n(), style: Theme.of(context)
                      .textTheme.titleSmall,)
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAds() {
      if (widget.isSubscription==false) {
        _interstitialAd?.show();

    }
  }
}
