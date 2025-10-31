import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';

class EmergencyAlertsScreen extends ConsumerStatefulWidget {
  const EmergencyAlertsScreen({super.key});

  @override
  ConsumerState<EmergencyAlertsScreen> createState() => _EmergencyAlertsScreenState();
}

class _EmergencyAlertsScreenState extends ConsumerState<EmergencyAlertsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    final alerts = await _db.getEmergencyAlerts();
    setState(() {
      _alerts = alerts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alerts'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No active emergency alerts'),
                      Text('All clear!', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _alerts.length,
                  itemBuilder: (context, index) {
                    final alert = _alerts[index];
                    return Card(
                      color: Colors.red.shade50,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.emergency, color: Colors.white),
                        ),
                        title: Text(
                          '🚨 ${alert['alertType']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Patient: ${alert['patientName']}'),
                            if (alert['location'] != null)
                              Text('Location: ${alert['location']}'),
                            Text('Phone: ${alert['patientPhone']}'),
                            Text(
                              'Time: ${DateTime.parse(alert['createdAt']).toLocal()}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle),
                          color: Colors.green,
                          onPressed: () async {
                            await _db.resolveAlert(alert['id']);
                            _loadAlerts();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Alert resolved'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}
