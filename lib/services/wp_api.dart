import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/device.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class WPApiService {
  static const String _devicesEndpoint = wledDevicesUrl;

  /// Login user with email and password
  Future<User> login({required String email, required String password}) async {
    final response = await http.post(
      Uri.parse(jwtAuthUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': email, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Login failed');
    }
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
    // Step 1: Create the user with basic info only
    final response = await http.post(
      Uri.parse('$wpApiUrl/wp/v2/users'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$adminUsername:$applicationPassword'))}',
      },
      body: jsonEncode({
        'username': email.split('@')[0],
        'email': email,
        'password': password,
        'roles': ['subscriber'],
        'first_name': registerForWarranty ? (firstName ?? '') : '',
        'last_name': registerForWarranty ? (lastName ?? '') : '',
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final userData = jsonDecode(response.body);
      final userId = userData['id'];

      // Step 2: If warranty info provided, update user meta separately
      if (registerForWarranty) {
        await _updateUserMeta(
          userId: userId,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          address: address,
          city: city,
          province: province,
          postalCode: postalCode,
          country: country,
          installationDate: installationDate,
        );
      }

      // Step 3: Login to get JWT
      return await login(email: email, password: password);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Registration failed');
    }
  }

  /// Update user meta fields for warranty information
  Future<void> _updateUserMeta({
    required int userId,
    String? firstName,
    String? lastName,
    String? phone,
    String? address,
    String? city,
    String? province,
    String? postalCode,
    String? country,
    DateTime? installationDate,
  }) async {
    final metaFields = {
      'billing_first_name': firstName ?? '',
      'billing_last_name': lastName ?? '',
      'billing_phone': phone ?? '',
      'billing_address_1': address ?? '',
      'billing_city': city ?? '',
      'billing_state': province ?? '',
      'billing_postcode': postalCode ?? '',
      'billing_country': _toCountryCode(country),
      'installation_date': _toIsoDate(installationDate),
      'warranty_registered': 'true',
    };

    // Update each meta field individually
    for (var entry in metaFields.entries) {
      try {
        await http.post(
          Uri.parse('$wpApiUrl/wp/v2/users/$userId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
                'Basic ${base64Encode(utf8.encode('$adminUsername:$applicationPassword'))}',
          },
          body: jsonEncode({
            'meta': {entry.key: entry.value},
          }),
        );
      } catch (e) {
        print('Failed to update meta ${entry.key}: $e');
        // Continue even if one meta field fails
      }
    }
  }

  String _toCountryCode(String? name) {
    if (name == null) return '';
    switch (name) {
      case 'Canada':
        return 'CA';
      case 'United States':
        return 'US';
      default:
        return name.length == 2 ? name.toUpperCase() : name;
    }
  }

  String _toIsoDate(DateTime? dt) {
    if (dt == null) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Validate JWT token without fetching data
  Future<bool> validateToken(String jwtToken) async {
    try {
      print('🔐 TOKEN: Validating JWT token');

      final response = await http
          .get(
            Uri.parse('$wpApiUrl/wp/v2/users/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwtToken',
            },
          )
          .timeout(const Duration(seconds: 5));

      print('🔐 TOKEN: Validation response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('🔐 TOKEN: Validation failed: $e');
      return false;
    }
  }

  /// Get all devices from WordPress
  Future<List<Device>> getDevices(String jwtToken) async {
    try {
      print('🔄 WP API: Fetching devices from $_devicesEndpoint');
      print('🔄 WP API: JWT token length: ${jwtToken.length}');

      final response = await http
          .get(
            Uri.parse(_devicesEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwtToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('🔄 WP API: Response status: ${response.statusCode}');
      print('🔄 WP API: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final devices = data
            .map((e) => Device.fromJson(_wpToDeviceJson(e)))
            .toList();
        print(
          '🔄 WP API: Successfully fetched ${devices.length} devices from WordPress',
        );
        return devices;
      } else {
        print(
          '🔄 WP API: Failed to fetch devices: ${response.statusCode} ${response.body}',
        );
        throw Exception(
          'Failed to load devices: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('🔄 WP API: Network error: $e');
      throw Exception('Network error: $e');
    }
  }

  /// Add a new device to WordPress
  Future<Device> addDevice(Device device, String jwtToken) async {
    try {
      final response = await http
          .post(
            Uri.parse(_devicesEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwtToken',
            },
            body: jsonEncode({
              'title': device.name,
              'status': 'publish',
              'meta': {
                'mqtt_client_id': device.mqttClientId,
                'mqtt_username': device.mqttUsername,
                'mqtt_password': device.mqttPassword,
                'allowed_users': device.allowedUsers,
                'ip_address': device.ipAddress,
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Device.fromJson(_wpToDeviceJson(data));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to add device');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Update an existing device in WordPress
  Future<Device> updateDevice(Device device, String jwtToken) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_devicesEndpoint/${device.id}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwtToken',
            },
            body: jsonEncode({
              'title': device.name,
              'meta': {
                'mqtt_client_id': device.mqttClientId,
                'mqtt_username': device.mqttUsername,
                'mqtt_password': device.mqttPassword,
                'allowed_users': device.allowedUsers,
                'ip_address': device.ipAddress,
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Device.fromJson(_wpToDeviceJson(data));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to update device');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Delete a device from WordPress
  Future<void> deleteDevice(String deviceId, String jwtToken) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_devicesEndpoint/$deviceId?force=true'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwtToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete device');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Helper to convert WP API response to Device JSON
  Map<String, dynamic> _wpToDeviceJson(Map<String, dynamic> wp) {
    final meta = (wp['meta'] is Map<String, dynamic>) ? wp['meta'] : {};
    return {
      'id': wp['id'].toString(),
      'name': wp['title']?['rendered'] ?? '',
      'ip_address': meta['ip_address'] ?? '',
      'mqtt_client_id': meta['mqtt_client_id'] ?? '',
      'mqtt_username': meta['mqtt_username'] ?? '',
      'mqtt_password': meta['mqtt_password'] ?? '',
      'allowed_users': meta['allowed_users'] ?? [],
    };
  }
}
