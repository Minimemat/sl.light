import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/device.dart';
import 'wp_api.dart';
import 'mdns_service.dart';

class DeviceDiscoveryService {
  final WPApiService _wpApiService = WPApiService();

  /// Get MAC address from WLED device
  Future<String?> getMacAddress(String ip) async {
    final url = Uri.parse('http://$ip/json');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      // WLED /json returns info.mac (e.g. "A0:AA:BB:CC:DD:EE")
      if (json['info']?['mac'] != null && json['info']['mac'] is String) {
        String mac = json['info']['mac'];
        mac = mac.replaceAll(':', '').replaceAll('-', '').toLowerCase();
        return mac;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Discover device IP address using platform-appropriate method
  Future<String?> discoverDeviceIp(String macAddress) async {
    print('Discovering IP for MAC: $macAddress');

    final MdnsService mdns = MdnsService();

    // Try MDNS first on supported platforms
    if (mdns.isSupported) {
      print('Using MDNS discovery...');
      try {
        await for (final device in mdns.discoverWledDevicesStream(
          timeout: const Duration(seconds: 5),
        )) {
          final ip = device['ip'] ?? '';
          if (ip.isEmpty) continue;

          final mac = await getMacAddress(ip);
          if (mac != null && normalizeMac(mac) == normalizeMac(macAddress)) {
            print('MDNS found matching device at $ip');
            return ip;
          }
        }
      } catch (e) {
        print('MDNS discovery failed: $e');
      }
    }

    // Fallback to network scanning on Windows or if MDNS fails
    print('Using network scanning fallback...');
    return await _discoverDeviceByNetworkScanning(macAddress);
  }

  /// Network scanning fallback for Windows or when MDNS fails
  Future<String?> _discoverDeviceByNetworkScanning(String macAddress) async {
    final Set<String> checkedIps = <String>{};

    // Common local network ranges to scan
    final networkRanges = [
      '192.168.1',
      '192.168.0',
      '192.168.50',
      '10.0.0',
      '10.0.1',
      '172.16.0',
      '172.16.1',
    ];

    // Try common WLED ports and endpoints
    final endpoints = ['/json', '/json/info'];

    for (final network in networkRanges) {
      print('Scanning network: $network.0/24');

      // Scan in batches to avoid overwhelming the network
      const batchSize = 20;
      const batchDelay = Duration(milliseconds: 100);

      for (int start = 1; start <= 254; start += batchSize) {
        final end = (start + batchSize - 1).clamp(1, 254);
        final futures = <Future<String?>>[];

        for (int i = start; i <= end; i++) {
          final ip = '$network.$i';
          if (!checkedIps.contains(ip)) {
            checkedIps.add(ip);
            futures.add(_checkDeviceAtIp(ip, macAddress, endpoints));
          }
        }

        final completer = Completer<String?>();
        for (final f in futures) {
          f.then((result) {
            if (result != null && !completer.isCompleted) {
              completer.complete(result);
            }
          });
        }

        try {
          final result = await completer.future.timeout(
            const Duration(seconds: 3),
          );
          if (result != null) {
            print('Found device at IP: $result');
            return result;
          }
        } catch (e) {
          print('Timeout scanning batch $start-$end in network $network: $e');
        }

        // Small delay between batches to avoid overwhelming the network
        if (end < 254) {
          await Future.delayed(batchDelay);
        }
      }
    }

    print('Device not found via network scanning - manual IP entry required');
    return null;
  }

  /// Check if a device with the given MAC address is at the specified IP
  Future<String?> _checkDeviceAtIp(
    String ip,
    String targetMac,
    List<String> endpoints,
  ) async {
    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse('http://$ip$endpoint');
        final response = await http
            .get(url)
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);

          // Check if this is a WLED device
          if (json['info']?['mac'] != null) {
            String deviceMac = json['info']['mac'];
            deviceMac = deviceMac
                .replaceAll(':', '')
                .replaceAll('-', '')
                .toLowerCase();

            if (deviceMac == targetMac.toLowerCase()) {
              print('Found matching device at $ip');
              return ip;
            }
          }
        }
      } catch (e) {
        // Ignore errors and continue to next endpoint/IP
        continue;
      }
    }
    return null;
  }

  /// Get device info from IP address (with fallback to discovery)
  Future<Map<String, dynamic>?> getDeviceInfo(Device device) async {
    String? ipAddress = device.ipAddress;

    // If no IP address stored, try to discover it
    if (ipAddress.isEmpty) {
      print(
        'No IP address stored for device ${device.name}, attempting discovery...',
      );
      ipAddress = await discoverDeviceIp(device.mqttClientId);

      if (ipAddress == null) {
        print('Could not discover IP address for device ${device.name}');
        return null;
      }

      print('Discovered IP address: $ipAddress for device ${device.name}');
    }

    // Now fetch device info from the IP address
    try {
      final url = 'http://$ipAddress/json/info';
      print('Fetching device info from: $url');

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2);
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 2));
      final response = await request.close().timeout(
        const Duration(seconds: 2),
      );

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

  /// Normalize MAC address format
  String normalizeMac(String s) =>
      s.replaceAll(':', '').replaceAll('-', '').toLowerCase();

  /// Check if device exists in WordPress by MAC address
  Future<bool> isDeviceInWordPress(String mac, String? jwt) async {
    if (jwt == null) return false;

    // Try up to 3 times with shorter delays
    for (int i = 0; i < 3; i++) {
      try {
        final devices = await _wpApiService.getDevices(jwt);
        print('Checking for MAC: $mac (attempt ${i + 1})');

        // Check if device exists
        if (devices.any(
          (d) => normalizeMac(d.mqttClientId) == normalizeMac(mac),
        )) {
          print('Found device in WordPress!');
          return true;
        }

        // If we get here, device wasn't found, but request was successful
        // No need to retry unless there was an error
        print('Device not found in WordPress.');
        return false;
      } catch (e) {
        print('Error checking WordPress devices (attempt ${i + 1}): $e');
        // Only delay if we're going to retry
        if (i < 2) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    print('Device not found in WordPress after retries.');
    return false;
  }

  /// Check if device exists in WordPress with specific MQTT settings
  Future<bool> isDeviceInWordPressWithSettings(
    String mac,
    String username,
    String password,
    String? jwt,
  ) async {
    if (jwt == null) return false;

    // Try up to 3 times with shorter delays
    for (int i = 0; i < 3; i++) {
      try {
        final devices = await _wpApiService.getDevices(jwt);
        print('Checking for MAC: $mac with settings (attempt ${i + 1})');

        // Check if device exists with correct settings
        if (devices.any(
          (d) =>
              normalizeMac(d.mqttClientId) == normalizeMac(mac) &&
              d.mqttUsername == username &&
              d.mqttPassword == password,
        )) {
          print('Found device in WordPress with correct settings!');
          return true;
        }

        // If we get here, device wasn't found with correct settings, but request was successful
        // No need to retry unless there was an error
        print('Device not found in WordPress with correct settings.');
        return false;
      } catch (e) {
        print('Error checking WordPress devices (attempt ${i + 1}): $e');
        // Only delay if we're going to retry
        if (i < 2) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    print('Device not found in WordPress after retries.');
    return false;
  }

  /// Confirm MQTT settings after device restart
  Future<bool> confirmMqttSettingsAfterRestart({
    required String ip,
    required String broker,
    required String clientId,
    required String username,
    required String password,
  }) async {
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final url = Uri.parse('http://$ip/json/cfg');
        final response = await http
            .get(url)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) continue;
        final cfg = jsonDecode(response.body);
        final mqtt = cfg['if']?['mqtt'];
        if (mqtt == null) continue;
        final topics = mqtt['topics'];
        if (mqtt['en'] == true &&
            mqtt['broker'] == broker &&
            mqtt['cid'] == clientId &&
            mqtt['user'] == username &&
            mqtt['psk'] == password &&
            topics != null &&
            topics['device'] == 'wled/$clientId' &&
            topics['group'] == 'wled/all') {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Create a new device with generated credentials
  Device createDevice({
    required String mac,
    required String name,
    required String ip,
    List<String> allowedUsers = const [],
  }) {
    final username = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final password = 'pass_${DateTime.now().millisecondsSinceEpoch}';

    return Device(
      id: mac,
      name: name,
      ipAddress: ip,
      mqttClientId: mac,
      mqttUsername: username,
      mqttPassword: password,
      allowedUsers: allowedUsers,
      isOnline: true, // Device is online when discovered
    );
  }
}
