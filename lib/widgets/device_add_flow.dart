import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../blocs/auth_bloc.dart';
import '../models/device.dart';
import '../services/add_device_service.dart';
import '../services/wled_api.dart';
import '../widgets/loading_overlay.dart';

class DeviceAddFlow {
  final DeviceDiscoveryService _discoveryService = DeviceDiscoveryService();
  final WledApi _wledApi = WledApi();
  final LoadingOverlay _loadingOverlay = LoadingOverlay();

  /// Handle manual device addition
  Future<void> onManualAdd(
    BuildContext context,
    String ip,
    String name,
    String? jwt,
    Function(Device, String?) addDevice,
  ) async {
    print('🚀 DEVICE ADD: Starting manual device addition for $ip');
    try {
      _loadingOverlay.showOrUpdate(context, 'Validating WLED device…');

      // First check if this is a WLED device
      final response = await http
          .get(Uri.parse('http://$ip/json'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        throw Exception('Could not connect to device at $ip');
      }
      final deviceData = jsonDecode(response.body);
      if (deviceData['info']?['name'] != 'WLED') {
        throw Exception('Device is not a WLED device');
      }

      final mac = await _discoveryService.getMacAddress(ip);
      if (mac == null) {
        throw Exception('Could not fetch MAC address from device');
      }
      await Future.delayed(const Duration(seconds: 2));

      // Check if MAC is already in WordPress
      _loadingOverlay.showOrUpdate(context, 'Checking for existing device…');
      if (await _discoveryService.isDeviceInWordPress(mac, jwt)) {
        _loadingOverlay.close();
        if (context.mounted) {
          Navigator.of(context).pop(); // Close modal
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Device is already registered. Ask the owner to share access or contact us for help.',
              ),
            ),
          );
        }
        return;
      }

