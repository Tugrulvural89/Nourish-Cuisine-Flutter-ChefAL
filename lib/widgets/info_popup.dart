import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import 'package:shared_preferences/shared_preferences.dart';


class InfoPopup {
  static Future<void> show(BuildContext context, String title, String body,
      String param,) async {
    var prefs = await SharedPreferences.getInstance();

    var showPopup = prefs.getBool(param) ?? true;
    Future.delayed( const Duration(seconds: 2), () {

    } );
    if(context.mounted) {
      if (showPopup) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(title, style: Theme.of(context)
                  .textTheme.titleMedium,),
              content: Text(body,
                style: Theme.of(context).textTheme.bodySmall,),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('close'.i18n(), style: Theme.of(context)
                      .textTheme.bodySmall,),
                ),
                TextButton(
                  onPressed: () {
                    prefs.setBool(param, false);
                    Navigator.pop(context);
                  },
                  child: Text('dont-show-again'.i18n(),
                    style: Theme.of(context).textTheme.bodySmall,),
                ),
              ],
            );
          },
        );
      }
    }

  }
}




