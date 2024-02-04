import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';


class SharePlusWidget extends StatelessWidget {
  final Map<String, dynamic> shareData;

  const SharePlusWidget({super.key, required this.shareData});


   void _shareContent() {
     final String shareText =  shareData['text'] ?? 'No Share Content';
     print(shareText);
     Share.share(shareText);
   }

  @override
  Widget build(BuildContext context) {
    return IconButton(onPressed: _shareContent, icon: const Icon(Icons.share));
  }
}