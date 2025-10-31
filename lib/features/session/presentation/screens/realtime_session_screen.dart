import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../translation/data/services/google_translate_service.dart';
import '../../../../core/database/database_helper.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String originalText;
  final String translatedText;
  final String originalLang;
  final String targetLang;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.originalText,
    required this.translatedText,
    required this.originalLang,
    required this.targetLang,
    required this.timestamp,
  });
}

class RealtimeSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final User doctor;
  final String patientId;
  final String patientName;

  const RealtimeSessionScreen({
    super.key,
    required this.sessionId,
    required this.doctor,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<RealtimeSessionScreen> createState() => _RealtimeSessionScreenState();
}

class _RealtimeSessionScreenState extends ConsumerState<RealtimeSessionScreen> {
  final GoogleTranslateService _translateService = GoogleTranslateService();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final DatabaseHelper _db = DatabaseHelper.instance;
  
  List<ChatMessage> _messages = [];
  bool _isListening = false;
  bool _isProcessing = false;
  String _currentSpeaker = 'doctor'; // 'doctor' or 'patient'
  
  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTTS();
    _startListening();
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    await _speech.initialize();
    print('✅ Speech initialized');
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    print('✅ TTS initialized');
  }

  Future<void> _startListening() async {
    if (!_isListening && !_isProcessing) {
      setState(() => _isListening = true);
      
      final sourceLanguage = _currentSpeaker == 'doctor' ? 'en_US' : 'kn_IN';
      
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _handleSpeechResult(result.recognizedWords);
          }
        },
        localeId: sourceLanguage,
        listenMode: stt.ListenMode.confirmation,
      );
    }
  }

  Future<void> _handleSpeechResult(String spokenText) async {
    if (spokenText.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _isListening = false;
    });

    print('🎤 Heard: $spokenText');

    try {
      // Determine languages
      final isDoctor = _currentSpeaker == 'doctor';
      final sourceLang = isDoctor ? 'en' : 'kn';
      final targetLang = isDoctor ? 'kn' : 'en';

      // Translate
      final translatedText = await _translateService.translate(
        spokenText,
        sourceLang,
        targetLang,
      );

      // Create message
      final message = ChatMessage(
        id: const Uuid().v4(),
        senderId: isDoctor ? widget.doctor.id : widget.patientId,
        senderName: isDoctor ? widget.doctor.fullName : widget.patientName,
        senderRole: _currentSpeaker,
        originalText: spokenText,
        translatedText: translatedText,
        originalLang: sourceLang,
        targetLang: targetLang,
        timestamp: DateTime.now(),
      );

      // Save to database
      await _db.saveSessionMessage({
        'id': message.id,
        'sessionId': widget.sessionId,
        'senderId': message.senderId,
        'senderRole': message.senderRole,
        'originalText': message.originalText,
        'translatedText': message.translatedText,
        'sourceLang': message.originalLang,
        'targetLang': message.targetLang,
        'timestamp': message.timestamp.toIso8601String(),
      });

      setState(() {
        _messages.add(message);
      });

      // Speak translation automatically
      await _speakTranslation(translatedText, targetLang);

      // Switch speaker
      setState(() {
        _currentSpeaker = isDoctor ? 'patient' : 'doctor';
      });

      // Restart listening after short delay
      await Future.delayed(const Duration(milliseconds: 500));
      _startListening();
      
    } catch (e) {
      print('❌ Error processing speech: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _speakTranslation(String text, String language) async {
    final langCode = language == 'kn' ? 'kn-IN' : 'en-US';
    await _tts.setLanguage(langCode);
    await _tts.speak(text);
    
    // Wait for speech to complete
    await Future.delayed(Duration(milliseconds: text.length * 50));
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session'),
        content: const Text('Are you sure you want to end this consultation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _speech.stop();
      await _tts.stop();
      
      await _db.updateSession(widget.sessionId, {
        'status': 'completed',
        'endTime': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        // Show post-session options
        _showPostSessionOptions();
      }
    }
  }

  void _showPostSessionOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PostSessionSheet(
        sessionId: widget.sessionId,
        doctor: widget.doctor,
        patientId: widget.patientId,
        patientName: widget.patientName,
      ),
    );
  }

  Future<void> _triggerEmergency() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red, size: 32),
            const SizedBox(width: 12),
            const Text('EMERGENCY SOS'),
          ],
        ),
        content: const Text(
          'This will trigger an emergency alert. Are you sure?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SEND SOS'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.createEmergencyAlert({
        'id': const Uuid().v4(),
        'patientId': widget.patientId,
        'adminId': null,
        'alertType': 'MEDICAL_EMERGENCY',
        'location': 'Consultation Room',
        'status': 'active',
        'createdAt': DateTime.now().toIso8601String(),
        'resolvedAt': null,
      });

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Session'),
            Text(
              widget.patientName,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          // Emergency SOS Button
          IconButton(
            onPressed: _triggerEmergency,
            icon: const Icon(Icons.emergency, color: Colors.red),
            tooltip: 'Emergency SOS',
          ),
          // End Session Button
          IconButton(
            onPressed: _endSession,
            icon: const Icon(Icons.stop_circle),
            tooltip: 'End Session',
          ),
        ],
      ),
      body: Column(
        children: [
          // Current Speaker Indicator
          Container(
            padding: const EdgeInsets.all(12),
            color: _currentSpeaker == 'doctor' 
                ? Colors.blue.shade100 
                : Colors.green.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _currentSpeaker == 'doctor' 
                      ? Icons.medical_services 
                      : Icons.person,
                  color: _currentSpeaker == 'doctor' 
                      ? Colors.blue 
                      : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _isListening 
                      ? '🎤 Listening to ${_currentSpeaker == 'doctor' ? 'Doctor' : 'Patient'}...'
                      : _isProcessing
                          ? '⚙️ Processing...'
                          : 'Ready',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Chat Messages
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Start speaking to begin translation',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      final isDoctor = message.senderRole == 'doctor';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: isDoctor 
                              ? CrossAxisAlignment.end 
                              : CrossAxisAlignment.start,
                          children: [
                            // Sender name
                            Text(
                              message.senderName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDoctor ? Colors.blue : Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            
                            // Original text bubble
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDoctor 
                                    ? Colors.blue.shade100 
                                    : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.originalText,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  const Text(
                                    'Translation:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message.translatedText,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Timestamp
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Status indicator
          if (_isListening || _isProcessing)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isListening)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 12),
                  Text(
                    _isListening 
                        ? 'Listening...' 
                        : 'Processing translation...',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Post-Session Sheet
class PostSessionSheet extends StatefulWidget {
  final String sessionId;
  final User doctor;
  final String patientId;
  final String patientName;

  const PostSessionSheet({
    super.key,
    required this.sessionId,
    required this.doctor,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PostSessionSheet> createState() => _PostSessionSheetState();
}

class _PostSessionSheetState extends State<PostSessionSheet> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final _prescriptionController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedTransport = 'none';

  @override
  void dispose() {
    _prescriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitAndClose() async {
    // Save prescription if provided
    if (_prescriptionController.text.isNotEmpty) {
      await _db.savePrescription({
        'id': const Uuid().v4(),
        'patientId': widget.patientId,
        'doctorId': widget.doctor.id,
        'sessionId': widget.sessionId,
        'medicines': _prescriptionController.text,
        'instructions': _notesController.text,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    // Create transport request if needed
    if (_selectedTransport != 'none') {
      await _db.createTransportRequest({
        'id': const Uuid().v4(),
        'patientId': widget.patientId,
        'doctorId': widget.doctor.id,
        'fromLocation': 'Consultation Room',
        'toLocation': 'Exit/Ward',
        'transportType': _selectedTransport,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    if (mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).pop(); // Close session screen too
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Session Completed',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          // Prescription
          TextField(
            controller: _prescriptionController,
            decoration: const InputDecoration(
              labelText: 'Prescription/Medicines',
              border: OutlineInputBorder(),
              hintText: 'Enter medicines and dosage',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Notes
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Instructions/Notes',
              border: OutlineInputBorder(),
              hintText: 'Additional instructions for patient',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Transport assistance
          const Text(
            'Transport Assistance Needed:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('None'),
                selected: _selectedTransport == 'none',
                onSelected: (selected) {
                  setState(() => _selectedTransport = 'none');
                },
              ),
              ChoiceChip(
                label: const Text('Wheelchair'),
                selected: _selectedTransport == 'wheelchair',
                onSelected: (selected) {
                  setState(() => _selectedTransport = 'wheelchair');
                },
              ),
              ChoiceChip(
                label: const Text('Walker'),
                selected: _selectedTransport == 'walker',
                onSelected: (selected) {
                  setState(() => _selectedTransport = 'walker');
                },
              ),
              ChoiceChip(
                label: const Text('Stretcher'),
                selected: _selectedTransport == 'stretcher',
                onSelected: (selected) {
                  setState(() => _selectedTransport = 'stretcher');
                },
              ),
              ChoiceChip(
                label: const Text('Walking Aid'),
                selected: _selectedTransport == 'walking aid',
                onSelected: (selected) {
                  setState(() => _selectedTransport = 'walking aid');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _submitAndClose,
            child: const Text('Complete & Close Session'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
