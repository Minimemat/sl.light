import 'dart:convert';
import 'dart:io';
import '../models/device.dart';

class DeviceInfoService {
  static const Duration _timeout = Duration(seconds: 5);

  /// Fetches device information from the HTTP JSON endpoint
  /// Returns null if the request fails
  static Future<Map<String, dynamic>?> getDeviceInfo(Device device) async {
    try {
      final url = 'http://${device.ipAddress}/json/info';
      print('Fetching device info from: $url');
      
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close().timeout(_timeout);
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        print('Device info received: ${data.keys.join(', ')}');
        return data;
      } else {
        print('Failed to fetch device info: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching device info: $e');
      return null;
    }
  }

  /// Formats power usage in watts
  static String formatPowerUsage(dynamic power) {
    if (power == null) return 'Unknown';
    if (power is int) {
      return '${(power / 1000).toStringAsFixed(1)}W';
    }
    if (power is String) {
      final powerInt = int.tryParse(power);
      if (powerInt != null) {
        return '${(powerInt / 1000).toStringAsFixed(1)}W';
      }
    }
    return 'Unknown';
  }

  /// Formats uptime in a human-readable format
  static String formatUptime(dynamic uptime) {
    if (uptime == null) return 'Unknown';
    
    int seconds = 0;
    if (uptime is int) seconds = uptime;
    if (uptime is String) seconds = int.tryParse(uptime) ?? 0;
    
    final duration = Duration(seconds: seconds);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    
    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Formats signal strength with percentage
  static String formatSignalStrength(dynamic rssi) {
    if (rssi == null) return 'Unknown';
    
    int rssiValue = 0;
    if (rssi is int) rssiValue = rssi;
    if (rssi is String) rssiValue = int.tryParse(rssi) ?? 0;
    
    // Convert RSSI to percentage (RSSI ranges from -100 to -30, where -30 is best)
    final percentage = ((rssiValue + 100) / 70 * 100).clamp(0, 100).round();
    
    String quality = 'Poor';
    if (percentage >= 80) {
      quality = 'Excellent';
    } else if (percentage >= 60) quality = 'Good';
    else if (percentage >= 40) quality = 'Fair';
    else if (percentage >= 20) quality = 'Poor';
    else quality = 'Very Poor';
    
    return '$quality ($percentage%)';
  }

  /// Formats LED count and power info
  static String formatLedInfo(Map<String, dynamic>? leds) {
    if (leds == null) return 'Unknown';
    
    final count = leds['count']?.toString() ?? 'Unknown';
    final power = formatPowerUsage(leds['pwr']);
    final maxPower = leds['maxpwr'] != null ? '${(leds['maxpwr'] / 1000).toStringAsFixed(1)}W' : 'Unknown';
    
    return '$count LEDs ($power / $maxPower max)';
  }

  /// Formats WiFi information
  static String formatWifiInfo(Map<String, dynamic>? wifi) {
    if (wifi == null) return 'Unknown';
    
    final bssid = wifi['bssid']?.toString() ?? 'Unknown';
    final channel = wifi['channel']?.toString() ?? 'Unknown';
    final signal = formatSignalStrength(wifi['rssi']);
    
    return '$bssid (Ch $channel, $signal)';
  }

  /// Formats the current time from device
  static String formatDeviceTime(dynamic time) {
    if (time == null) return 'Unknown';
    return time.toString();
  }
} 