import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/preset.dart';
import '../data/presets_database.dart' as PresetDB;
import '../services/wp_preset_service.dart';
import '../widgets/preset_card.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_bloc.dart';
import '../blocs/device_bloc.dart';
import '../services/mqtt_service.dart';
import '../services/storage_service.dart';
import '../services/wled_api.dart';
import '../services/mdns_service.dart';
import 'package:http/http.dart' as http;

class TimersScreen extends StatefulWidget {
  final Device device;

  const TimersScreen({super.key, required this.device});

  @override
  State<TimersScreen> createState() => _TimersScreenState();
}

class _TimersScreenState extends State<TimersScreen> {
  List<Map<String, dynamic>> timers = [];
  List<Map<String, dynamic>> internalTimers = [];
  List<Preset> allPresets = [];
  bool _isDeviceOnline = false;
  bool _isCheckingConnection = true;
  String? _deviceIpAddress;
  final StorageService _storageService = StorageService();
  final WledApi _wledApi = WledApi();
  final WPPresetService _wpPresetService = WPPresetService();
  String? _deviceTime;
  String? _selectedTimezone;
  // Map<String, int> _presetNameToId = {}; // no longer used; single-slot updates only

  bool get hasSunsetTimer => timers.any((t) => t['turnOnAtSunset'] == true);

  int get normalTimerCount => timers
      .where((t) => t['turnOnAtSunset'] != true && t['turnOnAtSunrise'] != true)
      .length;
  int get sunsetTimerCount =>
      timers.where((t) => t['turnOnAtSunset'] == true).length;
  int get sunriseTimerCount =>
      timers.where((t) => t['turnOnAtSunrise'] == true).length;

  bool get canAddNormalTimer => normalTimerCount < 8;
  bool get canAddSunsetTimer => sunsetTimerCount < 1;
  bool get canAddSunriseTimer => sunriseTimerCount < 1;
  bool get canAddAnyTimer =>
      timers.length < 8 &&
      (canAddNormalTimer || canAddSunsetTimer || canAddSunriseTimer);

  @override
  void initState() {
    super.initState();
    _checkDeviceConnection();
    _fetchTimersFromWordPress();
    _loadPresets();

    // Clear any existing timers to ensure we start fresh for this device
    print(
      'Initializing timers for device: ${widget.device.name} (${widget.device.mqttClientId})',
    );
    timers.clear();
    internalTimers.clear();
  }

  Future<void> _loadPresets() async {
    setState(() {});

    try {
      // Get JWT token from auth state
      String? jwt;
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        jwt = authState.user.jwtToken;
      }

      // Load presets from WordPress (or fallback to local if not authenticated)
      List<Preset> presets;
      if (jwt != null) {
        print('Loading presets from WordPress...');
        presets = await _wpPresetService.getPresets(jwt: jwt);
        print('Loaded ${presets.length} presets from WordPress');

        // Sort presets: personal presets first, then others (same as device screen)
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          final userEmail = authState.user.email;
          presets.sort((a, b) {
            // Personal presets are those created by the current user or private status
            // Handle null values for local presets that don't have these fields
            final aIsPersonal =
                (a.createdBy != null && a.createdBy == userEmail) ||
                (a.status != null && a.status == 'private');
            final bIsPersonal =
                (b.createdBy != null && b.createdBy == userEmail) ||
                (b.status != null && b.status == 'private');

            if (aIsPersonal && !bIsPersonal) return -1;
            if (!aIsPersonal && bIsPersonal) return 1;

            // Within each group, sort by name
            return a.name.compareTo(b.name);
          });
        }
      } else {
        print('Not authenticated, falling back to local presets...');
        presets = PresetDB.PresetDatabase.presets
            .map(
              (p) => Preset(
                name: p.name,
                description: p.description,
                icon: p.icon,
                categories: p.categories,
                fx: p.fx,
                sx: p.sx,
                ix: p.ix,
                paletteId: p.paletteId,
                colors: p.colors,
              ),
            )
            .toList();
      }

