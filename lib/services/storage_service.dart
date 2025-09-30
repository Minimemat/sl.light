import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../models/device.dart';

class StorageService {
  static const String _userKey = 'user_data';
  static const String _devicesKey = 'devices_data';

  /// Save user data for persistent login
  Future<void> saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = jsonEncode(user.toJson());
      await prefs.setString(_userKey, userData);
    } catch (e) {
      throw Exception('Failed to save user data: $e');
    }
  }

  /// Load saved user data
  Future<User?> loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userKey);

      if (userData != null) {
        final userJson = jsonDecode(userData);
        return User.fromJson(userJson);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save devices list locally
  Future<void> saveDevices(List<Device> devices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesData = jsonEncode(
        devices.map((device) => device.toJson()).toList(),
      );
      await prefs.setString(_devicesKey, devicesData);
    } catch (e) {
      throw Exception('Failed to save devices: $e');
    }
  }

  /// Load saved devices list
  Future<List<Device>> loadDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesData = prefs.getString(_devicesKey);

      if (devicesData != null) {
        final List<dynamic> devicesJson = jsonDecode(devicesData);
        return devicesJson.map((json) => Device.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Save device IP address for discovery
  Future<void> saveDeviceIpAddress(String deviceId, String ipAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_ip_$deviceId', ipAddress);
    } catch (e) {
      // Silently fail for IP address storage
    }
  }

  /// Load device IP address
  Future<String?> loadDeviceIpAddress(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('device_ip_$deviceId');
    } catch (e) {
      return null;
    }
  }

  /// Remove device IP address
  Future<void> removeDeviceIpAddress(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('device_ip_$deviceId');
    } catch (e) {
      // Silently fail
    }
  }

  /// Clear all stored data (for logout)
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      throw Exception('Failed to clear data: $e');
    }
  }

  /// Check if user data exists
  Future<bool> hasUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_userKey);
    } catch (e) {
      return false;
    }
  }

  /// Save device settings
  Future<void> saveDeviceSettings(
    String deviceId,
    Map<String, dynamic> settings,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsData = jsonEncode(settings);
      await prefs.setString('device_settings_$deviceId', settingsData);
    } catch (e) {
      throw Exception('Failed to save device settings: $e');
    }
  }

  /// Load device settings
  Future<Map<String, dynamic>?> getDeviceSettings(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsData = prefs.getString('device_settings_$deviceId');

      if (settingsData != null) {
        final settingsJson = jsonDecode(settingsData);
        return Map<String, dynamic>.from(settingsJson);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save selected preset (by ID) for a specific device
  Future<void> saveSelectedPresetForDevice(
    String deviceId,
    String presetId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_preset_$deviceId', presetId);
    } catch (e) {
      // Silently fail
    }
  }

  /// Load previously selected preset (by ID) for a device
  Future<String?> loadSelectedPresetForDevice(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('selected_preset_$deviceId');
    } catch (e) {
      return null;
    }
  }

  /// Clear stored selected preset for a device
  Future<void> clearSelectedPresetForDevice(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_preset_$deviceId');
    } catch (e) {
      // Silently fail
    }
  }

  /// Save brightness setting for a device
  Future<void> saveDeviceBrightness(String deviceId, int brightness) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('device_brightness_$deviceId', brightness);
    } catch (e) {
      // Silently fail
    }
  }

  /// Load brightness setting for a device (default: 150)
  Future<int> loadDeviceBrightness(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('device_brightness_$deviceId') ?? 150;
    } catch (e) {
      return 150;
    }
  }

  /// Save favorite presets list
  Future<void> saveFavoritePresets(List<String> presetIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_presets', presetIds);
    } catch (e) {
      // Silently fail
    }
  }

  /// Load favorite presets list
  Future<List<String>> loadFavoritePresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('favorite_presets') ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Toggle favorite status for a preset
  Future<void> togglePresetFavorite(String presetId) async {
    try {
      final favorites = await loadFavoritePresets();
      if (favorites.contains(presetId)) {
        favorites.remove(presetId);
      } else {
        favorites.add(presetId);
      }
      await saveFavoritePresets(favorites);
    } catch (e) {
      // Silently fail
    }
  }
}
