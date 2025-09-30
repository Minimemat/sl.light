import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../models/device.dart';
import '../services/device_info_service.dart';
import '../services/mdns_service.dart';
import '../services/mqtt_service.dart';
import '../services/storage_service.dart';
import '../services/wled_api.dart';
import '../screens/timers_screen.dart';
import '../screens/custom_pattern_screen.dart';
import '../blocs/device_bloc.dart';

class DeviceSettingsDrawer extends StatefulWidget {
  final Device device;
  final VoidCallback? onRefresh;

  const DeviceSettingsDrawer({super.key, required this.device, this.onRefresh});

  @override
  State<DeviceSettingsDrawer> createState() => _DeviceSettingsDrawerState();
}

class _DeviceSettingsDrawerState extends State<DeviceSettingsDrawer> {
  Map<String, dynamic>? _deviceInfo;
  bool _isLoadingDeviceInfo = false;
  final StorageService _storageService = StorageService();
  final WledApi _wledApi = WledApi();

  // Brightness slider state
  int _brightness = 150;
  bool _isDraggingBrightness = false;
  double _draggingBrightness = 150;
  DeviceMqttService? _deviceMqttService;

  @override
  void initState() {
    super.initState();
    _deviceMqttService = DeviceMqttService(widget.device);
    _loadBrightness();
    _fetchDeviceInfo();
  }

  @override
  void dispose() {
    // Reset device info state to prevent stale data
    _deviceInfo = null;
    _isLoadingDeviceInfo = false;
    _deviceMqttService?.dispose();
    super.dispose();
  }

  void _loadBrightness() {
    // Get brightness from current DeviceBloc state
    final blocState = context.read<DeviceBloc>().state;
    if (blocState is DeviceLoaded) {
      final currentDevice = blocState.devices.firstWhere(
        (d) => d.id == widget.device.id,
        orElse: () => widget.device,
      );
      if (mounted) {
        setState(() {
          _brightness = currentDevice.brightness;
          _draggingBrightness = currentDevice.brightness.toDouble();
        });
      }
    } else {
      // Fallback to device brightness if DeviceBloc not loaded yet
      if (mounted) {
        setState(() {
          _brightness = widget.device.brightness;
          _draggingBrightness = widget.device.brightness.toDouble();
        });
      }
    }
  }

