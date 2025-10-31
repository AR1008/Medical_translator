import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/database/database_helper.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _doctors = [];
  String? _selectedDoctorId;
  
  // Triage questions
  bool _hasChestPain = false;
  bool _hasDifficultyBreathing = false;
  bool _hasSevereHeadache = false;
  bool _hasHighFever = false;
  bool _hasBloodInStool = false;
  bool _hasSevereAbdominalPain = false;
  int _painLevel = 0;
  
  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    final db = await _db.database;
    final doctors = await db.query(
      'users',
      where: 'userType = ? AND isActive = 1',
      whereArgs: ['doctor'],
    );
    setState(() => _doctors = doctors);
  }

  int _calculatePriority() {
    // Critical symptoms - Priority 1
    if (_hasChestPain || _hasDifficultyBreathing || _hasBloodInStool) {
      return 1; // CRITICAL
    }
    
    // Urgent symptoms - Priority 2
    if (_hasSevereHeadache || _hasSevereAbdominalPain || _painLevel >= 8) {
      return 2; // URGENT
    }
    
    // Moderate symptoms - Priority 3
    if (_hasHighFever || _painLevel >= 5) {
      return 3; // MODERATE
    }
    
    // Low priority - Priority 4
    if (_painLevel >= 3) {
      return 4; // LOW
    }
    
    // Routine - Priority 5
    return 5; // ROUTINE
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 1: return 'CRITICAL';
      case 2: return 'URGENT';
      case 3: return 'MODERATE';
      case 4: return 'LOW';
      default: return 'ROUTINE';
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return Colors.yellow.shade700;
      case 4: return Colors.blue;
      default: return Colors.green;
    }
  }

  Future<void> _joinQueue() async {
    final authState = ref.read(authNotifierProvider);
    
    final user = authState.value;
    if (user == null) {
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

    final priority = _calculatePriority();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Queue Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${user.fullName}'),
            const SizedBox(height: 8),
            Text('Doctor: ${_doctors.firstWhere((d) => d['id'] == _selectedDoctorId)['fullName']}'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Priority: '),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(priority),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getPriorityText(priority),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Join Queue'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.addToQueue({
        'id': const Uuid().v4(),
        'patientId': user.id,
        'priority': priority,
        'department': 'General',
        'status': 'waiting',
        'assignedDoctorId': _selectedDoctorId,
        'checkinTime': DateTime.now().toIso8601String(),
        'notes': _buildTriageNotes(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to queue with ${_getPriorityText(priority)} priority'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  String _buildTriageNotes() {
    final notes = <String>[];
    if (_hasChestPain) notes.add('Chest pain');
    if (_hasDifficultyBreathing) notes.add('Difficulty breathing');
    if (_hasSevereHeadache) notes.add('Severe headache');
    if (_hasHighFever) notes.add('High fever');
    if (_hasBloodInStool) notes.add('Blood in stool');
    if (_hasSevereAbdominalPain) notes.add('Severe abdominal pain');
    notes.add('Pain level: $_painLevel/10');
    return notes.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Queue'),
      ),
      body: user == null
          ? const Center(child: Text('Please login first'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Info (Auto-filled)
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Patient Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Name: ${user.fullName}'),
                          if (user.phone != null) Text('Phone: ${user.phone}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Doctor Selection
                  const Text(
                    'Select Doctor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_doctors.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    ...List.generate(_doctors.length, (index) {
                      final doctor = _doctors[index];
                      final isSelected = _selectedDoctorId == doctor['id'];
                      return Card(
                        color: isSelected ? Colors.blue.shade100 : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(Icons.medical_services, color: Colors.blue),
                          ),
                          title: Text('Dr. ${doctor['fullName']}'),
                          subtitle: Text(doctor['specialization'] ?? 'General Physician'),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Colors.blue)
                              : null,
                          onTap: () {
                            setState(() => _selectedDoctorId = doctor['id']);
                          },
                        ),
                      );
                    }),
                  const SizedBox(height: 24),

                  // Triage Questions
                  const Text(
                    'Triage Assessment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please answer these questions to help us prioritize your care:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  _buildTriageQuestion(
                    'Do you have chest pain?',
                    _hasChestPain,
                    (value) => setState(() => _hasChestPain = value),
                  ),
                  _buildTriageQuestion(
                    'Are you having difficulty breathing?',
                    _hasDifficultyBreathing,
                    (value) => setState(() => _hasDifficultyBreathing = value),
                  ),
                  _buildTriageQuestion(
                    'Do you have severe headache?',
                    _hasSevereHeadache,
                    (value) => setState(() => _hasSevereHeadache = value),
                  ),
                  _buildTriageQuestion(
                    'Do you have high fever (>103°F)?',
                    _hasHighFever,
                    (value) => setState(() => _hasHighFever = value),
                  ),
                  _buildTriageQuestion(
                    'Is there blood in your stool?',
                    _hasBloodInStool,
                    (value) => setState(() => _hasBloodInStool = value),
                  ),
                  _buildTriageQuestion(
                    'Do you have severe abdominal pain?',
                    _hasSevereAbdominalPain,
                    (value) => setState(() => _hasSevereAbdominalPain = value),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Pain Level (0 = No pain, 10 = Worst pain)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _painLevel.toDouble(),
                          min: 0,
                          max: 10,
                          divisions: 10,
                          label: _painLevel.toString(),
                          onChanged: (value) {
                            setState(() => _painLevel = value.toInt());
                          },
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _painLevel >= 7 ? Colors.red : _painLevel >= 4 ? Colors.orange : Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _painLevel.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Priority Preview
                  Card(
                    color: _getPriorityColor(_calculatePriority()).withOpacity(0.2),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.priority_high,
                            color: _getPriorityColor(_calculatePriority()),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Priority Level:',
                                style: TextStyle(fontSize: 12),
                              ),
                              Text(
                                _getPriorityText(_calculatePriority()),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _getPriorityColor(_calculatePriority()),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Join Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _joinQueue,
                      child: const Text(
                        'Join Queue',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTriageQuestion(String question, bool value, Function(bool) onChanged) {
    return Card(
      child: SwitchListTile(
        title: Text(question),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.red,
      ),
    );
  }
}
