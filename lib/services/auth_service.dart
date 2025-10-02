import '../models/user.dart';
import 'wp_api.dart';

class AuthService {
  final WPApiService _wpApiService = WPApiService();

  /// Login user with email and password
  Future<User> login({required String email, required String password}) async {
    return await _wpApiService.login(email: email, password: password);
  }

  /// Register new user with warranty information
  Future<User> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
    String? address,
    String? city,
    String? province,
    String? postalCode,
    String? country,
    DateTime? installationDate,
    required bool registerForWarranty,
  }) async {
    return await _wpApiService.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      address: address,
      city: city,
      province: province,
      postalCode: postalCode,
      country: country,
      installationDate: installationDate,
      registerForWarranty: registerForWarranty,
    );
  }

  /// Verify JWT token
  Future<bool> verifyToken(String token) async {
    return await _wpApiService.validateToken(token);
  }
}
