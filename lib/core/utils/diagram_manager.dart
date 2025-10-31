import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class DiagramManager {
  static const Map<String, List<DiagramInfo>> diagrams = {
    'Anatomy': [
      DiagramInfo('Heart', 'assets/diagrams/anatomy/heart.png'),
      DiagramInfo('Brain', 'assets/diagrams/anatomy/brain.png'),
      DiagramInfo('Lungs', 'assets/diagrams/anatomy/lungs.png'),
      DiagramInfo('Skeleton', 'assets/diagrams/anatomy/skeleton.png'),
    ],
    'Organs': [
      DiagramInfo('Liver', 'assets/diagrams/organs/liver.png'),
      DiagramInfo('Kidney', 'assets/diagrams/organs/kidney.png'),
      DiagramInfo('Stomach', 'assets/diagrams/organs/stomach.png'),
    ],
    'Systems': [
      DiagramInfo('Digestive System', 'assets/diagrams/systems/digestive.png'),
      DiagramInfo('Circulatory System', 'assets/diagrams/systems/circulatory.png'),
      DiagramInfo('Respiratory System', 'assets/diagrams/systems/respiratory.png'),
      DiagramInfo('Nervous System', 'assets/diagrams/systems/nervous.png'),
    ],
    'Blank': [
      DiagramInfo('Blank Canvas', 'assets/diagrams/blank/blank_canvas.png'),
    ],
  };

  static Future<ui.Image?> loadDiagramImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Error loading diagram: $e');
      return null;
    }
  }

  static Future<bool> diagramExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }
}

class DiagramInfo {
  final String name;
  final String assetPath;

  const DiagramInfo(this.name, this.assetPath);
}
