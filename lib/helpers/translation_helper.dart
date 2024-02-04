import 'package:translator/translator.dart';

class TranslationHelper {
  final GoogleTranslator _translator;
  final Map<String, String> _translatedTextMap;

  TranslationHelper() :
        _translator = GoogleTranslator(),
        _translatedTextMap = {};

  Future<String> translateTextAndCache(String text, String targetLanguage,
      String fromLanguage,) async {
    if (targetLanguage == 'en') {
      final translation = text;
      return translation;
    } else {
      if (_translatedTextMap.containsKey(text)) {
        return _translatedTextMap[text]!;
      } else {
        final translation = await translateText(text, targetLanguage,
            fromLanguage,);
        _translatedTextMap[text] = translation;
        return translation;
      }
    }

  }

  Future<String> translateText(String text, String targetLanguage,
      String fromLanguage,) async {
    if (targetLanguage == 'en') {
      final translation = text;
      return translation;
    } else {
      final translation = await _translator.translate(text, to: targetLanguage,
          from: fromLanguage,);
      return translation.text;
    }

  }
}
