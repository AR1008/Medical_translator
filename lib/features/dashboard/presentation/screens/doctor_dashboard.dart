import 'package:flutter/material.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../session/presentation/screens/realtime_session_screen.dart';
import '../../../prescription/presentation/screens/prescription_list_screen.dart';

class DoctorDashboard extends StatefulWidget {
  final User doctor;

  const DoctorDashboard({super.key, required this.doctor});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final FirebaseService _firebase = FirebaseService.instance;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dr. ${widget.doctor.fullName}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _selectedIndex == 0 ? _buildDashboard() : _buildQueue(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Queue',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue,
                    child: Text(
                      widget.doctor.fullName[0],
                      style: const TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, Dr. ${widget.doctor.fullName}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.doctor.specialization ?? 'Doctor',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionCard(
                icon: Icons.people,
                title: 'Patient Queue',
                color: Colors.blue,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _buildActionCard(
                icon: Icons.medication,
                title: 'Prescriptions',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrescriptionListScreen(),
                    ),
                  );
                },
              ),
              _buildActionCard(
                icon: Icons.history,
                title: 'Session History',
                color: Colors.orange,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  );
                },
              ),
              _buildActionCard(
                icon: Icons.settings,
                title: 'Settings',
                color: Colors.grey,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueue() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: const Row(
            children: [
              Icon(Icons.people, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Patient Queue',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firebase.watchDoctorQueue(widget.doctor.id),
            builder: (context, snapshot) {
              print('�� Queue stream state: ${snapshot.connectionState}');
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                print('❌ Queue stream error: ${snapshot.error}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final queue = snapshot.data ?? [];
              print('📊 Queue loaded: ${queue.length} patients');

              if (queue.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No patients in queue',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  final patient = queue[index];
                  final priority = patient['priority'] as int;
                  final triageData = patient['triageData'] as Map<String, dynamic>?;

                  Color priorityColor = Colors.green;
                  String priorityText = 'Low';
                  if (priority == 1) {
                    priorityColor = Colors.red;
                    priorityText = 'High';
                  } else if (priority == 2) {
                    priorityColor = Colors.orange;
                    priorityText = 'Medium';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: priorityColor,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        patient['patientName'] ?? 'Unknown Patient',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Phone: ${patient['patientPhone'] ?? 'N/A'}'),
                          Text('Priority: $priorityText', style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold)),
                          if (triageData?['needsUrgentCare'] == true)
                            const Text(
                              '⚠️ Needs urgent care',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _startSession(patient),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _startSession(Map<String, dynamic> queueEntry) async {
    try {
      print('🚀 Starting session for patient: ${queueEntry['patientName']}');
      
      // Remove from queue first
      await _firebase.removeFromQueue(queueEntry['id']);

      // Create session
      final sessionId = await _firebase.createSession({
        'patientId': queueEntry['patientId'],
        'doctorId': widget.doctor.id,
        'status': 'active',
        'startTime': DateTime.now().toIso8601String(),
        'triageData': queueEntry['triageData'],
      });

      print('✅ Session created: $sessionId');

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RealtimeSessionScreen(
              sessionId: sessionId,
              doctor: widget.doctor,
              patientId: queueEntry['patientId'],
              patientName: queueEntry['patientName'] ?? 'Patient',
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error starting session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
