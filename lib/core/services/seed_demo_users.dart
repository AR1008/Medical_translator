import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DemoDataSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static Future<void> seedDemoUsers() async {
    print('🌱 Checking for demo users...');
    
    try {
      // Check if users already exist
      final existingUsers = await _firestore.collection('users').limit(1).get();
      if (existingUsers.docs.isNotEmpty) {
        print('✅ Users already exist, skipping seed');
        return;
      }

      final now = DateTime.now().toIso8601String();

      print('📝 Creating demo users...');

      // Create patient
      await _firestore.collection('users').add({
        'username': 'patient',
        'password': _hashPassword('patient123'),
        'fullName': 'Demo Patient',
        'userType': 'patient',
        'department': '',
        'specialization': '',
        'email': 'patient@demo.com',
        'phone': '1234567890',
        'isActive': true,
        'createdAt': now,
      });
      print('✅ Created patient user');

      // Create doctor
      await _firestore.collection('users').add({
        'username': 'doctor',
        'password': _hashPassword('doctor123'),
        'fullName': 'Demo Doctor',
        'userType': 'doctor',
        'department': 'General Medicine',
        'specialization': 'General Physician',
        'email': 'doctor@demo.com',
        'phone': '9876543210',
        'isActive': true,
        'createdAt': now,
      });
      print('✅ Created doctor user');

      // Create admin
      await _firestore.collection('users').add({
        'username': 'admin',
        'password': _hashPassword('admin123'),
        'fullName': 'Demo Admin',
        'userType': 'admin',
        'department': 'Administration',
        'specialization': '',
        'email': 'admin@demo.com',
        'phone': '5555555555',
        'isActive': true,
        'createdAt': now,
      });
      print('✅ Created admin user');

      print('✅✅✅ All demo users created successfully!');
    } catch (e) {
      print('❌ Error seeding users: $e');
    }
  }
}
