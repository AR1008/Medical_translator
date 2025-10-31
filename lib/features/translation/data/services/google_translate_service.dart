import 'package:translator/translator.dart';

class GoogleTranslateService {
  final GoogleTranslator _translator = GoogleTranslator();

  Future<String> translate(String text, String from, String to) async {
    try {
      print('🌐 Translating: $text from $from to $to');
      final translation = await _translator.translate(
        text,
        from: from,
        to: to,
      );
      print('✅ Translation: ${translation.text}');
      return translation.text;
    } catch (e) {
      print('❌ Translation error: $e');
      return text; // Return original text on error
    }
  }

  Future<String> translateToKannada(String englishText) async {
    return await translate(englishText, 'en', 'kn');
  }

  Future<String> translateToEnglish(String kannadaText) async {
    return await translate(kannadaText, 'kn', 'en');
  }

  Future<String> autoTranslate(String text, String targetLanguage) async {
    // Auto-detect source language and translate
    return await translate(text, 'auto', targetLanguage);
  }
}
