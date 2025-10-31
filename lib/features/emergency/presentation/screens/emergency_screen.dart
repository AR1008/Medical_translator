import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../auth/data/models/user_model.dart';

class EmergencyScreen extends ConsumerStatefulWidget {
  final User admin;

  const EmergencyScreen({super.key, required this.admin});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
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

  Future<void> _createAlert(String alertType, String patientId, String location) async {
    final alert = {
      'id': const Uuid().v4(),
      'patientId': patientId,
      'adminId': widget.admin.id,
      'alertType': alertType,
      'location': location,
      'status': 'active',
      'createdAt': DateTime.now().toIso8601String(),
    };

    await _db.createEmergencyAlert(alert);
    _loadAlerts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$alertType alert created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _resolveAlert(String id) async {
    await _db.resolveAlert(id);
    _loadAlerts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert resolved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showCreateAlertDialog() {
    String selectedType = 'Medical Emergency';
    final locationController = TextEditingController();
    final patientIdController = TextEditingController(text: 'patient1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Emergency Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(labelText: 'Alert Type'),
              items: [
                'Medical Emergency',
                'Nearest Doctor',
                'Transport Required',
                'Nurse Alert',
                'Security Alert',
              ].map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                selectedType = value!;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: patientIdController,
              decoration: const InputDecoration(
                labelText: 'Patient ID',
                hintText: 'Enter patient ID',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'Ward/Room number',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _createAlert(
                selectedType,
                patientIdController.text,
                locationController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Create Alert'),
          ),
        ],
      ),
    );
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'Medical Emergency':
        return Colors.red;
      case 'Nearest Doctor':
        return Colors.orange;
      case 'Transport Required':
        return Colors.blue;
      case 'Nurse Alert':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'Medical Emergency':
        return Icons.emergency;
      case 'Nearest Doctor':
        return Icons.person_search;
      case 'Transport Required':
        return Icons.local_hospital;
      case 'Nurse Alert':
        return Icons.notifications_active;
      default:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 80,
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No active alerts',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All clear! Create alerts when needed.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _alerts.length,
                  itemBuilder: (context, index) {
                    final alert = _alerts[index];
                    final alertColor = _getAlertColor(alert['alertType']);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: alertColor.withValues(alpha: 0.2),
                          child: Icon(
                            _getAlertIcon(alert['alertType']),
                            color: alertColor,
                          ),
                        ),
                        title: Text(
                          alert['alertType'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Patient: ${alert['patientName']}'),
                            if (alert['location'] != null)
                              Text('Location: ${alert['location']}'),
                            Text('Phone: ${alert['patientPhone']}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          color: Colors.green,
                          onPressed: () => _resolveAlert(alert['id']),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAlertDialog,
        icon: const Icon(Icons.add_alert),
        label: const Text('New Alert'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
