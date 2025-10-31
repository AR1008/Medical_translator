import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../auth/data/models/user_model.dart';

class PatientDrawingsScreen extends ConsumerStatefulWidget {
  final User patient;

  const PatientDrawingsScreen({super.key, required this.patient});

  @override
  ConsumerState<PatientDrawingsScreen> createState() => _PatientDrawingsScreenState();
}

class _PatientDrawingsScreenState extends ConsumerState<PatientDrawingsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _drawings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrawings();
  }

  Future<void> _loadDrawings() async {
    setState(() => _isLoading = true);
    final drawings = await _db.getPatientDrawings(widget.patient.id);
    setState(() {
      _drawings = drawings;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medical Drawings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drawings.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.draw_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No drawings yet'),
                      SizedBox(height: 8),
                      Text(
                        'Your doctor will add medical illustrations here',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _drawings.length,
                  itemBuilder: (context, index) {
                    final drawing = _drawings[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DrawingDetailScreen(
                                drawing: drawing,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Image.file(
                                File(drawing['imagePath']),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stack) {
                                  return const Center(
                                    child: Icon(Icons.broken_image, size: 50),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dr. ${drawing['doctorName']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    drawing['diagramType'] ?? 'Medical Drawing',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class DrawingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> drawing;

  const DrawingDetailScreen({super.key, required this.drawing});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.file(
              File(drawing['imagePath']),
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Icon(Icons.broken_image, size: 100),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Created by: Dr. ${drawing['doctorName']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Type: ${drawing['diagramType'] ?? 'Medical Drawing'}'),
                  if (drawing['notes'] != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Notes:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(drawing['notes']),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
