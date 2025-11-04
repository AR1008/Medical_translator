import 'package:translator/translator.dart';

class TranslationService {
  final GoogleTranslator _translator = GoogleTranslator();

  Future<String> translate(String text, String from, String to) async {
    try {
      if (text.isEmpty) return '';
      
      final translation = await _translator.translate(
        text,
        from: from,
        to: to,
      );
      
      return translation.text;
    } catch (e) {
      print('❌ Translation error: $e');
      return text; // Return original if translation fails
    }
  }
}
