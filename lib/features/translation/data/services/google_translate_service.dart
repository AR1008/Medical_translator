// ignore_for_file: avoid_print

import 'package:translator/translator.dart';

class GoogleTranslateService {
  final GoogleTranslator _translator = GoogleTranslator();

  Future<String> translate(String text, String from, String to) async {
    try {
      if (text.isEmpty) return '';
      
      print('🔄 Translating: $text');
      final translation = await _translator.translate(text, from: from, to: to);
      print('✅ Translated: ${translation.text}');
      
      return translation.text;
    } catch (e) {
      print('❌ Translation error: $e');
      return text; // Return original if translation fails
    }
  }
}
