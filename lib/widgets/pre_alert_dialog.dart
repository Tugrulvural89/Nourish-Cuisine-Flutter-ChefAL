import 'package:flutter/material.dart';
import 'package:localization/localization.dart';

class CustomAlertDialog extends StatelessWidget {
  final bool isSubscription;

  const CustomAlertDialog({super.key, required this.isSubscription});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'daily-limit-exceed'.i18n(),
      ),
      content: isSubscription
          ? Text(
              'try-tomorrow-premium-users'.i18n(),
            )
          : Text(
              'diet-body-warning'.i18n(),
            ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('close'.i18n()),
        ),
        (!isSubscription)
            ? TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/payWall',
                    (Route route) => false,
                  );
                },
                child: Text(
                  'buy-pre-withPrice'.i18n(),
                ),
              )
            : TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/recipes',
                    (Route route) => false,
                  );
                },
                child: Text(
                  'go-to-main-page'.i18n(),
                ),
              ),
      ],
    );
  }
}
