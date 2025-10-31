import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../drawing/presentation/screens/drawing_screen.dart';
import '../../../prescription/presentation/screens/prescription_list_screen.dart';
import '../../../emergency/presentation/screens/emergency_alerts_screen.dart';
import '../../../session/presentation/screens/realtime_session_screen.dart';
import '../../../../core/database/database_helper.dart';
import 'package:uuid/uuid.dart';

class DoctorDashboard extends ConsumerStatefulWidget {
  final User doctor;

  const DoctorDashboard({super.key, required this.doctor});

  @override
  ConsumerState<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends ConsumerState<DoctorDashboard> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _queue = [];
  Map<String, dynamic>? _activeSession;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final queue = await _db.getDoctorQueue(widget.doctor.id);
    final session = await _db.getActiveSession(widget.doctor.id);
    setState(() {
      _queue = queue;
      _activeSession = session;
      _isLoading = false;
    });
  }

  Future<void> _startNextSession() async {
    if (_queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No patients in queue')),
      );
      return;
    }

    final nextPatient = _queue.first;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Session'),
        content: Text(
          'Start consultation with ${nextPatient['patientName']}?\n\n'
          'Priority: ${_getPriorityText(nextPatient['priority'])}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final sessionId = const Uuid().v4();
      
      // Create session
      await _db.createSession({
        'id': sessionId,
        'patientId': nextPatient['patientId'],
        'doctorId': widget.doctor.id,
        'status': 'active',
        'startTime': DateTime.now().toIso8601String(),
        'notes': '',
      });

      // Remove from queue
      await _db.removeFromQueue(nextPatient['patientId'], widget.doctor.id);

      _loadData();

      if (mounted) {
        // Open real-time session
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RealtimeSessionScreen(
              sessionId: sessionId,
              doctor: widget.doctor,
              patientId: nextPatient['patientId'],
              patientName: nextPatient['patientName'],
            ),
          ),
        ).then((_) => _loadData());
      }
    }
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 1:
        return 'CRITICAL';
      case 2:
        return 'URGENT';
      case 3:
        return 'MODERATE';
      case 4:
        return 'LOW';
      default:
        return 'ROUTINE';
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      default:
        return Colors.green;
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Doctor Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: const Icon(Icons.medical_services, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dr. ${widget.doctor.fullName}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.doctor.specialization != null)
                                Text(
                                  widget.doctor.specialization!,
                                  style: theme.textTheme.bodyMedium,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Active Session or Start Button
                    if (_activeSession != null)
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'ACTIVE SESSION',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Patient: ${_activeSession!['patientName']}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RealtimeSessionScreen(
                                        sessionId: _activeSession!['id'],
                                        doctor: widget.doctor,
                                        patientId: _activeSession!['patientId'],
                                        patientName: _activeSession!['patientName'],
                                      ),
                                    ),
                                  ).then((_) => _loadData());
                                },
                                icon: const Icon(Icons.chat),
                                label: const Text('Resume Session'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                'No Active Session',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _queue.isEmpty ? null : _startNextSession,
                                icon: const Icon(Icons.play_arrow),
                                label: Text(_queue.isEmpty 
                                    ? 'No Patients in Queue' 
                                    : 'Start Next Session'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Patient Queue
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Patient Queue',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_queue.length} waiting',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (_queue.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No patients in queue'),
                          ),
                        ),
                      )
                    else
                      ...List.generate(_queue.length, (index) {
                        final patient = _queue[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getPriorityColor(patient['priority']).withOpacity(0.2),
                              child: Text(
                                '#${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getPriorityColor(patient['priority']),
                                ),
                              ),
                            ),
                            title: Text(patient['patientName']),
                            subtitle: Text(_getPriorityText(patient['priority'])),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(patient['priority']),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getPriorityText(patient['priority']),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 24),

                    // Tools Section
                    Text(
                      'Tools',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildToolCard(
                      icon: Icons.draw,
                      title: 'Create Drawing',
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DrawingScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    
                    _buildToolCard(
                      icon: Icons.medication,
                      title: 'Manage Prescriptions',
                      color: Colors.red,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrescriptionListScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    
                    _buildToolCard(
                      icon: Icons.emergency,
                      title: 'Emergency Alerts',
                      color: Colors.red.shade700,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EmergencyAlertsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
