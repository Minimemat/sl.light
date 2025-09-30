import 'dart:convert';
import 'package:http/http.dart' as http;

class WledApi {
  String _fixScheme(String url) {
    // If the IP is a local address, use http. Otherwise, use https.
    final uri = Uri.parse(url);
    final host = uri.host;
    if (host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        host == 'localhost') {
      return url
          .replaceFirst('https://', 'http://')
          .replaceFirst('http://', 'http://');
    } else {
      return url.replaceFirst('http://', 'https://');
    }
  }

  Future<void> setMqttSettings({
    required String ip,
    required String broker,
    required String clientId,
    required String username,
    required String password,
  }) async {
    final url = Uri.parse(_fixScheme('http://$ip/json/cfg'));
    final body = jsonEncode({
      'if': {
        'mqtt': {
          'en': true,
          'broker': broker,
          'cid': clientId,
          'user': username,
          'psk': password,
          'topics': {'device': 'wled/$clientId', 'group': 'wled/all'},
          'btn': true,
          'rtn': true,
        },
        'ntp': {'en': true, 'host': '0.wled.pool.ntp.org', 'tz': 14},
      },
      'def': {'on': false},
    });
    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = body;
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 5),
    );
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      print('WLED MQTT set error: ${response.body}');
      throw Exception(
        'Failed to set MQTT settings on WLED device: ${response.body}',
      );
    }
  }

  Future<void> restartDevice(String ip) async {
    final url = Uri.parse(_fixScheme('http://$ip/reset'));
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        print('WLED restart error: \\${response.body}');
        throw Exception('Failed to restart WLED device: \\${response.body}');
      }
    } catch (e) {
      // If the error is a parse error or connection reset, assume reboot is in progress
      print(
        'Ignoring error during WLED reset (likely due to device rebooting): $e',
      );
    }
  }

  /// Fetch WLED configuration file
  Future<Map<String, dynamic>> getConfig(String ip) async {
    final url = Uri.parse(_fixScheme('http://$ip/json/cfg'));
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        print('WLED get config error: ${response.body}');
        throw Exception('Failed to get WLED config: ${response.body}');
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print('Error fetching WLED config: $e');
      throw Exception('Failed to fetch WLED config: $e');
    }
  }

  /// Update WLED configuration file
  Future<void> updateConfig(String ip, Map<String, dynamic> config) async {
    final url = Uri.parse(_fixScheme('http://$ip/json/cfg'));
    final body = jsonEncode(config);
    try {
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = body;
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 200) {
        print('WLED update config error: ${response.body}');
        throw Exception('Failed to update WLED config: ${response.body}');
      }
    } catch (e) {
      print('Error updating WLED config: $e');
      throw Exception('Failed to update WLED config: $e');
    }
  }

  /// Set timers in WLED configuration
  Future<void> setTimers(String ip, List<Map<String, dynamic>> timers) async {
    try {
      // First, get current config
      final config = await getConfig(ip);

      // Ensure timers section exists with proper structure
      if (config['timers'] == null) {
        config['timers'] = {};
      }
      if (config['timers']['ins'] == null) {
        config['timers']['ins'] = [];
      }

      // Clear existing timers and rebuild the ins array
      final timerInstances = <Map<String, dynamic>>[];

      // First, add disabled timers to clear all 16 slots
      for (int i = 0; i < 16; i++) {
        timerInstances.add({
          'en': 0, // Disabled
          'hour': 0,
          'min': 0,
          'macro': 0,
          'dow': 0,
          'start': {'mon': 1, 'day': 1},
          'end': {'mon': 12, 'day': 31},
        });
      }

      // Then, overwrite with active timers at specific slots
      for (final timerConfig in timers) {
        final timer = timerConfig['timer'];
        final slot = timerConfig['slot'] ?? 0;

        // Ensure slot is within bounds
        if (slot >= 0 && slot < 16) {
          // Replace the disabled timer with active timer at specific slot
          timerInstances[slot] = {
            'en': timer['en'],
            'hour': timer['hour'],
            'min': timer['min'],
            'macro': timer['ps'], // Use preset as macro
            'dow': timer['dow'],
            'start': {'mon': 1, 'day': 1},
            'end': {'mon': 12, 'day': 31},
          };
        }
      }

      // Set the timers instances array
      config['timers']['ins'] = timerInstances;

      // Update the config
      await updateConfig(ip, config);

      print('Timers set successfully via HTTP cfg for $ip');
    } catch (e) {
      print('Error setting timers via HTTP cfg: $e');
      throw Exception('Failed to set timers: $e');
    }
  }
}
