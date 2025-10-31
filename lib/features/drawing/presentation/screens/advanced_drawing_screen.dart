import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../../core/database/database_helper.dart';

class DrawingPoint {
  Offset offset;
  Paint paint;

  DrawingPoint(this.offset, this.paint);
}

class AdvancedDrawingScreen extends ConsumerStatefulWidget {
  final User doctor;

  const AdvancedDrawingScreen({super.key, required this.doctor});

  @override
  ConsumerState<AdvancedDrawingScreen> createState() => _AdvancedDrawingScreenState();
}

class _AdvancedDrawingScreenState extends ConsumerState<AdvancedDrawingScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final GlobalKey _canvasKey = GlobalKey();
  
  List<DrawingPoint> _points = [];
  Color _selectedColor = Colors.red;
  double _strokeWidth = 3.0;
  String? _patientId;
  String? _patientName;
  final _notesController = TextEditingController();
  File? _backgroundImage;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectPatient() async {
    final patients = await _db.getAllPatients();
    
    if (!mounted) return;
    
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Patient'),
        content: SizedBox(
          width: double.maxFinite,
          child: patients.isEmpty
              ? const Center(child: Text('No patients found'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(patient['fullName']),
                      subtitle: Text(patient['phone'] ?? ''),
                      onTap: () => Navigator.pop(context, patient),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null) {
      setState(() {
        _patientId = selected['id'];
        _patientName = selected['fullName'];
      });
    }
  }

  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _backgroundImage = File(image.path);
      });
    }
  }

  void _clearCanvas() {
    setState(() {
      _points.clear();
    });
  }

  void _undo() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
      });
    }
  }

  Future<void> _saveDrawing() async {
    if (_patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient first')),
      );
      return;
    }

    try {
      // Capture the drawing as image
      final boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/${const Uuid().v4()}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      // Save to database
      await _db.saveDrawing({
        'id': const Uuid().v4(),
        'patientId': _patientId,
        'doctorId': widget.doctor.id,
        'sessionId': null,
        'imagePath': imagePath,
        'diagramType': 'medical',
        'notes': _notesController.text,
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Drawing saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving drawing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Drawing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undo,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearCanvas,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveDrawing,
          ),
        ],
      ),
      body: Column(
        children: [
          // Patient selection
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _patientName ?? 'No patient selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: _selectPatient,
                  icon: const Icon(Icons.edit),
                  label: const Text('Select Patient'),
                ),
              ],
            ),
          ),

          // Drawing canvas
          Expanded(
            child: RepaintBoundary(
              key: _canvasKey,
              child: Container(
                color: Colors.white,
                child: Stack(
                  children: [
                    // Background image if selected
                    if (_backgroundImage != null)
                      Positioned.fill(
                        child: Image.file(
                          _backgroundImage!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    
                    // Drawing area
                    GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _points.add(
                            DrawingPoint(
                              details.localPosition,
                              Paint()
                                ..color = _selectedColor
                                ..strokeWidth = _strokeWidth
                                ..strokeCap = StrokeCap.round,
                            ),
                          );
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          _points.add(
                            DrawingPoint(
                              details.localPosition,
                              Paint()
                                ..color = _selectedColor
                                ..strokeWidth = _strokeWidth
                                ..strokeCap = StrokeCap.round,
                            ),
                          );
                        });
                      },
                      onPanEnd: (details) {
                        setState(() {
                          _points.add(
                            DrawingPoint(
                              Offset.infinite,
                              Paint(),
                            ),
                          );
                        });
                      },
                      child: CustomPaint(
                        painter: DrawingPainter(_points),
                        size: Size.infinite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tools
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Color picker
                Row(
                  children: [
                    const Text('Color: '),
                    const SizedBox(width: 8),
                    ...[ Colors.red, Colors.blue, Colors.green, Colors.black, Colors.yellow, Colors.orange].map(
                      (color) => GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == color ? Colors.black : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.palette),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Pick Color'),
                            content: SingleChildScrollView(
                              child: ColorPicker(
                                pickerColor: _selectedColor,
                                onColorChanged: (color) {
                                  setState(() => _selectedColor = color);
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                
                // Stroke width
                Row(
                  children: [
                    const Text('Thickness: '),
                    Expanded(
                      child: Slider(
                        value: _strokeWidth,
                        min: 1.0,
                        max: 10.0,
                        onChanged: (value) {
                          setState(() => _strokeWidth = value);
                        },
                      ),
                    ),
                    Text(_strokeWidth.toStringAsFixed(1)),
                  ],
                ),

                // Notes
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Add description or instructions',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                
                // Background image button
                OutlinedButton.icon(
                  onPressed: _pickBackgroundImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Add Background Image'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].offset != Offset.infinite && points[i + 1].offset != Offset.infinite) {
        canvas.drawLine(points[i].offset, points[i + 1].offset, points[i].paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}