      setState(() {
        allPresets = presets;
      });
    } catch (e) {
      print('Error loading presets: $e');
      // Fallback to local presets on error
      setState(() {
        final fallbackPresets = PresetDB.PresetDatabase.presets
            .map(
              (p) => Preset(
                name: p.name,
                description: p.description,
                icon: p.icon,
                categories: p.categories,
                fx: p.fx,
                sx: p.sx,
                ix: p.ix,
                paletteId: p.paletteId,
                colors: p.colors,
              ),
            )
            .toList();

        allPresets = fallbackPresets;
      });
    }
  }

  Future<void> _checkDeviceConnection() async {
    setState(() {
      _isCheckingConnection = true;
    });

    try {
      // First try to get IP from DeviceBloc (most up-to-date)
      String? ipAddress;
      final deviceState = context.read<DeviceBloc>().state;
      if (deviceState is DeviceLoaded) {
        final currentDevice = deviceState.devices.firstWhere(
          (d) => d.id == widget.device.id,
          orElse: () => widget.device,
        );
        ipAddress = currentDevice.ipAddress;
      }

      // Fallback to local storage if DeviceBloc doesn't have a valid IP
      if (ipAddress == null || ipAddress.isEmpty) {
        ipAddress = await _storageService.loadDeviceIpAddress(widget.device.id);
      }

      // Final fallback to original device.ipAddress
      if (ipAddress == null || ipAddress.isEmpty) {
        ipAddress = widget.device.ipAddress;
      }

      if (ipAddress.isNotEmpty) {
        // Test connection to device
        final isOnline = await _testDeviceConnection(ipAddress);
        if (isOnline) {
          if (mounted) {
            setState(() {
              _isDeviceOnline = true;
              _deviceIpAddress = ipAddress;
              _isCheckingConnection = false;
            });
          }
          return;
        }
        // Connection failed, try discovery to find the correct IP
        print('Connection failed for IP $ipAddress, attempting discovery...');
      } else {
        // If no IP address available, try discovery
        print(
          'No IP address available for device ${widget.device.name}, attempting discovery...',
        );
      }

      String? discoveredIp;
      try {
        final MdnsService mdns = MdnsService();
        await for (final device in mdns.discoverWledDevicesStream(
          timeout: const Duration(seconds: 10),
        )) {
          final ip = device['ip'] ?? '';
          if (ip.isEmpty) continue;

          // MDNS doesn't provide MAC, so we need to fetch it by querying the device
          try {
            final response = await http
                .get(Uri.parse('http://$ip/json'))
                .timeout(const Duration(seconds: 3));

            if (response.statusCode == 200) {
              final deviceInfo =
                  jsonDecode(response.body) as Map<String, dynamic>;
              final deviceMac = deviceInfo['info']?['mac'] as String?;

              if (deviceMac != null &&
                  deviceMac == widget.device.mqttClientId) {
                discoveredIp = ip;
                print(
                  'Found matching device at IP: $discoveredIp (MAC: $deviceMac)',
                );
                break;
              }
            }
          } catch (e) {
            print('Failed to validate device at $ip: $e');
            continue;
          }
        }
      } catch (e) {
        print('Device discovery failed: $e');
      }

      if (discoveredIp != null) {
        final isOnline = await _testDeviceConnection(discoveredIp);
        if (isOnline) {
          await _storageService.saveDeviceIpAddress(
            widget.device.id,
            discoveredIp,
          );
          // Update DeviceBloc with the discovered IP
          final updatedDevice = widget.device.copyWith(ipAddress: discoveredIp);
          context.read<DeviceBloc>().add(UpdateDevice(updatedDevice));
          if (mounted) {
            setState(() {
              _isDeviceOnline = true;
              _deviceIpAddress = discoveredIp;
              _isCheckingConnection = false;
            });
          }
          return;
        }
      }

      // If discovery failed, mark as offline
      if (mounted) {
        setState(() {
          _isDeviceOnline = false;
          _deviceIpAddress = null;
          _isCheckingConnection = false;
          _deviceTime = null;
        });
      }
    } catch (e) {
      print('Error checking device connection: $e');
      if (mounted) {
        setState(() {
          _isDeviceOnline = false;
          _deviceIpAddress = null;
          _isCheckingConnection = false;
          _deviceTime = null;
        });
      }
    }
  }

  Future<bool> _testDeviceConnection(String ipAddress) async {
    try {
      final url = Uri.parse('http://$ipAddress/json/info');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        // Parse device info and extract time
        try {
          final deviceInfo = jsonDecode(response.body) as Map<String, dynamic>;
          final deviceTime = _formatTimeOnly(deviceInfo['time']);
          if (mounted) {
            setState(() {
              _deviceTime = deviceTime;
            });
          }
        } catch (e) {
          print('Error parsing device info: $e');
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Device connection test failed: $e');
      if (mounted) {
        setState(() {
          _deviceTime = null;
        });
      }
      return false;
    }
  }

  // Removed unused _updateDeviceTime

  String _formatTimeOnly(dynamic time) {
    if (time == null) return 'Unknown';

    final timeStr = time.toString();

    try {
      // Try to parse various time formats
      DateTime? dateTime;

      // Common format: "2024-01-15 14:30:25" or similar
      if (timeStr.contains(' ')) {
        final parts = timeStr.split(' ');
        if (parts.length >= 2) {
          final timePart = parts[1];
          final timeComponents = timePart.split(':');
          if (timeComponents.length >= 2) {
            final hour = int.tryParse(timeComponents[0]) ?? 0;
            final minute = int.tryParse(timeComponents[1]) ?? 0;
            dateTime = DateTime(2024, 1, 1, hour, minute);
          }
        }
      }

      // If parsing failed, try direct time format "14:30:25"
      if (dateTime == null && timeStr.contains(':')) {
        final timeComponents = timeStr.split(':');
        if (timeComponents.length >= 2) {
          final hour = int.tryParse(timeComponents[0]) ?? 0;
          final minute = int.tryParse(timeComponents[1]) ?? 0;
          dateTime = DateTime(2024, 1, 1, hour, minute);
        }
      }

      if (dateTime != null) {
        // Convert to 12-hour format
        int hour = dateTime.hour;
        final minute = dateTime.minute;
        final isAM = hour < 12;

        if (hour == 0) {
          hour = 12;
        } else if (hour > 12)
          hour -= 12;

        final minuteStr = minute.toString().padLeft(2, '0');
        final period = isAM ? 'AM' : 'PM';

        return '$hour:$minuteStr $period';
      }
    } catch (e) {
      print('Error formatting time: $e');
    }

    return timeStr;
  }

  void _showTimezoneDialog() {
    if (!_isDeviceOnline || _deviceIpAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device must be online to change timezone'),
        ),
      );
      return;
    }

    // Initialize with Mountain Time (first in list)
    _selectedTimezone = _getTimezones().first['name'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF2D3436),
          title: Row(
            children: [
              const Text('Time Setup', style: TextStyle(color: Colors.white)),
              const Spacer(),
              if (_deviceTime != null)
                Text(
                  _deviceTime!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select timezone:',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTimezone,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    items: _getTimezones().map((timezone) {
                      return DropdownMenuItem<String>(
                        value: timezone['name'],
                        child: Text(
                          timezone['name']!,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedTimezone = newValue;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: _selectedTimezone != null
                  ? () {
                      final timezone = _getTimezones().firstWhere(
                        (tz) => tz['name'] == _selectedTimezone,
                      );
                      _setTimezone(timezone['offset']!, timezone['name']!);
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Apply', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _getTimezones() {
    return [
      {'name': 'Mountain Time (MT) UTC-7', 'offset': '-7', 'tz': '15'},
      {'name': 'Pacific Time (PT) UTC-8', 'offset': '-8', 'tz': '16'},
      {'name': 'Central Time (CT) UTC-6', 'offset': '-6', 'tz': '14'},
      {'name': 'Eastern Time (ET) UTC-5', 'offset': '-5', 'tz': '13'},
      {'name': 'Alaska Time (AKT) UTC-9', 'offset': '-9', 'tz': '17'},
      {'name': 'Hawaii Time (HST) UTC-10', 'offset': '-10', 'tz': '18'},
      {'name': 'Atlantic Time (AT) UTC-4', 'offset': '-4', 'tz': '12'},
      {'name': 'Newfoundland Time (NT) UTC-3:30', 'offset': '-3.5', 'tz': '11'},
    ];
  }

  Future<void> _setTimezone(String offset, String timezoneName) async {
    try {
      Navigator.pop(context); // Close dialog

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Setting timezone to $timezoneName...'),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      // Get the timezone data for the selected timezone
      final timezoneData = _getTimezones().firstWhere(
        (tz) => tz['name'] == timezoneName,
      );
      final tzValue = int.parse(timezoneData['tz']!);

      // Get current config to preserve other settings
      final currentConfig = await _wledApi.getConfig(_deviceIpAddress!);

      // Ensure if section exists
      if (currentConfig['if'] == null) {
        currentConfig['if'] = {};
      }

      // Ensure ntp section exists
      if (currentConfig['if']['ntp'] == null) {
        currentConfig['if']['ntp'] = {};
      }

      // Update only the NTP settings we need to change
      currentConfig['if']['ntp']['en'] = true;
      currentConfig['if']['ntp']['host'] = '0.wled.pool.ntp.org';
      currentConfig['if']['ntp']['tz'] = tzValue;

      // Send the updated config
      await _wledApi.updateConfig(_deviceIpAddress!, currentConfig);

      // Refresh device time after setting timezone
      await Future.delayed(const Duration(seconds: 2));
      await _checkDeviceConnection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Timezone set to $timezoneName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set timezone: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchTimersFromWordPress() async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) {
        print('User not authenticated, skipping WordPress timer fetch');
        return;
      }

      // First get all devices and find the specific one by mqtt_client_id
      final url = 'https://staylit.lighting/wp-json/wp/v2/wled_device';
      print(
        'Fetching timers for device: ${widget.device.name} (${widget.device.mqttClientId})',
      );
      final request = await HttpClient().getUrl(Uri.parse(url));

      request.headers.set('Authorization', 'Bearer ${authState.user.jwtToken}');

      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final List<dynamic> allDevices = jsonDecode(responseBody);

        print('Found ${allDevices.length} total devices');

        // Find the specific device by mqtt_client_id
        final targetDevice = allDevices.firstWhere(
          (device) =>
              device['meta']?['mqtt_client_id'] == widget.device.mqttClientId,
          orElse: () => null,
        );

        if (targetDevice != null) {
          print(
            'Found target device: ${targetDevice['title']} (ID: ${targetDevice['id']})',
          );

          if (targetDevice['meta']?['timers_json'] != null) {
            final timersJson = targetDevice['meta']['timers_json'];
            if (timersJson != null && timersJson.toString().trim().isNotEmpty) {
              final List<dynamic> fetchedTimers = jsonDecode(timersJson);

              setState(() {
                timers = fetchedTimers.cast<Map<String, dynamic>>();
                // Ensure each timer has a stable presetId (1-8) that sticks with the timer
                final usedIds = <int>{};
                for (final t in timers) {
                  final id = t['presetId'];
                  if (id is int && id >= 1 && id <= 8) usedIds.add(id);
                }
                int nextId = 1;
                for (final t in timers) {
                  if (t['presetId'] is! int ||
                      t['presetId'] < 1 ||
                      t['presetId'] > 8) {
                    while ((usedIds.contains(nextId) ||
                            nextId == 7 ||
                            nextId == 8) &&
                        nextId <= 8) {
                      nextId++;
                    }
                    if (nextId <= 8) {
                      t['presetId'] = nextId;
                      usedIds.add(nextId);
                      nextId++;
                    } else {
                      // Fallback if more than 8: reuse 8
                      t['presetId'] = 8;
                    }
                  }
                }
                // Enforce reserved slots: sunrise -> 7, sunset -> 8
                for (final t in timers) {
                  if (t['turnOnAtSunrise'] == true) {
                    t['presetId'] = 7;
                  } else if (t['turnOnAtSunset'] == true) {
                    t['presetId'] = 8;
                  }
                }
                // Ensure no normal timer occupies 7 or 8
                final occupied = <int>{
                  for (final t in timers)
                    if (t['presetId'] is int) t['presetId'] as int,
                };
                int reassignId = 1;
                for (final t in timers) {
                  final isSunrise = t['turnOnAtSunrise'] == true;
                  final isSunset = t['turnOnAtSunset'] == true;
                  if (!isSunrise &&
                      !isSunset &&
                      (t['presetId'] == 7 || t['presetId'] == 8)) {
                    while ((occupied.contains(reassignId) ||
                            reassignId == 7 ||
                            reassignId == 8) &&
                        reassignId <= 8) {
                      reassignId++;
                    }
                    if (reassignId <= 8) {
                      occupied.remove(t['presetId']);
                      t['presetId'] = reassignId;
                      occupied.add(reassignId);
                      reassignId++;
                    }
                  }
                }
                // Rebuild internal timers
                internalTimers.clear();
                for (final timer in timers) {
                  internalTimers.add({
                    ...timer,
                    'type': 'on',
                    'preset': timer['presetName'],
                  });
                }
              });

              print(
                'Loaded ${timers.length} timers from WordPress for ${widget.device.name}',
              );
            } else {
              print('Empty timers_json for device ${widget.device.name}');
              setState(() {
                timers = [];
                internalTimers.clear();
              });
            }
          } else {
            print('No timers found for device ${widget.device.name}');
            setState(() {
              timers = [];
              internalTimers.clear();
            });
          }
        } else {
          print('Device not found in WordPress: ${widget.device.mqttClientId}');
          setState(() {
            timers = [];
            internalTimers.clear();
          });
        }
      } else {
        print('Failed to fetch devices: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching timers from WordPress: $e');
    }
  }

  Future<void> _saveTimersToWordPress() async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) {
        print('User not authenticated, skipping WordPress timer save');
        return;
      }

      // First, get all devices and find the specific one by mqtt_client_id
      final getUrl = 'https://staylit.lighting/wp-json/wp/v2/wled_device';
      print(
        'Saving timers for device: ${widget.device.name} (${widget.device.mqttClientId})',
      );
      final getRequest = await HttpClient().getUrl(Uri.parse(getUrl));

      getRequest.headers.set(
        'Authorization',
        'Bearer ${authState.user.jwtToken}',
      );

      final getResponse = await getRequest.close();

      if (getResponse.statusCode == 200) {
        final responseBody = await getResponse.transform(utf8.decoder).join();
        final List<dynamic> allDevices = jsonDecode(responseBody);

        print('Found ${allDevices.length} total devices');

        // Find the specific device by mqtt_client_id
        final targetDevice = allDevices.firstWhere(
          (device) =>
              device['meta']?['mqtt_client_id'] == widget.device.mqttClientId,
          orElse: () => null,
        );

        if (targetDevice != null) {
          final deviceId = targetDevice['id'];
          final timersJson = jsonEncode(timers);

          print('Saving ${timers.length} timers to device ID: $deviceId');

          // Update the device with new timers
          final putUrl =
              'https://staylit.lighting/wp-json/wp/v2/wled_device/$deviceId';
          final putRequest = await HttpClient().putUrl(Uri.parse(putUrl));
          putRequest.headers.set('Content-Type', 'application/json');

          putRequest.headers.set(
            'Authorization',
            'Bearer ${authState.user.jwtToken}',
          );

          final body = jsonEncode({
            'meta': {'timers_json': timersJson},
          });

          putRequest.add(utf8.encode(body));
          final putResponse = await putRequest.close();

          if (putResponse.statusCode == 200) {
            print('Timers saved to WordPress for ${widget.device.name}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Timers saved for ${widget.device.name}'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            print('Failed to save timers: HTTP ${putResponse.statusCode}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to save timers'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          print('Device not found in WordPress: ${widget.device.mqttClientId}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device not found in WordPress'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print('Failed to fetch devices: HTTP ${getResponse.statusCode}');
      }
    } catch (e) {
      print('Error saving timers to WordPress: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving timers: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _setTimerToWLED() async {
    if (_deviceIpAddress == null) {
      print('No device IP address available');
      return false;
    }

    try {
      print('Setting timers to WLED device: ${widget.device.name}');

      // Then, set timers via HTTP cfg - single action timers only
      final timerConfigs = <Map<String, dynamic>>[];

      // Separate timers by type and assign specific slots
      final normalTimers = timers
          .where(
            (t) => t['turnOnAtSunset'] != true && t['turnOnAtSunrise'] != true,
          )
          .toList();
      final sunriseTimers = timers
          .where((t) => t['turnOnAtSunrise'] == true)
          .toList();
      final sunsetTimers = timers
          .where((t) => t['turnOnAtSunset'] == true)
          .toList();

      // Add normal timers including OFF timers (slots 0-7)
      for (int i = 0; i < normalTimers.length && i < 8; i++) {
        final timer = normalTimers[i];
        final onTime = timer['onTime'].toString();
        final presetId = (timer['presetId'] as int?) ?? 1;
        final timerSettings = _buildTimerSettings(onTime, timer, presetId);

        timerConfigs.add({
          'timer': timerSettings,
          'slot': i, // Slots 0-7 for normal timers (including OFF)
        });
      }

      // Add sunrise timer (slot 8)
      for (int i = 0; i < sunriseTimers.length && i < 1; i++) {
        final timer = sunriseTimers[i];
        final onTime = timer['onTime'].toString();
        final presetId = (timer['presetId'] as int?) ?? 1;
        final timerSettings = _buildTimerSettings(onTime, timer, presetId);

        timerConfigs.add({
          'timer': timerSettings,
          'slot': 8, // Slot 8 for sunrise timer
        });
      }

      // Add sunset timer (slot 9)
      for (int i = 0; i < sunsetTimers.length && i < 1; i++) {
        final timer = sunsetTimers[i];
        final onTime = timer['onTime'].toString();
        final presetId = (timer['presetId'] as int?) ?? 1;
        final timerSettings = _buildTimerSettings(onTime, timer, presetId);

        timerConfigs.add({
          'timer': timerSettings,
          'slot': 9, // Slot 9 for sunset timer
        });
      }

      // Set timers via HTTP cfg
      await _wledApi.setTimers(_deviceIpAddress!, timerConfigs);

      print('Timers set to WLED via HTTP cfg for ${widget.device.name}');
      print('Total timers configured: ${timerConfigs.length}');
      for (final config in timerConfigs) {
        print('  Slot ${config['slot']}: ${config['timer']}');
      }
      return true;
    } catch (e) {
      print('Error setting timers to WLED: $e');
      return false;
    }
  }

  Future<void> _deletePresetFromDevice(int presetId) async {
    try {
      final deviceMqttService = DeviceMqttService(widget.device);
      await deviceMqttService.connect();

      // Wait for connection to be established
      int waitCount = 0;
      while (!deviceMqttService.isConnected && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }

      if (!deviceMqttService.isConnected) {
        print('Failed to connect to WLED device ${widget.device.name}');
        return;
      }

      // Write a basic OFF preset: one black segment and trailing stops to clear extras
      final List<Map<String, dynamic>> segArray = [
        {
          'id': 0,
          'start': 0,
          'stop': 1000,
          'grp': 1,
          'spc': 0,
          'of': 0,
          'on': true,
          'frz': false,
          'bri': 255,
          'cct': 127,
          'set': 0,
          'n': '',
          'col': [
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
          ],
          'fx': 0,
          'sx': 128,
          'ix': 128,
          'pal': 0,
          'c1': 128,
          'c2': 128,
          'c3': 16,
          'sel': true,
          'rev': false,
          'mi': false,
          'o1': false,
          'o2': false,
          'o3': false,
          'si': 0,
          'm12': 0,
        },
        ...List.generate(31, (_) => {'stop': 0}),
      ];
      final presetCommand = {
        'psave': presetId,
        'n': 'OFF',
        'ib': true,
        'sb': true,
        'on': false,
        'bri': 0,
        'transition': 7,
        'mainseg': 0,
        'seg': segArray,
      };
      await deviceMqttService.savePresetMqtt(presetId, 'OFF', presetCommand);
      await Future.delayed(const Duration(milliseconds: 100));

      print(
        'Preset $presetId replaced with OFF on device ${widget.device.name}',
      );
    } catch (e) {
      print('Error replacing preset $presetId with OFF: $e');
    }
  }

  Future<void> _recallPreset(int presetId) async {
    try {
      final deviceMqttService = DeviceMqttService(widget.device);
      await deviceMqttService.connect();
      int waitCount = 0;
      while (!deviceMqttService.isConnected && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 10));
        waitCount++;
      }
      if (!deviceMqttService.isConnected) {
        print(
          'Failed to connect to WLED device ${widget.device.name} for recall',
        );
        return;
      }
      deviceMqttService.sendCommand({'ps': presetId});
      await Future.delayed(const Duration(milliseconds: 200));
      print('Recalled preset $presetId on device ${widget.device.name}');
    } catch (e) {
      print('Error recalling preset $presetId: $e');
    }
  }

  Future<void> _savePresetToDevice(Preset preset, int slot) async {
    try {
      final deviceMqttService = DeviceMqttService(widget.device);
      await deviceMqttService.connect();
      int waitCount = 0;
      while (!deviceMqttService.isConnected && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      if (!deviceMqttService.isConnected) {
        print('Failed to connect to WLED device ${widget.device.name}');
        return;
      }

      final presetState = _buildPresetState(preset);
      final presetName = preset.name.replaceAll('&#215;', '×');
      final payload = {
        'psave': slot,
        'n': presetName,
        'ib': true,
        'sb': true,
        ...presetState,
      };
      await deviceMqttService.savePresetMqtt(slot, presetName, payload);
      await Future.delayed(const Duration(milliseconds: 200));
      print(
        'Saved preset "$presetName" to slot $slot for ${widget.device.name}',
      );
    } catch (e) {
      print('Error saving preset to WLED: $e');
    }
  }

  String _normalizePresetName(String? name) {
    if (name == null) return '';
    return name.replaceAll('&#215;', '×').trim().toLowerCase();
  }

  // Unused bulk save removed to avoid device resets
  /* Future<void> _savePresetsToWLED() async {
    try {
      final deviceMqttService = DeviceMqttService(widget.device);
      await deviceMqttService.connect();
      
      // Wait for connection to be established
      int waitCount = 0;
      while (!deviceMqttService.isConnected && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      
      if (!deviceMqttService.isConnected) {
        print('Failed to connect to WLED device ${widget.device.name}');
        return;
      }
      
      // Save presets to fixed slots 1-8 based on each timer's presetId. Unused slots become OFF.
      _presetNameToId.clear();
      bool reloadedPresets = false; // reload once on first miss
      for (int presetSlot = 1; presetSlot <= 8; presetSlot++) {
        // Find a timer that is assigned to this slot
        final timerForSlot = timers.firstWhere(
          (t) => (t['presetId'] as int?) == presetSlot,
          orElse: () => {},
        );

        Map<String, dynamic> presetState;
        String presetDisplayName;
        bool skipSend = false;
        if (timerForSlot.isNotEmpty) {
          final tNameRaw = (timerForSlot['presetName'] as String?) ?? '';
          final tName = tNameRaw.trim();
          if (tName.isEmpty || _normalizePresetName(tName) == 'off') {
            presetState = {
              'on': false,
              'bri': 0,
            };
            presetDisplayName = 'OFF';
            _presetNameToId['OFF'] = presetSlot;
          } else {
            Preset? presetObj;
            try {
              presetObj = allPresets.firstWhere(
                (p) => _normalizePresetName(p.name) == _normalizePresetName(tName),
              );
            } catch (_) {
              presetObj = null;
            }
            if (presetObj == null && !reloadedPresets) {
              // One-time reload to avoid premature OFF fallback
              reloadedPresets = true;
              await _loadPresets();
              try {
                presetObj = allPresets.firstWhere(
                  (p) => _normalizePresetName(p.name) == _normalizePresetName(tName),
                );
              } catch (_) {
                presetObj = null;
              }
            }
            if (presetObj != null) {
              presetState = _buildPresetState(presetObj);
              presetDisplayName = tName;
              _presetNameToId[tName] = presetSlot;
            } else {
              // Skip sending rather than overwriting with OFF; preserve device state
              skipSend = true;
              presetState = const {};
              presetDisplayName = tName;
            }
          }
        } else {
          // No timer for this slot → OFF
          presetState = {
            'on': false,
            'bri': 0,
          };
          presetDisplayName = 'OFF';
          _presetNameToId['OFF'] = presetSlot;
        }

        if (!skipSend) {
          final presetCommand = {
            'psave': presetSlot,
            'n': presetDisplayName,
            'ib': true,
            'sb': true,
            ...presetState,
          };
          await deviceMqttService.savePresetMqtt(presetSlot, presetDisplayName, presetCommand);
          await Future.delayed(const Duration(milliseconds: 200));
        } else {
          print('Skipping preset save for slot $presetSlot to avoid OFF fallback (preset "$presetDisplayName" not found yet).');
        }
      }
      
      print('Presets saved to WLED for ${widget.device.name}');
      
      // Clear any presets that are no longer used by timers
      await _clearUnusedPresets();
    } catch (e) {
      print('Error saving presets to WLED: $e');
    }
  } */

  // Future<void> _clearUnusedPresets() async { /* no-op; removed to avoid mass writes */ }

  Map<String, dynamic> _buildPresetState(Preset preset) {
    // For Custom Pattern presets, mirror DeviceScreen multi-segment layout and clear extra segments with trailing {stop:0}
    if (preset.categories.contains('Custom Pattern') &&
        (preset.colors?.isNotEmpty ?? false)) {
      final colors = preset.colors!;
      final int count = colors.length;
      final int spacing = count > 1 ? count - 1 : 0;

      List<Map<String, dynamic>> activeSegments = List.generate(count, (i) {
        final hex = colors[i].replaceAll('#', '');
        int r = 0, g = 0, b = 0;
        if (hex.length >= 6) {
          try {
            r = int.parse(hex.substring(0, 2), radix: 16);
            g = int.parse(hex.substring(2, 4), radix: 16);
            b = int.parse(hex.substring(4, 6), radix: 16);
          } catch (_) {}
        }
        return {
          'id': i,
          'start': i,
          'stop': 1000,
          'grp': 1,
          'spc': spacing,
          'of': 0,
          'on': true,
          'frz': false,
          'bri': 255,
          'cct': 127,
          'set': 0,
          'n': '',
          'col': [
            [r, g, b, 0],
            [0, 0, 0],
            [0, 0, 0],
          ],
          'fx': preset.fx,
          'sx': 128,
          'ix': 128,
          'pal': 0,
          'c1': 128,
          'c2': 128,
          'c3': 16,
          'sel': i == 0,
          'rev': false,
          'mi': false,
          'o1': false,
          'o2': false,
          'o3': false,
          'si': 0,
          'm12': 0,
        };
      });

      final int emptyCount = count < 32 ? 32 - count : 0;
      final emptySegments = List.generate(emptyCount, (i) => {'stop': 0});

      return {
        'on': true,
        'bri': 150,
        'transition': 7,
        'mainseg': 0,
        'seg': [...activeSegments, ...emptySegments],
      };
    }

    final state = <String, dynamic>{
      'bri': 150,
      'mainseg': 0,
      'on': true,
      'transition': 7,
    };

    // Minimal single-segment configuration + trailing {stop:0} placeholders to clear extras
    final segment = <String, dynamic>{
      'id': 0,
      'spc': 0, // ensure spacing reset for non-custom
      'on': true,
      'fx': preset.fx,
    };

    // Add up to 3 colors, pad to 3
    final colors = <List<int>>[];
    if (preset.colors != null && preset.colors!.isNotEmpty) {
      for (final colorHex in preset.colors!.take(3)) {
        final hex = colorHex.replaceAll('#', '');
        if (hex.length >= 6) {
          final r = int.parse(hex.substring(0, 2), radix: 16);
          final g = int.parse(hex.substring(2, 4), radix: 16);
          final b = int.parse(hex.substring(4, 6), radix: 16);
          colors.add([r, g, b, 0]);
        }
      }
    }
    while (colors.length < 3) {
      colors.add([0, 0, 0, 0]);
    }
    segment['col'] = colors;

    if (preset.paletteId != null) segment['pal'] = preset.paletteId;
    if (preset.sx != null) segment['sx'] = preset.sx;
    if (preset.ix != null) segment['ix'] = preset.ix;
    if (preset.c1 != null) segment['c1'] = preset.c1;
    if (preset.c2 != null) segment['c2'] = preset.c2;
    if (preset.c3 != null) segment['c3'] = preset.c3;
    if (preset.o1 != null) segment['o1'] = preset.o1;
    if (preset.o2 != null) segment['o2'] = preset.o2;
    if (preset.o3 != null) segment['o3'] = preset.o3;

    // Add 31 trailing stops so the last entry is a {stop:0}
    final List<Map<String, dynamic>> trailingStops = List.generate(
      31,
      (i) => {'stop': 0},
    );
    state['seg'] = [segment, ...trailingStops];

    return state;
  }

  Map<String, dynamic> _buildTimerSettings(
    String timeStr,
    Map<String, dynamic> timer,
    int presetId,
  ) {
    // Handle sunrise timer FIRST (to ensure it takes precedence)
    if (timeStr == 'Sunrise' || timer['turnOnAtSunrise'] == true) {
      // Build weekday mask (bit 0 = Sunday, bit 1 = Monday, etc.)
      int weekdayMask = 0;
      final daysText = timer['daysText'] ?? '';
      const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      for (int i = 0; i < dayNames.length; i++) {
        if (daysText.contains(dayNames[i])) {
          weekdayMask |= (1 << i);
        }
      }

      // Return sunrise timer settings
      return {
        'en': 1,
        'hour': 253, // 253 indicates sunrise
        'min': timer['sunriseOffset'] ?? 0, // Offset in minutes
        'dow': weekdayMask,
        'ps': presetId,
      };
    }

    // Handle sunset timer
    if (timeStr == 'Sunset' || timer['turnOnAtSunset'] == true) {
      // Build weekday mask (bit 0 = Sunday, bit 1 = Monday, etc.)
      int weekdayMask = 0;
      final daysText = timer['daysText'] ?? '';
      const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      for (int i = 0; i < dayNames.length; i++) {
        if (daysText.contains(dayNames[i])) {
          weekdayMask |= (1 << i);
        }
      }

      // Return sunset timer settings
      return {
        'en': 1,
        'hour': 254, // 254 indicates sunset
        'min': timer['sunsetOffset'] ?? 0, // Offset in minutes
        'dow': weekdayMask,
        'ps': presetId,
      };
    }

    // Parse regular time (e.g., "7:30 AM" -> hour: 7, minute: 30)
    final parts = timeStr.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final isPM = parts.length > 1 && parts[1] == 'PM';

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    // Build weekday mask (bit 0 = Sunday, bit 1 = Monday, etc.)
    int weekdayMask = 0;
    final daysText = timer['daysText'] ?? '';
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    for (int i = 0; i < dayNames.length; i++) {
      if (daysText.contains(dayNames[i])) {
        weekdayMask |= (1 << i);
      }
    }

    // Return timer settings map
    return {
      'en': 1,
      'hour': hour,
      'min': minute,
      'dow': weekdayMask,
      'ps': presetId,
    };
  }

  void _openAddTimer() async {
    if (!_isDeviceOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device must be online to add timers')),
      );
      return;
    }

    if (!canAddAnyTimer) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2D3436),
          title: const Text(
            'Timer Limit Reached',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Too many timers set. EDIT or DELETE the timers set.\n\nLimit: 8 timers total\n\n• Normal timers (includes OFF): up to 8\n• Sunrise timer: 1\n• Sunset timer: 1',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Okay', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
      return;
    }

    final newTimer = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTimerPage(
          disableSunset: !canAddSunsetTimer,
          disableSunrise: !canAddSunriseTimer,
          canAddOffTimer: canAddNormalTimer,
          allPresets: allPresets,
        ),
      ),
    );
    if (newTimer != null) {
      // Snapshot timers before change for potential rollback
      final previousTimers = timers
          .map((t) => Map<String, dynamic>.from(t))
          .toList();
      // Assign a stable presetId (1-8), reserving 7 for sunrise and 8 for sunset
      final bool isSunrise = newTimer['turnOnAtSunrise'] == true;
      final bool isSunset = newTimer['turnOnAtSunset'] == true;
      if (isSunrise) {
        newTimer['presetId'] = 7;
      } else if (isSunset) {
        newTimer['presetId'] = 8;
      } else {
        final usedIds = <int>{};
        for (final t in timers) {
          final id = t['presetId'];
          if (id is int && id >= 1 && id <= 8) usedIds.add(id);
        }
        int nextId = 1;
        while ((usedIds.contains(nextId) || nextId == 7 || nextId == 8) &&
            nextId <= 8) {
          nextId++;
        }
        if (nextId <= 8) {
          newTimer['presetId'] = nextId;
        } else {
          newTimer['presetId'] = 6; // fallback to a non-reserved slot
        }
      }
      // Save preset to device before adding timer
      Preset? preset;
      String? presetPostId =
          (newTimer['presetPostId']?.toString().isNotEmpty ?? false)
          ? newTimer['presetPostId'].toString()
          : null;
      try {
        if (presetPostId != null) {
          preset = allPresets.firstWhere((p) => p.id == presetPostId);
        } else {
          preset = allPresets.firstWhere(
            (p) => p.name == newTimer['presetName'],
          );
        }
      } catch (_) {
        preset = null;
      }
      // If presets not yet loaded or preset not found, load and retry once to avoid OFF fallback
      if (preset == null &&
          ((newTimer['presetName'] is String &&
                  (newTimer['presetName'] as String).isNotEmpty) ||
              presetPostId != null)) {
        await _loadPresets();
        try {
          if (presetPostId != null) {
            preset = allPresets.firstWhere((p) => p.id == presetPostId);
          } else {
            preset = allPresets.firstWhere(
              (p) => p.name == newTimer['presetName'],
            );
          }
        } catch (_) {
          preset = null;
        }
      }
      if (preset != null) {
        final slot = (newTimer['presetId'] as int?) ?? 1;
        await _savePresetToDevice(preset, slot);
      }
      setState(() {
        timers.add(newTimer);
        // Internal logic: create timer
        internalTimers.add({
          ...newTimer,
          'type': 'on',
          'preset': newTimer['presetName'],
        });
      });

      // Save to WordPress after local update
      await _saveTimersToWordPress();
      await Future.delayed(const Duration(milliseconds: 50));
      final applied = await _setTimerToWLED();
      if (!applied) {
        // Roll back local state and WordPress if device update failed
        setState(() {
          timers = previousTimers
              .map((t) => Map<String, dynamic>.from(t))
              .toList();
          internalTimers.clear();
          for (final t in timers) {
            internalTimers.add({...t, 'type': 'on', 'preset': t['presetName']});
          }
        });
        await _saveTimersToWordPress();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Device update failed. Reverted timers on WordPress.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      // Recall the newly assigned preset so the device reflects user's choice immediately
      final recallId = newTimer['presetId'] as int?;
      if (recallId != null && recallId >= 1 && recallId <= 8) {
        await _recallPreset(recallId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2526),
      appBar: AppBar(
        title: const Text('Timers'),
        backgroundColor: const Color(0xFF2D3436),
        actions: [
          if (_deviceTime != null && _isDeviceOnline) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: GestureDetector(
                  onTap: _showTimezoneDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      _deviceTime!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          IconButton(
            icon: Icon(
              _isDeviceOnline ? Icons.wifi : Icons.wifi_off,
              color: _isDeviceOnline ? Colors.green : Colors.red,
            ),
            onPressed: _checkDeviceConnection,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isCheckingConnection)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Checking device connection...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isCheckingConnection && !_isDeviceOnline)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Device Not Connected',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Timers require a local network connection to the device.\nPlease connect to the same WiFi network as your WLED device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _checkDeviceConnection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Retry Connection',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isDeviceOnline && canAddAnyTimer
                    ? _openAddTimer
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDeviceOnline && canAddAnyTimer
                      ? Colors.blue
                      : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: Text(
                  !_isDeviceOnline
                      ? 'Add Timer (Device Offline)'
                      : !canAddAnyTimer
                      ? 'Add Timer (Limit Reached)'
                      : 'Add Timer',
                  style: TextStyle(
                    fontSize: 16,
                    color: _isDeviceOnline && canAddAnyTimer
                        ? Colors.white
                        : Colors.white54,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: timers.isEmpty
                ? const Center(
                    child: Text(
                      'No timers set yet.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: timers.length,
                    itemBuilder: (context, index) {
                      final timer = timers[index];
                      return Card(
                        key: ValueKey(
                          'timer-${timer['presetId'] ?? timer['name'] ?? index}-${timer['turnOnAtSunrise'] == true
                              ? 'sunrise'
                              : timer['turnOnAtSunset'] == true
                              ? 'sunset'
                              : 'normal'}',
                        ),
                        color: const Color(0xFF2D3436),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: Icon(Icons.timer, color: Colors.blue),
                          title: Text(
                            timer['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preset: ${timer['presetName']?.isEmpty == true || timer['presetName'] == null ? 'OFF' : timer['presetName']}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatScheduleText(timer['daysText'] ?? ''),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Time',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    timer['onTime'],
                                    style: TextStyle(
                                      color: timer['onTime'] == 'Sunrise'
                                          ? Colors.orange
                                          : timer['onTime'] == 'Sunset'
                                          ? Colors.blue
                                          : Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: _isDeviceOnline
                                      ? Colors.white70
                                      : Colors.white38,
                                ),
                                color: const Color(0xFF2D3436),
                                enabled: _isDeviceOnline,
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editTimer(index, timer);
                                  } else if (value == 'delete') {
                                    _deleteTimer(index);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    enabled: _isDeviceOnline,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          color: _isDeviceOnline
                                              ? Colors.white70
                                              : Colors.white38,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: _isDeviceOnline
                                                ? Colors.white
                                                : Colors.white38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    enabled: _isDeviceOnline,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          color: _isDeviceOnline
                                              ? Colors.red
                                              : Colors.white38,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: _isDeviceOnline
                                                ? Colors.white
                                                : Colors.white38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _editTimer(int index, Map<String, dynamic> timer) async {
    if (!_isDeviceOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device must be online to edit timers')),
      );
      return;
    }

    final editedTimer = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTimerPage(
          disableSunset: !canAddSunsetTimer && timer['turnOnAtSunset'] != true,
          disableSunrise:
              !canAddSunriseTimer && timer['turnOnAtSunrise'] != true,
          canAddOffTimer: canAddNormalTimer || timer['presetName'] == 'OFF',
          editingTimer: timer,
          allPresets: allPresets,
        ),
      ),
    );
    if (editedTimer != null) {
      // Snapshot timers before change for potential rollback
      final previousTimers = timers
          .map((t) => Map<String, dynamic>.from(t))
          .toList();
      // Preserve slot but enforce reserved rules (7 sunrise, 8 sunset)
      final currentId = timers[index]['presetId'];
      if (currentId is int) {
        editedTimer['presetId'] = currentId;
      }
      final bool isSunrise = editedTimer['turnOnAtSunrise'] == true;
      final bool isSunset = editedTimer['turnOnAtSunset'] == true;
      if (isSunrise) {
        editedTimer['presetId'] = 7;
      } else if (isSunset) {
        editedTimer['presetId'] = 8;
      } else if (editedTimer['presetId'] == 7 || editedTimer['presetId'] == 8) {
        // Normal timer cannot occupy reserved slots; reassign to next free non-reserved
        final usedIds = <int>{};
        for (int i = 0; i < timers.length; i++) {
          if (i == index) continue; // ignore the one being edited
          final id = timers[i]['presetId'];
          if (id is int && id >= 1 && id <= 8) usedIds.add(id);
        }
        int nextId = 1;
        while ((usedIds.contains(nextId) || nextId == 7 || nextId == 8) &&
            nextId <= 8) {
          nextId++;
        }
        editedTimer['presetId'] = nextId <= 8 ? nextId : 6;
      }
      setState(() {
        timers[index] = editedTimer;
        // Update internal timers
        internalTimers.removeWhere((t) => t['name'] == timer['name']);
        internalTimers.add({
          ...editedTimer,
          'type': 'on',
          'preset': editedTimer['presetName'],
        });
      });
      // Update only the affected preset slot to avoid device resets
      final slot =
          (editedTimer['presetId'] as int?) ??
          (currentId is int ? currentId : 1);
      final name = (editedTimer['presetName'] as String?) ?? '';
      final editedPresetPostId =
          (editedTimer['presetPostId']?.toString().isNotEmpty ?? false)
          ? editedTimer['presetPostId'].toString()
          : null;
      if (name.isEmpty || _normalizePresetName(name) == 'off') {
        await _deletePresetFromDevice(slot);
      } else {
        Preset? presetObj;
        try {
          if (editedPresetPostId != null) {
            presetObj = allPresets.firstWhere(
              (p) => p.id == editedPresetPostId,
            );
          } else {
            presetObj = allPresets.firstWhere(
              (p) => _normalizePresetName(p.name) == _normalizePresetName(name),
            );
          }
        } catch (_) {
          presetObj = null;
        }
        if (presetObj == null) {
          await _loadPresets();
          try {
            if (editedPresetPostId != null) {
              presetObj = allPresets.firstWhere(
                (p) => p.id == editedPresetPostId,
              );
            } else {
              presetObj = allPresets.firstWhere(
                (p) =>
                    _normalizePresetName(p.name) == _normalizePresetName(name),
              );
            }
          } catch (_) {
            presetObj = null;
          }
        }
        if (presetObj != null) {
          await _savePresetToDevice(presetObj, slot);
        }
      }
      await _saveTimersToWordPress();
      await Future.delayed(const Duration(milliseconds: 50));
      final applied = await _setTimerToWLED();
      if (!applied) {
        // Roll back local state and WordPress if device update failed
        setState(() {
          timers = previousTimers
              .map((t) => Map<String, dynamic>.from(t))
              .toList();
          internalTimers.clear();
          for (final t in timers) {
            internalTimers.add({...t, 'type': 'on', 'preset': t['presetName']});
          }
        });
        await _saveTimersToWordPress();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Device update failed. Reverted timers on WordPress.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      // Recall the edited timer's preset so the device reflects user's choice immediately
      final recallId = editedTimer['presetId'] as int?;
      if (recallId != null && recallId >= 1 && recallId <= 8) {
        await _recallPreset(recallId);
      }
    }
  }

  void _deleteTimer(int index) async {
    if (!_isDeviceOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device must be online to delete timers')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D3436),
        title: const Text(
          'Delete Timer',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this timer?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Snapshot timers before change for potential rollback
      final previousTimers = timers
          .map((t) => Map<String, dynamic>.from(t))
          .toList();
      final timer = timers[index];
      final presetId = timer['presetId'] as int?;

      setState(() {
        timers.removeAt(index);
        // Remove from internal timers
        internalTimers.removeWhere((t) => t['name'] == timer['name']);
      });

      // Immediately replace this timer's preset slot with OFF to preserve order
      if (presetId != null && presetId >= 1 && presetId <= 8) {
        await _deletePresetFromDevice(presetId);
      }

      await _saveTimersToWordPress();
      await Future.delayed(const Duration(milliseconds: 50));
      final applied = await _setTimerToWLED();
      if (!applied) {
        // Roll back local state and WordPress if device update failed
        setState(() {
          timers = previousTimers
              .map((t) => Map<String, dynamic>.from(t))
              .toList();
          internalTimers.clear();
          for (final t in timers) {
            internalTimers.add({...t, 'type': 'on', 'preset': t['presetName']});
          }
        });
        await _saveTimersToWordPress();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Device update failed. Reverted timers on WordPress.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
  }
}

class AddTimerPage extends StatefulWidget {
  final bool disableSunset;
  final bool disableSunrise;
  final bool canAddOffTimer;
  final Map<String, dynamic>? editingTimer;
  final List<Preset> allPresets;
  const AddTimerPage({
    super.key,
    this.disableSunset = false,
    this.disableSunrise = false,
    this.canAddOffTimer = true,
    this.editingTimer,
    required this.allPresets,
  });

  @override
  State<AddTimerPage> createState() => _AddTimerPageState();
}

class _AddTimerPageState extends State<AddTimerPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  int onHour = 6;
  int onMinute = 0;
  bool onIsPM = false;

  List<bool> weeklyDays = List.filled(7, false);
  late TabController _tabController;
  int startMonth = 1;
  int startDay = 1;
  int endMonth = 12;
  int endDay = 31;
  Preset? selectedPreset;
  bool turnOnAtSunset = false;
  int sunsetOffset = 0;
  bool turnOnAtSunrise = false;
  int sunriseOffset = 0;
  bool isOffTimer = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController.text = widget.editingTimer?['name'] ?? 'Timer 1';
    weeklyDays = List.filled(7, true); // Default to all days selected
    selectedPreset = widget.allPresets.isNotEmpty ? widget.allPresets[0] : null;

    if (widget.editingTimer != null) {
      final timer = widget.editingTimer!;

      // Set sunset settings
      turnOnAtSunset = timer['turnOnAtSunset'] ?? false;
      sunsetOffset = timer['sunsetOffset'] ?? 0;

      // Set sunrise settings
      turnOnAtSunrise = timer['turnOnAtSunrise'] ?? false;
      sunriseOffset = timer['sunriseOffset'] ?? 0;

      // Parse on/off times if not sunset or sunrise
      if (!turnOnAtSunset && !turnOnAtSunrise && timer['onTime'] != null) {
        final onTimeParts = timer['onTime'].toString().split(' ');
        if (onTimeParts.length == 2) {
          final timePart = onTimeParts[0].split(':');
          if (timePart.length == 2) {
            onHour = int.tryParse(timePart[0]) ?? 1;
            onMinute = int.tryParse(timePart[1]) ?? 0;
            onIsPM = onTimeParts[1] == 'PM';
          }
        }
      }

      // Set preset and OFF state (prefer matching by presetPostId when available)
      if (timer['presetName'] == 'OFF' ||
          timer['presetName']?.isEmpty == true ||
          timer['presetName'] == null) {
        isOffTimer = true;
        selectedPreset = null;
      } else {
        final String? presetPostId =
            (timer['presetPostId']?.toString().isNotEmpty ?? false)
            ? timer['presetPostId'].toString()
            : null;
        if (presetPostId != null) {
          try {
            selectedPreset = widget.allPresets.firstWhere(
              (p) => p.id == presetPostId,
            );
          } catch (_) {
            // fallback to name
            try {
              selectedPreset = widget.allPresets.firstWhere(
                (p) => p.name == timer['presetName'],
              );
            } catch (_) {}
          }
        } else if (timer['presetName'] != null) {
          try {
            selectedPreset = widget.allPresets.firstWhere(
              (p) => p.name == timer['presetName'],
            );
          } catch (_) {}
        }
      }

      // Parse days/date info from daysText
      final daysText = timer['daysText']?.toString() ?? '';
      if (daysText.contains('From ') && daysText.contains(' to ')) {
        // Yearly mode
        _tabController.index = 1;
        // Parse "From Jan 1 to Dec 31" format
        final parts = daysText.split(' to ');
        if (parts.length == 2) {
          final fromPart = parts[0].replaceFirst('From ', '').split(' ');
          final toPart = parts[1].split(' ');
          if (fromPart.length == 2 && toPart.length == 2) {
            startMonth = _monthNameToNumber(fromPart[0]);
            startDay = int.tryParse(fromPart[1]) ?? 1;
            endMonth = _monthNameToNumber(toPart[0]);
            endDay = int.tryParse(toPart[1]) ?? 31;
          }
        }
      } else {
        // Weekly mode
        _tabController.index = 0;
        weeklyDays = List.filled(
          7,
          true,
        ); // Keep all days selected when editing
        const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        for (int i = 0; i < dayNames.length; i++) {
          if (daysText.contains(dayNames[i])) {
            weeklyDays[i] = true;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _pickPreset() async {
    final preset = await showModalBottomSheet<Preset>(
      context: context,
      backgroundColor: const Color(0xFF1E2526),
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: ListView(
            children: widget.allPresets.map((preset) {
              return PresetCard(
                preset: preset,
                onTap: () => Navigator.pop(context, preset),
              );
            }).toList(),
          ),
        );
      },
    );
    if (preset != null) {
      setState(() {
        selectedPreset = preset;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2526),
      appBar: AppBar(
        title: const Text('Add Timer'),
        backgroundColor: const Color(0xFF2D3436),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Preset', style: const TextStyle(color: Colors.white70)),
            Row(
              children: [
                Checkbox(
                  value: isOffTimer,
                  activeColor: Colors.red,
                  onChanged: widget.canAddOffTimer || isOffTimer
                      ? (v) {
                          setState(() {
                            isOffTimer = v ?? false;
                            if (isOffTimer) {
                              selectedPreset = null;
                            } else if (selectedPreset == null &&
                                widget.allPresets.isNotEmpty) {
                              selectedPreset = widget.allPresets.first;
                            }
                          });
                        }
                      : null,
                ),
                const Text('OFF', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: isOffTimer ? null : _pickPreset,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isOffTimer
                            ? const Color(0xFF1A1D1E)
                            : const Color(0xFF2D3436),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOffTimer ? Colors.white12 : Colors.white24,
                        ),
                      ),
                      child: Text(
                        isOffTimer
                            ? 'OFF Timer'
                            : ((selectedPreset?.name ?? '').replaceAll(
                                '&#215;',
                                '×',
                              )),
                        style: TextStyle(
                          color: isOffTimer ? Colors.white38 : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, thickness: 1, height: 32),
            Row(
              children: [
                if (!turnOnAtSunset && !turnOnAtSunrise) ...[
                  const Text(
                    'Turn On:',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: onHour,
                    dropdownColor: const Color(0xFF2D3436),
                    items: List.generate(12, (i) => i + 1)
                        .map(
                          (h) => DropdownMenuItem(
                            value: h,
                            child: Text(
                              h.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => onHour = v ?? 1),
                  ),
                  const Text(':', style: TextStyle(color: Colors.white)),
                  DropdownButton<int>(
                    value: onMinute,
                    dropdownColor: const Color(0xFF2D3436),
                    items: List.generate(60, (i) => i)
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              m.toString().padLeft(2, '0'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => onMinute = v ?? 0),
                  ),
                  DropdownButton<bool>(
                    value: onIsPM,
                    dropdownColor: const Color(0xFF2D3436),
                    items: const [
                      DropdownMenuItem(
                        value: false,
                        child: Text(
                          'AM',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: Text(
                          'PM',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => onIsPM = v ?? false),
                  ),
                ] else if (turnOnAtSunrise) ...[
                  const Text(
                    'Turn On: Sunrise',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Offset (min):',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: sunriseOffset,
                    dropdownColor: const Color(0xFF2D3436),
                    items: List.generate(119, (i) => i - 59)
                        .map(
                          (offset) => DropdownMenuItem(
                            value: offset,
                            child: Text(
                              offset.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => sunriseOffset = v ?? 0),
                  ),
                ] else ...[
                  const Text(
                    'Turn On: Sunset',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Offset (min):',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: sunsetOffset,
                    dropdownColor: const Color(0xFF2D3436),
                    items: List.generate(119, (i) => i - 59)
                        .map(
                          (offset) => DropdownMenuItem(
                            value: offset,
                            child: Text(
                              offset.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => sunsetOffset = v ?? 0),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
            // Advanced timers section
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 5,
                    color: const Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Advanced',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 5,
                    color: const Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Sunrise timer option
            if (widget.disableSunrise && !turnOnAtSunrise) ...[
              const Text(
                'Sunrise timer already set',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ] else if (!widget.disableSunrise || turnOnAtSunrise) ...[
              Row(
                children: [
                  Checkbox(
                    value: turnOnAtSunrise,
                    activeColor: Colors.orange,
                    onChanged: (v) => setState(() {
                      turnOnAtSunrise = v ?? false;
                      if (turnOnAtSunrise) turnOnAtSunset = false;
                    }),
                  ),
                  const Text(
                    'Sunrise timer',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Sunset timer option
            if (widget.disableSunset && !turnOnAtSunset) ...[
              const Text(
                'Sunset timer already set',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ] else if (!widget.disableSunset || turnOnAtSunset) ...[
              Row(
                children: [
                  Checkbox(
                    value: turnOnAtSunset,
                    activeColor: Colors.blue,
                    onChanged: (v) => setState(() {
                      turnOnAtSunset = v ?? false;
                      if (turnOnAtSunset) turnOnAtSunrise = false;
                    }),
                  ),
                  const Text(
                    'Sunset timer',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Weekly'),
                Tab(text: 'Yearly'),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.blue,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Weekly tab
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Days:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (i) {
                          const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                          return GestureDetector(
                            onTap: () =>
                                setState(() => weeklyDays[i] = !weeklyDays[i]),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: weeklyDays[i]
                                    ? Colors.blue
                                    : Colors.transparent,
                                border: Border.all(color: Colors.white38),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                days[i],
                                style: TextStyle(
                                  color: weeklyDays[i]
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  // Yearly tab
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Range:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'From',
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: startMonth,
                            dropdownColor: const Color(0xFF2D3436),
                            items: List.generate(12, (i) => i + 1)
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      _monthName(m),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => startMonth = v ?? 1),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: startDay,
                            dropdownColor: const Color(0xFF2D3436),
                            items: List.generate(31, (i) => i + 1)
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(
                                      d.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => startDay = v ?? 1),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'to',
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: endMonth,
                            dropdownColor: const Color(0xFF2D3436),
                            items: List.generate(12, (i) => i + 1)
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      _monthName(m),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => endMonth = v ?? 12),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: endDay,
                            dropdownColor: const Color(0xFF2D3436),
                            items: List.generate(31, (i) => i + 1)
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(
                                      d.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => endDay = v ?? 31),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    // Gather timer data
                    final name = _nameController.text.trim();
                    String onTime = '';
                    if (turnOnAtSunrise) {
                      onTime = 'Sunrise';
                    } else if (turnOnAtSunset) {
                      onTime = 'Sunset';
                    } else {
                      onTime =
                          '$onHour:${onMinute.toString().padLeft(2, '0')} ${onIsPM ? 'PM' : 'AM'}';
                    }

                    String daysText = '';
                    if (_tabController.index == 0) {
                      // Weekly
                      const days = [
                        'Sun',
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                      ];
                      daysText = [
                        for (int i = 0; i < 7; i++)
                          if (weeklyDays[i]) days[i],
                      ].join(', ');
                    } else {
                      // Yearly
                      daysText =
                          'From ${_monthName(startMonth)} $startDay to ${_monthName(endMonth)} $endDay';
                    }
                    final presetName = selectedPreset?.name ?? '';
                    final presetPostId = selectedPreset?.id;
                    Navigator.pop(context, {
                      'name': name.isEmpty ? 'Timer' : name,
                      'onTime': onTime,
                      'daysText': daysText,
                      'presetName': presetName,
                      if (!isOffTimer && (presetPostId?.isNotEmpty ?? false))
                        'presetPostId': presetPostId,
                      'turnOnAtSunset': turnOnAtSunset,
                      'sunsetOffset': sunsetOffset,
                      'turnOnAtSunrise': turnOnAtSunrise,
                      'sunriseOffset': sunriseOffset,
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}

int _monthNameToNumber(String monthName) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final index = months.indexOf(monthName);
  return index >= 0 ? index + 1 : 1;
}

// Removed broken top-level savePresetToDevice; use _savePresetToDevice instead

String _formatScheduleText(String daysText) {
  if (daysText.isEmpty) return '';

  // Check if it's yearly format
  if (daysText.contains('From ') && daysText.contains(' to ')) {
    // Check if it's the full year (Jan 1 to Dec 31)
    if (daysText == 'From Jan 1 to Dec 31') {
      return '(everyday)';
    }
    return 'Sun, Mon, Tue, Wed, Thu, Fri, Sat - $daysText';
  }

  // Check if it's weekly format
  const allDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  final selectedDays = allDays.where((day) => daysText.contains(day)).toList();

  if (selectedDays.length == 7) {
    return '(everyday)';
  }

  return selectedDays.join(', ');
}
