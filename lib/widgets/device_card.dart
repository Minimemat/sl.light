import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/device.dart';
import '../blocs/device_bloc.dart';
import '../services/mqtt_service.dart';
import '../screens/device_screen.dart';
import 'dart:async';
import '../screens/device_settings.dart';

class DeviceCard extends StatefulWidget {
  final Device device;
  final VoidCallback? onRefresh;

  const DeviceCard({super.key, required this.device, this.onRefresh});

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  bool _isPowerOn = false;
  DeviceMqttService? _deviceMqttService;
  bool _hasReceivedMqttState = false;
  bool _isPinging = false;
  DateTime? _lastMqttUpdateAt;
  Timer? _settingsLongPressTimer;
  bool _longPressActive = false;
  bool _openedSettingsViaLongPress = false;

  @override
  void initState() {
    super.initState();
    print('🔌 CARD: initState for ${widget.device.name}');

    // Initialize with device state
    _isPowerOn = widget.device.isPoweredOn;
    print('🔌 CARD: Starting with power state: ${_isPowerOn ? 'ON' : 'OFF'}');

    // Initialize MQTT service
    _deviceMqttService = DeviceMqttService(widget.device);

    // Set up MQTT callbacks - MQTT is the source of truth
    _deviceMqttService!.onPowerUpdate = (bool isPoweredOn) {
      print(
        '🔌 CARD: Power update received for ${widget.device.name}: $isPoweredOn',
      );
      if (mounted) {
        _hasReceivedMqttState = true;
        _lastMqttUpdateAt = DateTime.now();
        // MQTT is source of truth - always update local state
        setState(() {
          _isPowerOn = isPoweredOn;
        });

        // Dispatch bloc event to update global state
        final deviceBloc = context.read<DeviceBloc>();
        deviceBloc.add(
          UpdateDevicePowerFromMqtt(widget.device.id, isPoweredOn),
        );
        deviceBloc.add(UpdateDeviceOnlineStatus(widget.device.id, true));
        print('🔌 CARD: Bloc event dispatched for power update: $isPoweredOn');
      }
    };

    _deviceMqttService!.onBrightnessUpdate = (int brightness) {
      print(
        '💡 CARD: Brightness update received for ${widget.device.name}: $brightness',
      );
      if (mounted) {
        _lastMqttUpdateAt = DateTime.now();
        // Dispatch bloc event to update global state
        final deviceBloc = context.read<DeviceBloc>();
        deviceBloc.add(UpdateDeviceBrightness(widget.device.id, brightness));
        print(
          '🔌 CARD: Bloc event dispatched for brightness update: $brightness',
        );
      }
    };

    _deviceMqttService!.onStateUpdate = (Map<String, dynamic> state) {
      print('📡 CARD: State update received for ${widget.device.name}: $state');
      if (mounted) {
        _hasReceivedMqttState = true;
        _lastMqttUpdateAt = DateTime.now();
        // MQTT is source of truth - always update local state
        if (state.containsKey('on')) {
          final isPoweredOn = state['on'] ?? false;
          setState(() {
            _isPowerOn = isPoweredOn;
          });
          print('🔌 CARD: Local state updated from MQTT: $isPoweredOn');
        }

        // Dispatch bloc event to update global state
        final deviceBloc = context.read<DeviceBloc>();
        deviceBloc.add(UpdateDeviceStateFromMqtt(widget.device.id, state));
        deviceBloc.add(UpdateDeviceOnlineStatus(widget.device.id, true));
        print('🔌 CARD: Bloc event dispatched for state update');
      }
    };

    // Connect to MQTT
    _connectMqtt();

    print('🔌 CARD: MQTT service initialized for ${widget.device.name}');
  }

  Future<void> _connectMqtt() async {
    try {
      await _deviceMqttService?.connect();
      print('🔌 CARD: MQTT connected for ${widget.device.name}');
    } catch (e) {
      print('🔌 CARD: MQTT connection failed for ${widget.device.name}: $e');
    }
  }

