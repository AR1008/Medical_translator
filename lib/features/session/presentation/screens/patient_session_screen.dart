import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import '../../../../core/services/firebase_service.dart';

class PatientSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String patientId;
  final String patientName;
  final String doctorName;

  const PatientSessionScreen({
    super.key,
    required this.sessionId,
    required this.patientId,
    required this.patientName,
    required this.doctorName,
  });

  @override
  ConsumerState<PatientSessionScreen> createState() => _PatientSessionScreenState();
}

class _PatientSessionScreenState extends ConsumerState<PatientSessionScreen> {
  final GoogleTranslator _translator = GoogleTranslator();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FirebaseService _firebase = FirebaseService.instance;
  final TextEditingController _textController = TextEditingController();
  
  bool _isListening = false;
  bool _isSending = false;
  
  @override
  void initState() {
    super.initState();
    _speech.initialize();
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) => _textController.text = result.recognizedWords,
        localeId: 'kn_IN',
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      print('🔄 Translating: $text');
      
      final translation = await _translator.translate(text, from: 'kn', to: 'en');
      final translatedText = translation.text;
      
      print('✅ Translated: $translatedText');

      final message = {
        'senderId': widget.patientId,
        'senderName': widget.patientName,
        'senderRole': 'patient',
        'originalText': text,
        'translatedText': translatedText,
        'originalLang': 'kn',
        'targetLang': 'en',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _firebase.sendMessage(widget.sessionId, message);
      print('✅ Message sent successfully');
      
    } catch (e) {
      print('❌ Error: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _speakText(String text, String language) async {
    await _tts.setLanguage(language == 'kn' ? 'kn-IN' : 'en-US');
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dr. ${widget.doctorName}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firebase.watchSessionMessages(widget.sessionId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];
                print('📊 Patient: Loaded ${messages.length} messages');

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Waiting for doctor...', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isDoctor = msg['senderRole'] == 'doctor';
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Align(
                        alignment: isDoctor ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDoctor ? Colors.blue.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['senderName'] ?? '',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                              ),
                              const SizedBox(height: 8),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      msg['originalText'] ?? '',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.volume_up, size: 20, color: Colors.blue),
                                    onPressed: () => _speakText(msg['originalText'] ?? '', msg['originalLang'] ?? 'en'),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              
                              const Divider(height: 16, thickness: 1),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      msg['translatedText'] ?? '',
                                      style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black87),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.volume_up, size: 20, color: Colors.green),
                                    onPressed: () => _speakText(msg['translatedText'] ?? '', msg['targetLang'] ?? 'kn'),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isListening ? Icons.stop : Icons.mic, color: _isListening ? Colors.red : Colors.green),
                  onPressed: _toggleListening,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Type message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.send, color: Colors.green, size: 28),
                        onPressed: _sendMessage,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