      // Get user email from AuthBloc
      String? userEmail;
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        userEmail = authState.user.email;
      }

      // Create device
      final device = _discoveryService.createDevice(
        mac: mac,
        name: name,
        ip: ip,
        allowedUsers: userEmail != null ? [userEmail] : [],
      );

      // Configure WLED device
      _loadingOverlay.showOrUpdate(context, 'Configuring WLED device…');
      await Future.delayed(const Duration(seconds: 2));
      print('🔧 DEVICE ADD: Setting MQTT settings for $ip');
      await _wledApi.setMqttSettings(
        ip: ip,
        broker: 'staylit.lighting',
        clientId: device.mqttClientId,
        username: device.mqttUsername,
        password: device.mqttPassword,
      );
      print('🔧 DEVICE ADD: MQTT settings configured successfully');

      // Restart device
      _loadingOverlay.showOrUpdate(context, 'Restarting WLED device…');
      await Future.delayed(const Duration(seconds: 2));
      print('🔧 DEVICE ADD: Restarting WLED device at $ip');
      await _wledApi.restartDevice(ip);
      print('🔧 DEVICE ADD: Device restart command sent');
      await Future.delayed(const Duration(seconds: 10));
      print('🔧 DEVICE ADD: Waiting for device to come back online');

      // Verify MQTT settings
      _loadingOverlay.showOrUpdate(context, 'Verifying MQTT settings…');
      await Future.delayed(const Duration(seconds: 2));
      print('🔧 DEVICE ADD: Verifying MQTT settings after restart');

      // Check if widget is still mounted before verification
      if (!context.mounted) {
        print('❌ DEVICE ADD: Widget disposed, aborting verification');
        return;
      }

      final ok = await _discoveryService.confirmMqttSettingsAfterRestart(
        ip: ip,
        broker: 'staylit.lighting',
        clientId: device.mqttClientId,
        username: device.mqttUsername,
        password: device.mqttPassword,
      );
      print('🔧 DEVICE ADD: MQTT verification result: $ok');
      if (!ok) {
        throw Exception(
          'MQTT settings not confirmed on WLED device after restart',
        );
      }

      // Add device to WordPress
      _loadingOverlay.showOrUpdate(context, 'Adding device to WordPress…');
      await Future.delayed(const Duration(seconds: 2));
      print('🔧 DEVICE ADD: Adding device to WordPress');
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Small delay before callback

      // Check if widget is still mounted before calling callback
      if (context.mounted) {
        addDevice(device, jwt);
        print('🔧 DEVICE ADD: Device addition initiated');

        // Wait for the BLoC to complete the WordPress API call
        await Future.delayed(const Duration(seconds: 3));
        print('🔧 DEVICE ADD: Waiting for WordPress API call to complete');
      } else {
        print('❌ DEVICE ADD: Widget disposed, skipping WordPress addition');
        _loadingOverlay.close();
        return;
      }

      // Verify device was added
      if (!context.mounted) {
        print('❌ DEVICE ADD: Widget disposed, aborting final verification');
        _loadingOverlay.close();
        return;
      }

      _loadingOverlay.showOrUpdate(context, 'Verifying device registration…');
      await Future.delayed(const Duration(seconds: 2));

      if (!context.mounted) {
        print('❌ DEVICE ADD: Widget disposed, aborting final verification');
        _loadingOverlay.close();
        return;
      }

      final added = await _discoveryService.isDeviceInWordPressWithSettings(
        mac,
        device.mqttUsername,
        device.mqttPassword,
        jwt,
      );

      // Always close the loading overlay regardless of verification result
      _loadingOverlay.close();

      if (added) {
        print('✅ DEVICE ADD: Device successfully added to WordPress');
        if (context.mounted) {
          Navigator.of(context).pop(); // Close modal
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Device "$name" added!')));
        }
      } else {
        print('❌ DEVICE ADD: Device was not added to WordPress');
        if (context.mounted) {
          Navigator.of(context).pop(); // Close modal
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Device was not added to WordPress.')),
          );
        }
      }
    } catch (e) {
      print('❌ DEVICE ADD ERROR: $e');
      _loadingOverlay.close();
      if (context.mounted) {
        Navigator.of(context).pop(); // Close modal
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to configure WLED: $e')));
      }
    }
  }

  /// Handle device tap from discovery
  Future<void> onDeviceTap(
    BuildContext context,
    Map<String, String> deviceMap,
    String? jwt,
    Function(Device, String?) addDevice,
  ) async {
    final ip = deviceMap['ip'] ?? '';
    final name = deviceMap['name'] ?? 'WLED Device';

    try {
      _loadingOverlay.showOrUpdate(context, 'Fetching device MAC address…');
      final mac = await _discoveryService.getMacAddress(ip);
      if (mac == null) {
        throw Exception('Could not fetch MAC address from device');
      }
      await Future.delayed(const Duration(seconds: 2));

      _loadingOverlay.showOrUpdate(context, 'Checking for existing device…');
      if (await _discoveryService.isDeviceInWordPress(mac, jwt)) {
        _loadingOverlay.close();
        if (context.mounted) {
          Navigator.of(context).pop(); // Close modal
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Device is already registered. Ask the owner to share access or contact us for help.',
              ),
            ),
          );
        }
        return;
      }

      // Get user email from AuthBloc
      String? userEmail;
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        userEmail = authState.user.email;
      }

      // Create device
      final device = _discoveryService.createDevice(
        mac: mac,
        name: name,
        ip: ip,
        allowedUsers: userEmail != null ? [userEmail] : [],
      );

      // Configure WLED device
      _loadingOverlay.showOrUpdate(context, 'Configuring WLED device…');
      await Future.delayed(const Duration(seconds: 2));
      print('🔧 DEVICE ADD: Setting MQTT settings for $ip');
      await _wledApi.setMqttSettings(
        ip: ip,
        broker: 'staylit.lighting',
        clientId: device.mqttClientId,
        username: device.mqttUsername,
        password: device.mqttPassword,
      );
      print('🔧 DEVICE ADD: MQTT settings configured successfully');

      // Restart device
      _loadingOverlay.showOrUpdate(context, 'Restarting WLED device…');
      await Future.delayed(const Duration(seconds: 2));
      print('🔧 DEVICE ADD: Restarting WLED device at $ip');
      await _wledApi.restartDevice(ip);
      print('🔧 DEVICE ADD: Device restart command sent');
      await Future.delayed(const Duration(seconds: 10));
      print('🔧 DEVICE ADD: Waiting for device to come back online');

      // Verify MQTT settings
      _loadingOverlay.showOrUpdate(context, 'Verifying MQTT settings…');
      await Future.delayed(const Duration(seconds: 2));
      print('🔧 DEVICE ADD: Verifying MQTT settings after restart');

      // Check if widget is still mounted before verification
      if (!context.mounted) {
        print('❌ DEVICE ADD: Widget disposed, aborting verification');
        return;
      }

      final ok = await _discoveryService.confirmMqttSettingsAfterRestart(
        ip: ip,
        broker: 'staylit.lighting',
        clientId: device.mqttClientId,
        username: device.mqttUsername,
        password: device.mqttPassword,
      );
      print('🔧 DEVICE ADD: MQTT verification result: $ok');
      if (!ok) {
        throw Exception(
          'MQTT settings not confirmed on WLED device after restart',
        );
      }

      // Add device to WordPress
      _loadingOverlay.showOrUpdate(context, 'Adding device to WordPress…');
      await Future.delayed(const Duration(seconds: 2));
      print('🔧 DEVICE ADD: Adding device to WordPress');
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Small delay before callback

      // Check if widget is still mounted before calling callback
      if (context.mounted) {
        addDevice(device, jwt);
        print('🔧 DEVICE ADD: Device addition initiated');

        // Wait for the BLoC to complete the WordPress API call
        await Future.delayed(const Duration(seconds: 3));
        print('🔧 DEVICE ADD: Waiting for WordPress API call to complete');

        // Close loading overlay and modal
        _loadingOverlay.close();
        Navigator.of(context).pop(); // Close modal
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Device "$name" added!')));
      } else {
        print('❌ DEVICE ADD: Widget disposed, skipping WordPress addition');
        _loadingOverlay.close();
        return;
      }
    } catch (e) {
      print('❌ DEVICE ADD ERROR: $e');
      _loadingOverlay.close();
      if (context.mounted) {
        Navigator.of(context).pop(); // Close modal
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to configure WLED: $e')));
      }
    }
  }

  /// Dispose of resources
  void dispose() {
    _loadingOverlay.dispose();
  }
}