  void _togglePower() {
    print('🔌 CARD: _togglePower called!');
    print('🔌 CARD: Current power state: $_isPowerOn');

    // Optimistic update for immediate UI response
    final newPowerState = !_isPowerOn;
    setState(() {
      _isPowerOn = newPowerState;
    });

    print('🔌 CARD: Optimistic update to: $_isPowerOn');

    // Send MQTT command using the simplified service
    _deviceMqttService?.togglePower(_isPowerOn).catchError((e) {
      print('🔌 CARD: Error sending MQTT command: $e');
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _isPowerOn = !_isPowerOn;
        });
        print('🔌 CARD: Reverted optimistic update due to error');
      }
    });

    // Dispatch bloc event for optimistic global state update
    try {
      final deviceBloc = context.read<DeviceBloc>();
      deviceBloc.add(ToggleDevicePower(widget.device.id, _isPowerOn));
      print(
        '🔌 CARD: Bloc event dispatched: ToggleDevicePower(${widget.device.id}, $_isPowerOn)',
      );
    } catch (e) {
      print('🔌 CARD: Error dispatching bloc event: $e');
    }
  }

  Future<void> _safePing() async {
    try {
      // Connect to MQTT if needed (lazy loading)
      await _connectMqtt();

      // If a very recent MQTT update came in, wait a moment to avoid overlap
      if (_lastMqttUpdateAt != null) {
        final since = DateTime.now().difference(_lastMqttUpdateAt!);
        if (since < const Duration(milliseconds: 300)) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
      await _deviceMqttService?.pingDevice();
    } catch (e) {
      print('🔌 CARD: Ping error for ${widget.device.name}: $e');
    }
  }

  @override
  void dispose() {
    _settingsLongPressTimer?.cancel();
    _deviceMqttService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceBloc, DeviceState>(
      builder: (context, state) {
        // Find the current device in the bloc state
        Device? currentDevice;
        if (state is DeviceLoaded) {
          currentDevice = state.devices.firstWhere(
            (d) => d.id == widget.device.id,
            orElse: () => widget.device,
          );
        } else {
          currentDevice = widget.device;
        }

        final bool isOnline = currentDevice.isOnline;

        // Only update from bloc before the first MQTT state arrives.
        // After that, keep using MQTT state to avoid stale overwrites.
        // If MQTT hasn't updated in a while, allow bloc to refresh UI.
        final bool mqttStale =
            _lastMqttUpdateAt == null ||
            DateTime.now().difference(_lastMqttUpdateAt!) >
                const Duration(seconds: 2);
        if ((!_hasReceivedMqttState || mqttStale) &&
            currentDevice.isPoweredOn != _isPowerOn) {
          print(
            '🔌 CARD: Updating from bloc state - ${currentDevice.isPoweredOn}',
          );
          _isPowerOn = currentDevice.isPoweredOn;
        }

        print(
          '🔌 CARD: build() called for ${widget.device.name} - power: $_isPowerOn',
        );

        return Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GestureDetector(
            onLongPressStart: (_) {
              _longPressActive = true;
              _settingsLongPressTimer?.cancel();
              _settingsLongPressTimer = Timer(
                const Duration(seconds: 2),
                () async {
                  if (!mounted) return;
                  if (!_longPressActive) return;
                  _openedSettingsViaLongPress = true;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DeviceSettingsScreen(device: widget.device),
                    ),
                  );
                  if (!mounted) return;
                  setState(() {
                    _hasReceivedMqttState = false;
                  });
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (!mounted) return;
                    context.read<DeviceBloc>().add(
                      PingDevice(widget.device.id),
                    );
                  });
                },
              );
            },
            onLongPressEnd: (_) {
              _longPressActive = false;
              _settingsLongPressTimer?.cancel();
            },
            onTapCancel: () {
              _longPressActive = false;
              _settingsLongPressTimer?.cancel();
            },
            child: InkWell(
              onTap: () async {
                if (_openedSettingsViaLongPress) {
                  _openedSettingsViaLongPress = false;
                  return;
                }
                if (!isOnline) {
                  // Show feedback that device is disconnected but still allow navigation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${widget.device.name} is disconnected'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeviceScreen(device: widget.device),
                  ),
                );
                if (!mounted) return;
                // Allow bloc to refresh UI until MQTT resumes, then ping after a short delay
                setState(() {
                  _hasReceivedMqttState = false;
                });
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (!mounted) return;
                  context.read<DeviceBloc>().add(PingDevice(widget.device.id));
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.device.name,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Sync button
                        IconButton(
                          icon: _isPinging
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync, color: Colors.blue),
                          onPressed: _isPinging
                              ? null
                              : () async {
                                  setState(() => _isPinging = true);
                                  if (!isOnline) {
                                    // Allow some time for the device to potentially come back online
                                    await Future.delayed(
                                      const Duration(seconds: 5),
                                    );
                                    if (!mounted) return;
                                  }
                                  await _safePing();
                                  if (!mounted) return;
                                  await Future.delayed(
                                    const Duration(seconds: 1),
                                  );
                                  if (mounted) {
                                    setState(() => _isPinging = false);
                                  }
                                },
                          tooltip: 'Sync device state',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (!isOnline) ...[
                          Expanded(
                            child: Text(
                              'DISCONNECTED',
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Text(
                              _isPowerOn ? 'POWER ON' : 'POWER OFF',
                              style: TextStyle(
                                color: _isPowerOn ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          // Power toggle button
                          Switch(
                            value: _isPowerOn,
                            onChanged: (value) {
                              if (!isOnline) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Device is disconnected'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              print(
                                '🔌 CARD: Switch onChanged called with value: $value',
                              );
                              _togglePower();
                            },
                            activeColor: const Color(0xFF5865F2),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
