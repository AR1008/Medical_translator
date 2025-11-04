import 'package:cloud_firestore/cloud_firestore.dart';

class CleanupHelper {
  static Future<void> cleanupOldSessions() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get all active sessions
      final activeSessions = await firestore
          .collection('sessions')
          .where('status', isEqualTo: 'active')
          .get();
      
      // Close sessions older than 1 hour
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      
      for (var doc in activeSessions.docs) {
        final data = doc.data();
        final startTime = DateTime.parse(data['startTime'] ?? DateTime.now().toIso8601String());
        
        if (startTime.isBefore(oneHourAgo)) {
          await doc.reference.update({
            'status': 'completed',
            'endTime': DateTime.now().toIso8601String(),
          });
          print('✅ Cleaned up old session: ${doc.id}');
        }
      }
    } catch (e) {
      print('❌ Cleanup error: $e');
    }
  }
}
