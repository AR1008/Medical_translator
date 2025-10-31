import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/services/google_translate_service.dart';

class TranslationScreen extends ConsumerStatefulWidget {
  const TranslationScreen({super.key});

  @override
  ConsumerState<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends ConsumerState<TranslationScreen> {
  final GoogleTranslateService _translateService = GoogleTranslateService();
  final FlutterTts _tts = FlutterTts();
  late stt.SpeechToText _speech;
  final _sourceTextController = TextEditingController();
  
  String _sourceLanguage = 'en';
  String _targetLanguage = 'kn';
  String _translatedText = '';
  bool _isListening = false;
  bool _isTranslating = false;
  bool _speechAvailable = false;
  String _lastError = '';
  List<String> _availableLanguages = [];
  bool _kannadaTTSAvailable = false;
  
  final Map<String, String> _languages = {
    'en': 'English',
    'kn': 'ಕನ್ನಡ (Kannada)',
    'hi': 'हिंदी (Hindi)',
    'ta': 'தமிழ் (Tamil)',
    'te': 'తెలుగు (Telugu)',
    'ml': 'മലയാളം (Malayalam)',
  };

  final Map<String, String> _ttsLanguageCodes = {
    'en': 'en-US',
    'kn': 'kn-IN',
    'hi': 'hi-IN',
    'ta': 'ta-IN',
    'te': 'te-IN',
    'ml': 'ml-IN',
  };

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTTS();
  }

