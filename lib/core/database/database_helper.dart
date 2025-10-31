import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('medical_hospital.db');
    return _database!;
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // Increased version to force recreation
      onCreate: (db, version) async {
        print('🗄️ Creating database...');
        await _createDB(db, version);
        await _seedDemoUsers(db);
        print('✅ Database created with demo users');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('🔄 Upgrading database from $oldVersion to $newVersion');
        await _upgradeDB(db, oldVersion, newVersion);
        // Seed demo users on upgrade too
        await _seedDemoUsers(db);
        print('✅ Database upgraded with demo users');
      },
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transport_requests (
          id TEXT PRIMARY KEY,
          patientId TEXT NOT NULL,
          doctorId TEXT NOT NULL,
          fromLocation TEXT NOT NULL,
          toLocation TEXT NOT NULL,
          transportType TEXT NOT NULL,
          status TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          FOREIGN KEY (patientId) REFERENCES users (id),
          FOREIGN KEY (doctorId) REFERENCES users (id)
        )
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';
    const boolType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE users (
        id $idType,
        username $textType UNIQUE,
        password $textType,
        fullName $textType,
        userType $textType,
        department $textNullable,
        specialization $textNullable,
        email $textType,
        phone $textNullable,
        isActive $boolType DEFAULT 1,
        createdAt $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE patient_records (
        id $idType,
        patientId $textType,
        doctorId $textNullable,
        diagnosis $textNullable,
        symptoms $textNullable,
        notes $textNullable,
        createdAt $textType,
        updatedAt $textType,
        FOREIGN KEY (patientId) REFERENCES users (id),
        FOREIGN KEY (doctorId) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE medical_drawings (
        id $idType,
        patientId $textType,
        doctorId $textType,
        sessionId $textNullable,
        imagePath $textType,
        diagramType $textNullable,
        notes $textNullable,
        createdAt $textType,
        FOREIGN KEY (patientId) REFERENCES users (id),
        FOREIGN KEY (doctorId) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id $idType,
        patientId $textType,
        doctorId $textType,
        status $textType,
        startTime $textType,
        endTime $textNullable,
        notes $textNullable,
        FOREIGN KEY (patientId) REFERENCES users (id),
        FOREIGN KEY (doctorId) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE prescriptions (
        id $idType,
        patientId $textType,
        doctorId $textType,
        sessionId $textNullable,
        medicines TEXT,
        instructions $textNullable,
        createdAt $textType,
        FOREIGN KEY (patientId) REFERENCES users (id),
        FOREIGN KEY (doctorId) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE queue (
        id $idType,
        patientId $textType,
        priority $intType,
        department $textType,
        status $textType,
        assignedDoctorId $textNullable,
        checkinTime $textType,
        notes $textNullable,
        FOREIGN KEY (patientId) REFERENCES users (id),
        FOREIGN KEY (assignedDoctorId) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE emergency_alerts (
        id $idType,
        patientId $textType,
        adminId $textNullable,
        alertType $textType,
        location $textNullable,
        status $textType,
        createdAt $textType,
        resolvedAt $textNullable,
        FOREIGN KEY (patientId) REFERENCES users (id),
        FOREIGN KEY (adminId) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE transport_requests (
        id $idType,
        patientId $textType,
        doctorId $textType,
        fromLocation $textType,
        toLocation $textType,
        transportType $textType,
        status $textType,
        createdAt $textType,
        FOREIGN KEY (patientId) REFERENCES users (id),
        FOREIGN KEY (doctorId) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE translation_history (
        id $idType,
        userId $textType,
        sourceText $textType,
        translatedText $textType,
        sourceLang $textType,
        targetLang $textType,
        createdAt $textType,
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE session_messages (
        id $idType,
        sessionId $textType,
        senderId $textType,
        senderRole $textType,
        originalText $textType,
        translatedText $textType,
        sourceLang $textType,
        targetLang $textType,
        timestamp $textType,
        FOREIGN KEY (sessionId) REFERENCES sessions (id),
        FOREIGN KEY (senderId) REFERENCES users (id)
      )
    ''');
  }

  Future<void> _seedDemoUsers(Database db) async {
    final now = DateTime.now().toIso8601String();
    const uuid = Uuid();

    print('🌱 Seeding demo users...');

    // Check if users already exist
    final existingUsers = await db.query('users', limit: 1);
    if (existingUsers.isNotEmpty) {
      print('✅ Users already exist, skipping seed');
      return;
    }

    try {
      // Create demo patient
      final patientId = uuid.v4();
      await db.insert('users', {
        'id': patientId,
        'username': 'patient',
        'password': _hashPassword('patient123'),
        'fullName': 'Demo Patient',
        'userType': 'patient',
        'department': '',
        'specialization': '',
        'email': 'patient@demo.com',
        'phone': '1234567890',
        'isActive': 1,
        'createdAt': now,
      });
      print('✅ Created patient user: $patientId');

      // Create demo doctor
      final doctorId = uuid.v4();
      await db.insert('users', {
        'id': doctorId,
        'username': 'doctor',
        'password': _hashPassword('doctor123'),
        'fullName': 'Demo Doctor',
        'userType': 'doctor',
        'department': 'General Medicine',
        'specialization': 'General Physician',
        'email': 'doctor@demo.com',
        'phone': '9876543210',
        'isActive': 1,
        'createdAt': now,
      });
      print('✅ Created doctor user: $doctorId');

      // Create demo admin
      final adminId = uuid.v4();
      await db.insert('users', {
        'id': adminId,
        'username': 'admin',
        'password': _hashPassword('admin123'),
        'fullName': 'Demo Admin',
        'userType': 'admin',
        'department': 'Administration',
        'specialization': '',
        'email': 'admin@demo.com',
        'phone': '5555555555',
        'isActive': 1,
        'createdAt': now,
      });
      print('✅ Created admin user: $adminId');

      // Verify users were created
      final userCount = await db.query('users');
      print('✅ Total users in database: ${userCount.length}');
    } catch (e) {
      print('❌ Error seeding users: $e');
    }
  }

  // User operations
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await database;
    final hashedPassword = _hashPassword(password);
    
    print('🔍 Looking for user: $username');
    print('🔑 Hashed password: ${hashedPassword.substring(0, 10)}...');
    
    final results = await db.query(
      'users',
      where: 'username = ? AND password = ? AND isActive = 1',
      whereArgs: [username, hashedPassword],
    );
    
    if (results.isNotEmpty) {
      print('✅ User found: ${results.first}');
    } else {
      print('❌ No user found with those credentials');
      // Debug: Check if user exists with different password
      final userExists = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
      );
      if (userExists.isNotEmpty) {
        print('⚠️ User exists but password doesn\'t match');
        print('⚠️ Stored password hash: ${userExists.first['password']}');
      } else {
        print('⚠️ User doesn\'t exist at all');
      }
    }
    
    return results.isNotEmpty ? results.first : null;
  }

  Future<bool> registerUser(Map<String, dynamic> user) async {
    try {
      final db = await database;
      user['password'] = _hashPassword(user['password']);
      await db.insert('users', user);
      return true;
    } catch (e) {
      print('❌ Error registering user: $e');
      return false;
    }
  }

  Future<bool> usernameExists(String username) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    return result.isNotEmpty;
  }

  // Patient records
  Future<List<Map<String, dynamic>>> getPatientRecords(String patientId) async {
    final db = await database;
    return await db.query(
      'patient_records',
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'createdAt DESC',
    );
  }

  Future<int> insertPatientRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await db.insert('patient_records', record);
  }

  // Medical drawings
  Future<List<Map<String, dynamic>>> getPatientDrawings(String patientId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT md.*, u.fullName as doctorName
      FROM medical_drawings md
      INNER JOIN users u ON md.doctorId = u.id
      WHERE md.patientId = ?
      ORDER BY md.createdAt DESC
    ''', [patientId]);
  }

  Future<int> saveDrawing(Map<String, dynamic> drawing) async {
    final db = await database;
    return await db.insert('medical_drawings', drawing);
  }

  // Sessions
  Future<Map<String, dynamic>?> getActiveSession(String doctorId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT s.*, u.fullName as patientName, u.phone as patientPhone, u.id as patientId
      FROM sessions s
      INNER JOIN users u ON s.patientId = u.id
      WHERE s.doctorId = ? AND s.status = 'active'
      LIMIT 1
    ''', [doctorId]);
    
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> createSession(Map<String, dynamic> session) async {
    final db = await database;
    return await db.insert('sessions', session);
  }

  Future<int> updateSession(String id, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update(
      'sessions',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Queue
  Future<List<Map<String, dynamic>>> getQueue() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT q.*, u.fullName as patientName, u.phone as patientPhone
      FROM queue q
      INNER JOIN users u ON q.patientId = u.id
      WHERE q.status IN ('waiting', 'in_progress')
      ORDER BY q.priority ASC, q.checkinTime ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getDoctorQueue(String doctorId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT q.*, u.fullName as patientName, u.phone as patientPhone, u.id as patientId
      FROM queue q
      INNER JOIN users u ON q.patientId = u.id
      WHERE q.assignedDoctorId = ? AND q.status = 'waiting'
      ORDER BY q.priority ASC, q.checkinTime ASC
    ''', [doctorId]);
  }

  Future<int> addToQueue(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert('queue', item);
  }

  Future<int> updateQueueStatus(String id, String status) async {
    final db = await database;
    return await db.update(
      'queue',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> removeFromQueue(String patientId, String doctorId) async {
    final db = await database;
    return await db.delete(
      'queue',
      where: 'patientId = ? AND assignedDoctorId = ?',
      whereArgs: [patientId, doctorId],
    );
  }

  // Prescriptions
  Future<List<Map<String, dynamic>>> getPatientPrescriptions(String patientId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, u.fullName as doctorName
      FROM prescriptions p
      INNER JOIN users u ON p.doctorId = u.id
      WHERE p.patientId = ?
      ORDER BY p.createdAt DESC
    ''', [patientId]);
  }

  Future<int> savePrescription(Map<String, dynamic> prescription) async {
    final db = await database;
    return await db.insert('prescriptions', prescription);
  }

  // Emergency alerts
  Future<List<Map<String, dynamic>>> getEmergencyAlerts() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT ea.*, u.fullName as patientName, u.phone as patientPhone
      FROM emergency_alerts ea
      INNER JOIN users u ON ea.patientId = u.id
      WHERE ea.status = 'active'
      ORDER BY ea.createdAt DESC
    ''');
  }

  Future<int> createEmergencyAlert(Map<String, dynamic> alert) async {
    final db = await database;
    return await db.insert('emergency_alerts', alert);
  }

  Future<int> resolveAlert(String id) async {
    final db = await database;
    return await db.update(
      'emergency_alerts',
      {
        'status': 'resolved',
        'resolvedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Transport requests
  Future<List<Map<String, dynamic>>> getTransportRequests() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT tr.*, 
             u.fullName as patientName, 
             u.phone as patientPhone,
             d.fullName as doctorName
      FROM transport_requests tr
      INNER JOIN users u ON tr.patientId = u.id
      INNER JOIN users d ON tr.doctorId = d.id
      WHERE tr.status = 'pending'
      ORDER BY tr.createdAt DESC
    ''');
  }

  Future<int> createTransportRequest(Map<String, dynamic> request) async {
    final db = await database;
    return await db.insert('transport_requests', request);
  }

  Future<int> updateTransportStatus(String id, String status) async {
    final db = await database;
    return await db.update(
      'transport_requests',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Session messages
  Future<List<Map<String, dynamic>>> getSessionMessages(String sessionId) async {
    final db = await database;
    return await db.query(
      'session_messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<int> saveSessionMessage(Map<String, dynamic> message) async {
    final db = await database;
    return await db.insert('session_messages', message);
  }

  // Translation history
  Future<int> saveTranslation(Map<String, dynamic> translation) async {
    final db = await database;
    return await db.insert('translation_history', translation);
  }

  Future<List<Map<String, dynamic>>> getTranslationHistory(String userId) async {
    final db = await database;
    return await db.query(
      'translation_history',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
      limit: 50,
    );
  }

  Future<List<Map<String, dynamic>>> getAllPatients() async {
    final db = await database;
    return await db.query(
      'users',
      where: 'userType = ? AND isActive = 1',
      whereArgs: ['patient'],
      orderBy: 'fullName ASC',
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
