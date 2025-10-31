import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class PrescriptionListScreen extends ConsumerStatefulWidget {
  const PrescriptionListScreen({super.key});

  @override
  ConsumerState<PrescriptionListScreen> createState() => _PrescriptionListScreenState();
}

class _PrescriptionListScreenState extends ConsumerState<PrescriptionListScreen> {
  final List<Map<String, dynamic>> _prescriptions = [
    {
      'id': '1',
      'doctorName': 'Dr. Sarah Johnson',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'medicines': ['Amoxicillin 500mg', 'Ibuprofen 400mg'],
      'notes': 'Take with food',
    },
    {
      'id': '2',
      'doctorName': 'Dr. Michael Chen',
      'date': DateTime.now().subtract(const Duration(days: 7)),
      'medicines': ['Lisinopril 10mg', 'Metformin 500mg'],
      'notes': 'Check blood pressure regularly',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _prescriptions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medical_information_outlined,
                    size: 80,
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text('No prescriptions', style: theme.textTheme.titleMedium),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _prescriptions.length,
              itemBuilder: (context, index) {
                final prescription = _prescriptions[index];
                return Card(
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: const Icon(Icons.medical_information, color: Colors.white),
                    ),
                    title: Text(prescription['doctorName']),
                    subtitle: Text(DateFormat('MMM dd, yyyy').format(prescription['date'])),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Medicines:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...(prescription['medicines'] as List<String>).map(
                              (medicine) => Padding(
                                padding: const EdgeInsets.only(left: 16, bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.circle, size: 8),
                                    const SizedBox(width: 8),
                                    Text(medicine),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Notes:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(prescription['notes']),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
