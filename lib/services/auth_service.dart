import '../models/user.dart';
import 'wp_api.dart';

class AuthService {
  final WPApiService _wpApiService = WPApiService();

  /// Login user with email and password
  Future<User> login({required String email, required String password}) async {
    return await _wpApiService.login(email: email, password: password);
  }

  /// Register new user with admin credentials
  Future<User> register({
    required String email,
    required String password,
  }) async {
    return await _wpApiService.register(email: email, password: password);
  }

  /// Verify JWT token
  Future<bool> verifyToken(String token) async {
    return await _wpApiService.validateToken(token);
  }
}
