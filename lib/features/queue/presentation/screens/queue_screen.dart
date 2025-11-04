import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/firebase_service.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  final FirebaseService _firebase = FirebaseService.instance;
  List<Map<String, dynamic>> _doctors = [];
  String? _selectedDoctorId;
  bool _isLoading = true;
  
  // Triage questions
  bool _hasSymptoms = false;
  bool _needsUrgentCare = false;
  bool _hasChronicCondition = false;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final doctors = await _firebase.getAllDoctors();
      print('📋 Loaded ${doctors.length} doctors');
      setState(() {
        _doctors = doctors;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading doctors: $e');
      setState(() => _isLoading = false);
    }
  }

  int _calculatePriority() {
    if (_needsUrgentCare) return 1; // High
    if (_hasSymptoms) return 2; // Medium
    return 3; // Low
  }

  Future<void> _joinQueue() async {
    final currentUser = ref.read(authNotifierProvider).value;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    if (_selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doctor')),
      );
      return;
    }

    try {
      final queueId = const Uuid().v4();
      final now = DateTime.now().toIso8601String();
      final priority = _calculatePriority();

      final queueData = {
        'id': queueId,
        'patientId': currentUser.id,
        'patientName': currentUser.fullName,
        'patientPhone': currentUser.phone,
        'assignedDoctorId': _selectedDoctorId,
        'status': 'waiting',
        'checkinTime': now,
        'priority': priority,
        'triageData': {
          'hasSymptoms': _hasSymptoms,
          'needsUrgentCare': _needsUrgentCare,
          'hasChronicCondition': _hasChronicCondition,
        },
      };

      print('📤 Joining queue with data: $queueData');
      await _firebase.addToQueue(queueData);
      print('✅ Successfully added to queue!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Successfully joined queue!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error joining queue: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Queue'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select Doctor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_doctors.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No doctors available'),
                      ),
                    )
                  else
                    ..._doctors.map((doctor) => Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: RadioListTile<String>(
                            title: Text(
                              doctor['fullName'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${doctor['department'] ?? 'General'}\n${doctor['specialization'] ?? 'Doctor'}',
                            ),
                            value: doctor['id'],
                            groupValue: _selectedDoctorId,
                            onChanged: (value) {
                              setState(() => _selectedDoctorId = value);
                            },
                          ),
                        )),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Triage Questions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    child: SwitchListTile(
                      title: const Text('Are you experiencing symptoms?'),
                      value: _hasSymptoms,
                      onChanged: (value) => setState(() => _hasSymptoms = value),
                    ),
                  ),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Do you need urgent care?'),
                      subtitle: const Text('Severe pain, difficulty breathing, etc.'),
                      value: _needsUrgentCare,
                      onChanged: (value) => setState(() => _needsUrgentCare = value),
                    ),
                  ),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Do you have a chronic condition?'),
                      subtitle: const Text('Diabetes, hypertension, etc.'),
                      value: _hasChronicCondition,
                      onChanged: (value) => setState(() => _hasChronicCondition = value),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _joinQueue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text(
                      'Join Queue',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
