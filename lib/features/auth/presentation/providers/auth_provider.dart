import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../auth/data/models/user_model.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final FirebaseService _firebase = FirebaseService.instance;

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
      
      final userData = await _firebase.login(username, password);
      
      if (userData != null) {
        final user = User.fromMap(userData);
        print('✅ User logged in: ${user.fullName}');
        state = AsyncValue.data(user);
        return true;
      } else {
        print('❌ Login failed');
        state = const AsyncValue.data(null);
        return false;
      }
    } catch (e, stack) {
      print('❌ Login error: $e');
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> userData) async {
    try {
      return await _firebase.registerUser(userData);
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.data(null);
  }

  Future<bool> checkUsername(String username) async {
    return await _firebase.usernameExists(username);
  }
}
