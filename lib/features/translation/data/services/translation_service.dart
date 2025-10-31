import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TranslationService {
  final GoogleTranslator _translator = GoogleTranslator();
  final FlutterTts _flutterTts = FlutterTts();

  TranslationService() {
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<String> translate(String text, String fromLang, String toLang) async {
    try {
      final translation = await _translator.translate(
        text,
        from: fromLang,
        to: toLang,
      );
      return translation.text;
    } catch (e) {
      print('Translation error: $e');
      return text;
    }
  }

  Future<void> speak(String text, String language) async {
    try {
      // Map language codes to TTS codes
      String ttsLang = language;
      if (language == 'kn') {
        ttsLang = 'kn-IN'; // Kannada - India
      } else if (language == 'en') {
        ttsLang = 'en-US';
      }
      
      await _flutterTts.setLanguage(ttsLang);
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS error: $e');
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  // Language mapping
  static const Map<String, String> languages = {
    'English': 'en',
    'Kannada': 'kn',
    'Hindi': 'hi',
    'Tamil': 'ta',
    'Telugu': 'te',
    'Malayalam': 'ml',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Arabic': 'ar',
  };

  static String getLanguageCode(String languageName) {
    return languages[languageName] ?? 'en';
  }

  static String getLanguageName(String code) {
    return languages.entries
        .firstWhere((entry) => entry.value == code, orElse: () => const MapEntry('English', 'en'))
        .key;
  }
}