  @override
  void dispose() {
    _sourceTextController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    _speech = stt.SpeechToText();
    
    try {
      final status = await Permission.microphone.request();
      print('🎤 Microphone permission: $status');
      
      if (status.isGranted) {
        bool available = await _speech.initialize(
          onStatus: (status) {
            print('Speech status: $status');
            if (status == 'done' || status == 'notListening') {
              if (mounted) {
                setState(() => _isListening = false);
              }
            }
          },
          onError: (error) {
            print('❌ Speech error: ${error.errorMsg}');
            _lastError = error.errorMsg;
            if (mounted) {
              setState(() => _isListening = false);
              
              String message = 'Speech recognition error';
              if (error.errorMsg == 'error_no_match') {
                message = 'No speech detected. Please speak clearly.';
              } else if (error.errorMsg == 'error_speech_timeout') {
                message = 'Speech timeout. Please try again.';
              } else if (error.errorMsg == 'error_audio') {
                message = 'Microphone error. Try a real device if using emulator.';
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.orange,
                  action: SnackBarAction(label: 'OK', onPressed: () {}),
                ),
              );
            }
          },
          debugLogging: true,
        );
        
        setState(() => _speechAvailable = available);
        print('✅ Speech available: $available');
      }
    } catch (e) {
      print('❌ Speech initialization error: $e');
      setState(() => _lastError = 'Failed to initialize speech: $e');
    }
  }

  Future<void> _initializeTTS() async {
    try {
      // Set up TTS event handlers
      _tts.setStartHandler(() {
        print('🔊 TTS Started');
      });

      _tts.setCompletionHandler(() {
        print('✅ TTS Completed');
      });

      _tts.setErrorHandler((msg) {
        print('❌ TTS Error: $msg');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Speech error: $msg'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });

      // Get available languages
      var languages = await _tts.getLanguages;
      if (languages != null) {
        _availableLanguages = List<String>.from(languages);
        print('📋 Available TTS languages: $_availableLanguages');
        
        // Check if Kannada is available
        _kannadaTTSAvailable = _availableLanguages.any((lang) => 
          lang.toLowerCase().contains('kn') || 
          lang.toLowerCase().contains('kannada')
        );
        
        print(_kannadaTTSAvailable 
          ? '✅ Kannada TTS is available' 
          : '❌ Kannada TTS NOT available - will show instructions');
      }

      // Set default properties
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45); // Slower for better clarity
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      
      print('✅ TTS initialized');
    } catch (e) {
      print('❌ TTS initialization error: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      _showSpeechNotAvailableDialog();
      return;
    }

    await _speech.stop();
    
    setState(() {
      _isListening = true;
      _lastError = '';
    });

    String locale = _sourceLanguage == 'en' ? 'en_US' : '${_sourceLanguage}_IN';
    print('🎤 Starting to listen with locale: $locale');

    try {
      bool started = await _speech.listen(
        onResult: (result) {
          print('📝 Recognized: "${result.recognizedWords}" (confidence: ${result.confidence})');
          
          if (result.recognizedWords.isNotEmpty) {
            setState(() {
              _sourceTextController.text = result.recognizedWords;
            });
            
            if (result.finalResult) {
              print('✅ Final result received, translating...');
              _translateText();
            }
          }
        },
        localeId: locale,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
        onSoundLevelChange: (level) {
          if (level > 0) {
            print('🔊 Sound level: $level');
          }
        },
      );
      
      if (!started) {
        print('❌ Failed to start listening');
        setState(() {
          _isListening = false;
          _lastError = 'Failed to start speech recognition';
        });
      } else {
        print('✅ Listening started successfully');
      }
    } catch (e) {
      print('❌ Listen error: $e');
      setState(() {
        _isListening = false;
        _lastError = 'Error: $e';
      });
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    
    if (_sourceTextController.text.isNotEmpty) {
      _translateText();
    }
  }

  void _showSpeechNotAvailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Speech Recognition'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Speech recognition is not available.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Solutions:'),
            const SizedBox(height: 4),
            const Text('• Use a real Android device'),
            const Text('• Or use the text input field'),
            if (_lastError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Error: $_lastError',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeSpeech();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _translateText() async {
    if (_sourceTextController.text.isEmpty) return;

    setState(() => _isTranslating = true);

    try {
      print('🌐 Translating: ${_sourceTextController.text}');
      print('🌐 From: $_sourceLanguage To: $_targetLanguage');
      
      final translated = await _translateService.translate(
        _sourceTextController.text,
        _sourceLanguage,
        _targetLanguage,
      );

      setState(() {
        _translatedText = translated;
        _isTranslating = false;
      });

      print('✅ Translated: $translated');

      // Automatically speak translation
      await _speakTranslation(translated, _targetLanguage);
    } catch (e) {
      print('❌ Translation error: $e');
      setState(() => _isTranslating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _speakTranslation(String text, String language) async {
    if (text.isEmpty) return;

    final langCode = _ttsLanguageCodes[language] ?? 'en-US';
    
    print('🔊 Attempting to speak in $langCode: $text');

    try {
      // Check if this specific language is available
      var isLanguageAvailable = await _tts.isLanguageAvailable(langCode);
      print('Language $langCode available: $isLanguageAvailable');

      if (isLanguageAvailable) {
        // Set language and speak
        var result = await _tts.setLanguage(langCode);
        print('Set language result: $result');
        
        if (result == 1) {
          // Language set successfully
          await _tts.setSpeechRate(0.45);
          await _tts.setVolume(1.0);
          await _tts.setPitch(1.0);
          
          var speakResult = await _tts.speak(text);
          print('Speak result: $speakResult');
          
          if (speakResult == 1) {
            print('✅ Speaking in $langCode');
          } else {
            print('❌ Speak failed with result: $speakResult');
            _showTTSNotAvailableMessage(language);
          }
        } else {
          print('❌ Failed to set language');
          _showTTSNotAvailableMessage(language);
        }
      } else {
        print('❌ Language $langCode not available on device');
        _showTTSNotAvailableMessage(language);
      }
    } catch (e) {
      print('❌ TTS error: $e');
      _showTTSNotAvailableMessage(language);
    }
  }

  void _showTTSNotAvailableMessage(String language) {
    if (!mounted) return;
    
    final languageName = _languages[language] ?? language;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.volume_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Voice Not Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$languageName voice is not installed on your device.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('To enable voice output:'),
            const SizedBox(height: 8),
            const Text('1. Open Settings'),
            const Text('2. Go to System → Languages & Input'),
            const Text('3. Select Text-to-speech output'),
            const Text('4. Download language data'),
            const SizedBox(height: 12),
            const Text(
              'The text translation still works!',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;
      
      final tempText = _sourceTextController.text;
      _sourceTextController.text = _translatedText;
      _translatedText = tempText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Translator'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning banners
            if (!_speechAvailable)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Speech Recognition Unavailable',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Use text input or test on a real device',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            if (!_kannadaTTSAvailable && _targetLanguage == 'kn')
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kannada Voice Not Installed',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Text translation works. Install Kannada TTS for audio.',
                              style: TextStyle(fontSize: 11),
                            ),
                            TextButton(
                              onPressed: () => _showTTSNotAvailableMessage('kn'),
                              child: const Text('How to install?'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),

            // Language Selection
            Row(
              children: [
                Expanded(
                  child: _buildLanguageDropdown(
                    'From',
                    _sourceLanguage,
                    (value) => setState(() => _sourceLanguage = value!),
                  ),
                ),
                IconButton(
                  onPressed: _swapLanguages,
                  icon: const Icon(Icons.swap_horiz, size: 32),
                ),
                Expanded(
                  child: _buildLanguageDropdown(
                    'To',
                    _targetLanguage,
                    (value) => setState(() => _targetLanguage = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Source Text Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Text to translate',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_sourceTextController.text.isNotEmpty)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.volume_up),
                                onPressed: () => _speakTranslation(
                                  _sourceTextController.text,
                                  _sourceLanguage,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _sourceTextController.clear();
                                    _translatedText = '';
                                  });
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    TextField(
                      controller: _sourceTextController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type here or use microphone...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      style: const TextStyle(fontSize: 16),
                      onChanged: (text) {
                        if (text.isNotEmpty) {
                          Future.delayed(const Duration(milliseconds: 800), () {
                            if (_sourceTextController.text == text && text.length > 2) {
                              _translateText();
                            }
                          });
                        }
                      },
                    ),
                    
                    if (_isListening)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '🎤 Listening... Speak now!',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _isListening ? _stopListening : _startListening,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _isListening 
                          ? Colors.red 
                          : (_speechAvailable ? Colors.blue : Colors.grey),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? Colors.red : Colors.blue)
                              .withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                
                ElevatedButton.icon(
                  onPressed: _sourceTextController.text.isEmpty 
                      ? null 
                      : _translateText,
                  icon: const Icon(Icons.translate),
                  label: const Text('Translate'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Translation Card
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Translation',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_translatedText.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.volume_up, color: Colors.green),
                            onPressed: () => _speakTranslation(
                              _translatedText,
                              _targetLanguage,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isTranslating)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 100),
                        child: Text(
                          _translatedText.isEmpty 
                              ? 'Translation will appear here...' 
                              : _translatedText,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: _translatedText.isEmpty 
                                ? Colors.grey 
                                : Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'How to use:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('✓ Type text in the input field'),
                    const Text('✓ Or tap microphone and speak'),
                    const Text('✓ Translation happens automatically'),
                    const Text('✓ Tap speaker icon to hear audio'),
                    const SizedBox(height: 8),
                    const Text(
                      '⚠️ If no audio: Install Kannada TTS voice data',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown(
    String label,
    String value,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: _languages.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
