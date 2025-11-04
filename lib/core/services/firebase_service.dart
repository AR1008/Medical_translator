import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._init();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  FirebaseService._init();

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // ==================== AUTHENTICATION ====================
  
  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      print('🔐 Firebase Login attempt: $username');
      
      final hashedPassword = _hashPassword(password);
      
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .where('password', isEqualTo: hashedPassword)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        userData['id'] = querySnapshot.docs.first.id;
        print('✅ User found: ${userData['fullName']}');
        return userData;
      }
      
      print('❌ No user found');
      return null;
    } catch (e) {
      print('❌ Login error: $e');
      return null;
    }
  }

  Future<bool> registerUser(Map<String, dynamic> userData) async {
    try {
      userData['password'] = _hashPassword(userData['password']);
      await _firestore.collection('users').add(userData);
      return true;
    } catch (e) {
      print('❌ Registration error: $e');
      return false;
    }
  }

  Future<bool> usernameExists(String username) async {
    final snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getAllDoctors() async {
    final snapshot = await _firestore
        .collection('users')
        .where('userType', isEqualTo: 'doctor')
        .where('isActive', isEqualTo: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // ==================== QUEUE MANAGEMENT ====================
  
  Future<void> addToQueue(Map<String, dynamic> queueData) async {
    await _firestore.collection('queue').doc(queueData['id']).set(queueData);
    print('✅ Added to queue: ${queueData['patientId']}');
  }

  Stream<List<Map<String, dynamic>>> watchDoctorQueue(String doctorId) {
    return _firestore
        .collection('queue')
        .where('assignedDoctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'waiting')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> queue = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        final patientDoc = await _firestore.collection('users').doc(data['patientId']).get();
        if (patientDoc.exists) {
          data['patientName'] = patientDoc.data()?['fullName'];
          data['patientPhone'] = patientDoc.data()?['phone'];
        }
        
        queue.add(data);
      }
      
      queue.sort((a, b) {
        final priorityCompare = (a['priority'] as int).compareTo(b['priority'] as int);
        if (priorityCompare != 0) return priorityCompare;
        return (a['checkinTime'] as String).compareTo(b['checkinTime'] as String);
      });
      
      return queue;
    });
  }

  Future<void> removeFromQueue(String queueId) async {
    await _firestore.collection('queue').doc(queueId).delete();
    print('✅ Removed from queue: $queueId');
  }

  // ==================== SESSION MANAGEMENT ====================
  
  Future<String> createSession(Map<String, dynamic> sessionData) async {
    final docRef = await _firestore.collection('sessions').add(sessionData);
    print('✅ Session created: ${docRef.id}');
    return docRef.id;
  }

  Future<void> updateSession(String sessionId, Map<String, dynamic> updates) async {
    await _firestore.collection('sessions').doc(sessionId).update(updates);
  }

  Stream<Map<String, dynamic>?> watchPatientActiveSession(String patientId) {
    return _firestore
        .collection('sessions')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return null;
      
      final data = snapshot.docs.first.data();
      data['id'] = snapshot.docs.first.id;
      
      final doctorDoc = await _firestore.collection('users').doc(data['doctorId']).get();
      if (doctorDoc.exists) {
        data['doctorName'] = doctorDoc.data()?['fullName'];
      }
      
      return data;
    });
  }

  // ==================== MESSAGES (SIMPLIFIED - FIRESTORE ONLY) ====================
  
  Future<void> sendMessage(String sessionId, Map<String, dynamic> message) async {
    try {
      await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('messages')
          .add(message);
      
      print('✅ Message sent to Firestore: ${message['originalText']}');
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> watchSessionMessages(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // ==================== TRANSLATIONS ====================
  
  Future<void> saveTranslation(Map<String, dynamic> translation) async {
    await _firestore.collection('translations').add(translation);
  }

  // ==================== PRESCRIPTIONS ====================
  
  Future<void> savePrescription(Map<String, dynamic> prescription) async {
    await _firestore.collection('prescriptions').add(prescription);
  }

  Future<List<Map<String, dynamic>>> getPatientPrescriptions(String patientId) async {
    final snapshot = await _firestore
        .collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}
