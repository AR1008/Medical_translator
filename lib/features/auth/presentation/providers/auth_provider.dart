import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../auth/data/models/user_model.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  AuthNotifier() : super(const AsyncValue.loading()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    state = const AsyncValue.data(null);
  }

  Future<bool> login(String username, String password) async {
    try {
      print('🔐 Login attempt: $username');
      state = const AsyncValue.loading();
      
      final userData = await _db.login(username, password);
      print('📊 User data: $userData');
      
      if (userData != null) {
        final user = User.fromMap(userData);
        print('✅ User created: ${user.fullName}, type: ${user.userType}');
        state = AsyncValue.data(user);
        print('✅ State updated with user');
        return true;
      } else {
        print('❌ Login failed - invalid credentials');
        state = const AsyncValue.data(null);
        return false;
      }
    } catch (e, stack) {
      print('❌ Login error: $e');
      print('Stack: $stack');
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> userData) async {
    try {
      final success = await _db.registerUser(userData);
      return success;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.data(null);
  }

  Future<bool> checkUsername(String username) async {
    return await _db.usernameExists(username);
  }
}
