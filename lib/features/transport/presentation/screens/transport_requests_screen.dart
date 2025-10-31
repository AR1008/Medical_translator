import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';

class TransportRequestsScreen extends ConsumerStatefulWidget {
  const TransportRequestsScreen({super.key});

  @override
  ConsumerState<TransportRequestsScreen> createState() => _TransportRequestsScreenState();
}

class _TransportRequestsScreenState extends ConsumerState<TransportRequestsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final requests = await _db.getTransportRequests();
    setState(() {
      _requests = requests;
      _isLoading = false;
    });
  }

  IconData _getTransportIcon(String type) {
    switch (type.toLowerCase()) {
      case 'wheelchair':
        return Icons.accessible;
      case 'stretcher':
        return Icons.airline_seat_flat;
      case 'walking aid':
        return Icons.accessibility_new;
      default:
        return Icons.directions_walk;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_hospital, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No pending transport requests'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(
                            _getTransportIcon(request['transportType']),
                            color: Colors.blue,
                          ),
                        ),
                        title: Text(
                          request['patientName'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Doctor: ${request['doctorName']}'),
                            Text('From: ${request['fromLocation']}'),
                            Text('To: ${request['toLocation']}'),
                            Text('Transport: ${request['transportType']}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle),
                          color: Colors.green,
                          onPressed: () async {
                            await _db.updateTransportStatus(request['id'], 'completed');
                            _loadRequests();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Transport completed')),
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