  Future<void> _fetchDeviceInfo() async {
    if (_isLoadingDeviceInfo) return;

    setState(() {
      _isLoadingDeviceInfo = true;
    });

    try {
      // 1) Try saved IP first
      String? savedIp = await _storageService.loadDeviceIpAddress(
        widget.device.id,
      );
      if (savedIp == null || savedIp.isEmpty) {
        savedIp = widget.device.ipAddress;
      }

      if (savedIp.isNotEmpty) {
        print(
          'Using saved IP address: $savedIp for device ${widget.device.name}',
        );
        final ok = await _fetchDeviceInfoFromIp(savedIp);
        if (ok) return;
      }

      // 2) If that failed, discover using the new DeviceDiscoveryService
      print(
        'No working IP for device ${widget.device.name}, attempting discovery...',
      );

      // Try the new modular discovery service first
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
        print('DeviceDiscoveryService failed: $e');
      }

      // No fallback service available - discovery failed
      if (discoveredIp == null) {
        print('Device discovery failed - no matching device found');
      }

      if (discoveredIp != null) {
        print(
          'Discovered IP address: $discoveredIp for device ${widget.device.name}',
        );
        final ok = await _fetchDeviceInfoFromIp(discoveredIp);
        if (ok) {
          await _storageService.saveDeviceIpAddress(
            widget.device.id,
            discoveredIp,
          );
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingDeviceInfo = false;
        });
      }
    } catch (e) {
      print('Error fetching device info: $e');
      if (mounted) {
        setState(() {
          _isLoadingDeviceInfo = false;
        });
      }
    }
  }

  Future<bool> _fetchDeviceInfoFromIp(String ipAddress) async {
    try {
      print('Fetching device info from: $ipAddress');

      // Try multiple endpoints to get device info
      final endpoints = [
        'http://$ipAddress/json/info',
        'http://$ipAddress/json',
      ];

      for (final endpoint in endpoints) {
        try {
          print('Trying endpoint: $endpoint');
          final response = await http
              .get(Uri.parse(endpoint))
              .timeout(const Duration(seconds: 3));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            print(
              'Device info received from $endpoint: ${data.keys.join(', ')}',
            );

            // Verify this is a WLED device
            final isWledDevice =
                data['ver'] != null ||
                data['brand'] == 'WLED' ||
                data['product'] == 'FOSS' ||
                data['arch'] != null ||
                data['core'] != null ||
                data['leds'] != null ||
                data['state'] != null;

            if (isWledDevice) {
              if (mounted) {
                setState(() {
                  _deviceInfo = data;
                  _isLoadingDeviceInfo = false;
                });
              }
              return true;
            } else {
              print('Device at $ipAddress is not a WLED device');
            }
          } else {
            print('HTTP ${response.statusCode} from $endpoint');
          }
        } catch (e) {
          print('Failed to connect to $endpoint: $e');
          continue;
        }
      }

      print('Failed to fetch device info from $ipAddress');
      return false;
    } catch (e) {
      print('Error fetching device info from $ipAddress: $e');
      return false;
    }
  }

  Future<void> _restartDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Device'),
        content: const Text(
          'Are you sure you want to restart this WLED device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final ipAddress =
            await _storageService.loadDeviceIpAddress(widget.device.id) ??
            widget.device.ipAddress;
        if (ipAddress.isNotEmpty) {
          await _wledApi.restartDevice(ipAddress);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Device restarting...')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to restart device: $e')),
          );
        }
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(color: Colors.blueGrey),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DeviceBloc, DeviceState>(
      listener: (context, state) {
        // Update brightness when DeviceBloc state changes (from MQTT updates)
        if (state is DeviceLoaded) {
          final currentDevice = state.devices.firstWhere(
            (d) => d.id == widget.device.id,
            orElse: () => widget.device,
          );
          if (currentDevice.brightness != _brightness &&
              !_isDraggingBrightness) {
            setState(() {
              _brightness = currentDevice.brightness;
              _draggingBrightness = currentDevice.brightness.toDouble();
            });
          }
        }
      },
      child: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text(
                    'Device Info',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (_isLoadingDeviceInfo)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchDeviceInfo,
                      tooltip: 'Refresh device info',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Device name and IP address card at the top
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Brightness: ${_isDraggingBrightness ? _draggingBrightness.round() : _brightness}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Slider(
                      min: 0,
                      max: 255,
                      value: _isDraggingBrightness
                          ? _draggingBrightness
                          : _brightness.toDouble(),
                      activeColor: Colors.white,
                      inactiveColor: Colors.white30,
                      thumbColor: Colors.white,
                      divisions: 254,
                      overlayColor: WidgetStateProperty.all(
                        Theme.of(context).primaryColor.withOpacity(0.1),
                      ),
                      onChanged: (newValue) {
                        setState(() {
                          _isDraggingBrightness = true;
                          _draggingBrightness = newValue;
                        });
                      },
                      onChangeEnd: (newValue) async {
                        final newBrightness = newValue.round();
                        setState(() {
                          _isDraggingBrightness = false;
                          _brightness = newBrightness;
                        });

                        // Update via DeviceBloc - this handles both MQTT and persistence
                        try {
                          context.read<DeviceBloc>().add(
                            UpdateDeviceBrightness(
                              widget.device.id,
                              newBrightness,
                            ),
                          );
                          // Also send brightness update to device via MQTT for immediate response
                          await _deviceMqttService?.connect();
                          _deviceMqttService?.sendCommand({
                            'bri': newBrightness,
                          });
                        } catch (e) {
                          print('Error updating device brightness: $e');
                          // Show error to user but don't block UI
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to update device brightness: $e',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.palette_outlined),
                      label: const Text('Custom Pattern'),
                      onPressed: () {
                        Navigator.of(context).maybePop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                CustomPatternScreen(device: widget.device),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '(Local Wifi only below)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              if (_deviceInfo != null) ...[
                /*_infoRow(
                  'Software Version',
                  _deviceInfo!['ver']?.toString() ?? 'Unknown',
                ),
                _infoRow(
                  'LED Configuration',
                  DeviceService.formatLedInfo(_deviceInfo!['leds']),
                ),*/
                _infoRow(
                  'Power Usage',
                  DeviceInfoService.formatPowerUsage(
                    _deviceInfo!['leds']?['pwr'],
                  ),
                ),
                _infoRow(
                  'Uptime',
                  DeviceInfoService.formatUptime(_deviceInfo!['uptime']),
                ),
                _infoRow(
                  'IP Address',
                  _deviceInfo!['ip']?.toString() ?? 'Unknown',
                ),
                _infoRow(
                  'Current Time',
                  DeviceInfoService.formatDeviceTime(_deviceInfo!['time']),
                ),
              ] else if (_isLoadingDeviceInfo) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                const Text(
                  'Loading device information...',
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const Text('No device information available'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _fetchDeviceInfo,
                      child: const Text('Retry'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        // Clear saved IP and force rediscovery
                        await _storageService.saveDeviceIpAddress(
                          widget.device.id,
                          '',
                        );
                        _fetchDeviceInfo();
                      },
                      child: const Text('Rediscover'),
                    ),
                  ],
                ),
              ],
              const Divider(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text('Sync'),
                onPressed: () {
                  // TODO: Implement sync logic
                  Navigator.of(context).maybePop();
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.timer),
                label: const Text('Timers'),
                onPressed: () {
                  Navigator.of(context).maybePop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TimersScreen(device: widget.device),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restart Device'),
                onPressed: _restartDevice,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
