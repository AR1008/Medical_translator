import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';
import '../../../../core/database/database_helper.dart';
import '../../data/services/translation_service.dart';
import 'package:uuid/uuid.dart';

class SessionTranslationScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String doctorId;
  final String doctorName;
  final String patientId;
  final String patientName;
  final bool isDoctor;

  const SessionTranslationScreen({
    super.key,
    required this.sessionId,
    required this.doctorId,
    required this.doctorName,
    required this.patientId,
    required this.patientName,
    required this.isDoctor,
  });

  @override
  ConsumerState<SessionTranslationScreen> createState() =>
      _SessionTranslationScreenState();
}

class _SessionTranslationScreenState
    extends ConsumerState<SessionTranslationScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final TranslationService _translationService = TranslationService();
  final SpeechToText _speechToText = SpeechToText();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isListening = false;
  bool _speechEnabled = false;
  String _currentText = '';
  Timer? _pollingTimer;
  Timer? _autoSpeakTimer;
  
  // Doctor speaks English, Patient speaks Kannada
  final String _doctorLang = 'en';
  final String _patientLang = 'kn';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _autoSpeakTimer?.cancel();
    _translationService.stop();
    super.dispose();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _loadMessages();
    });
  }

  Future<void> _loadMessages() async {
    final messages = await _db.getSessionMessages(widget.sessionId);
    if (mounted && messages.length != _messages.length) {
      setState(() {
        _messages = messages;
      });
      
      // Auto-play the latest message if it's from the other person
      if (_messages.isNotEmpty) {
        final lastMessage = _messages.last;
        final isFromOtherPerson = widget.isDoctor
            ? lastMessage['senderId'] == widget.patientId
            : lastMessage['senderId'] == widget.doctorId;
        
        if (isFromOtherPerson) {
          _autoSpeakTimer?.cancel();
          _autoSpeakTimer = Timer(const Duration(milliseconds: 500), () {
            _speakMessage(lastMessage);
          });
        }
      }
    }
  }

  void _speakMessage(Map<String, dynamic> message) async {
    final textToSpeak = widget.isDoctor
        ? message['originalText'] // Doctor hears in English
        : message['translatedText']; // Patient hears in Kannada
    
    final lang = widget.isDoctor ? _doctorLang : _patientLang;
    
    await _translationService.speak(textToSpeak, lang);
  }

  void _startListening() async {
    if (!_speechEnabled) return;

    setState(() {
      _isListening = true;
      _currentText = '';
    });

    final locale = widget.isDoctor ? 'en_US' : 'kn_IN';
    
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _currentText = result.recognizedWords;
        });
        
        if (result.finalResult) {
          _sendMessage(_currentText);
        }
      },
      localeId: locale,
      listenMode: ListenMode.confirmation,
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final fromLang = widget.isDoctor ? _doctorLang : _patientLang;
    final toLang = widget.isDoctor ? _patientLang : _doctorLang;

    // Translate
    final translatedText = await _translationService.translate(text, fromLang, toLang);

    // Save to database
    final message = {
      'id': const Uuid().v4(),
      'sessionId': widget.sessionId,
      'senderId': widget.isDoctor ? widget.doctorId : widget.patientId,
      'senderRole': widget.isDoctor ? 'doctor' : 'patient',
      'originalText': text,
      'translatedText': translatedText,
      'sourceLang': fromLang,
      'targetLang': toLang,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _db.saveSessionMessage(message);
    
    // Speak the translation immediately for the speaker
    await _translationService.speak(translatedText, toLang);
    
    setState(() {
      _currentText = '';
    });
    
    _loadMessages();
  }

  void _endSession() async {
    await _db.updateSession(widget.sessionId, {
      'status': 'completed',
      'endTime': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _triggerSOS() async {
    // Create emergency alert
    final alert = {
      'id': const Uuid().v4(),
      'patientId': widget.patientId,
      'adminId': null,
      'alertType': 'Medical Emergency',
      'location': 'Consultation Room',
      'status': 'active',
      'createdAt': DateTime.now().toIso8601String(),
    };

    await _db.createEmergencyAlert(alert);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 EMERGENCY ALERT SENT!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _requestTransport() {
    showModalBottomSheet(
      context: context,
      builder: (context) => TransportRequestSheet(
        sessionId: widget.sessionId,
        doctorId: widget.doctorId,
        patientId: widget.patientId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDoctor
            ? 'Session with ${widget.patientName}'
            : 'Session with Dr. ${widget.doctorName}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (widget.isDoctor) ...[
            IconButton(
              icon: const Icon(Icons.local_hospital),
              onPressed: _requestTransport,
              tooltip: 'Transport Request',
            ),
            IconButton(
              icon: const Icon(Icons.emergency),
              onPressed: _triggerSOS,
              tooltip: 'Emergency SOS',
            ),
            IconButton(
              icon: const Icon(Icons.stop_circle),
              onPressed: _endSession,
              tooltip: 'End Session',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isFromMe = widget.isDoctor
                    ? message['senderId'] == widget.doctorId
                    : message['senderId'] == widget.patientId;

                return _buildMessageBubble(message, isFromMe);
              },
            ),
          ),

          // Current listening text
          if (_currentText.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Speaking...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_currentText),
                ],
              ),
            ),

          // Control buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isListening ? _stopListening : _startListening,
                  icon: Icon(_isListening ? Icons.stop : Icons.mic),
                  label: Text(_isListening ? 'Stop' : 'Speak'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isFromMe) {
    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isFromMe ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original text
            Text(
              message['originalText'],
              style: TextStyle(
                color: isFromMe ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white54),
            const SizedBox(height: 4),
            // Translated text
            Text(
              'Translation:',
              style: TextStyle(
                color: isFromMe ? Colors.white70 : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message['translatedText'],
              style: TextStyle(
                color: isFromMe ? Colors.white : Colors.black,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message['timestamp']),
              style: TextStyle(
                color: isFromMe ? Colors.white70 : Colors.black54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    final dt = DateTime.parse(timestamp);
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class TransportRequestSheet extends StatefulWidget {
  final String sessionId;
  final String doctorId;
  final String patientId;

  const TransportRequestSheet({
    super.key,
    required this.sessionId,
    required this.doctorId,
    required this.patientId,
  });

  @override
  State<TransportRequestSheet> createState() => _TransportRequestSheetState();
}

class _TransportRequestSheetState extends State<TransportRequestSheet> {
  String _selectedType = 'Wheelchair';
  final List<String> _transportTypes = [
    'Wheelchair',
    'Walker',
    'Stretcher',
    'Bed',
    'Ward Assistant',
    'None',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Transport Request',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(_transportTypes.length, (index) {
            final type = _transportTypes[index];
            return RadioListTile<String>(
              title: Text(type),
              value: type,
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            );
          }),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    if (_selectedType != 'None') {
                      await DatabaseHelper.instance.createTransportRequest({
                        'id': const Uuid().v4(),
                        'patientId': widget.patientId,
                        'doctorId': widget.doctorId,
                        'fromLocation': 'Consultation Room',
                        'toLocation': 'Exit',
                        'transportType': _selectedType,
                        'status': 'pending',
                        'createdAt': DateTime.now().toIso8601String(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Transport request sent: $_selectedType'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
