import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/wled_api.dart';
import '../widgets/firmware_update_drawer.dart';

import '../models/device.dart';
import '../services/storage_service.dart';
import '../services/mdns_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/device_bloc.dart';

class DeviceSettingsScreen extends StatefulWidget {
  final Device device;

  const DeviceSettingsScreen({super.key, required this.device});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _LedOutput {
  int gpio;
  int start;
  int length;
  bool reversed;
  int skip;
  _LedOutput({
    required this.gpio,
    required this.start,
    required this.length,
    required this.reversed,
    required this.skip,
  });
  _LedOutput copyWith({
    int? gpio,
    int? start,
    int? length,
    bool? reversed,
    int? skip,
  }) => _LedOutput(
    gpio: gpio ?? this.gpio,
    start: start ?? this.start,
    length: length ?? this.length,
    reversed: reversed ?? this.reversed,
    skip: skip ?? this.skip,
  );
}

class _LedOutputEditor extends StatelessWidget {
  final int index;
  final _LedOutput output;
  final ValueChanged<_LedOutput> onChanged;
  final VoidCallback? onRemove;
  final int? prevCumLen;
  const _LedOutputEditor({
    required this.index,
    required this.output,
    required this.onChanged,
    this.onRemove,
    this.prevCumLen,
  });

  @override
  Widget build(BuildContext context) {
    // final labelStyle = const TextStyle(color: Colors.white70);
    final inputTextStyle = const TextStyle(color: Colors.white);
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white24),
    );
    final int previousCum = prevCumLen ?? 0;
    final bool isOtherStart =
        !(output.start == 0 || (index > 0 && output.start == previousCum));
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${index + 1}: LED output',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.remove_circle,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Remove output',
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Start selector (first output forced to Flow)
          if (index == 0) ...[
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Start',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isDense: true,
                            isExpanded: true,
                            iconSize: 18,
                            value: 'flow',
                            dropdownColor: const Color(0xFF2D3436),
                            items: const [
                              DropdownMenuItem(
                                value: 'flow',
                                child: Text(
                                  'Flow',
                                  style: TextStyle(color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            onChanged: null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _NumberField(
                    label: 'Length',
                    value: output.length,
                    onChanged: (v) => onChanged(output.copyWith(length: v)),
                    inputTextStyle: inputTextStyle,
                    border: border,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Start',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white24),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isDense: true,
                                  isExpanded: true,
                                  iconSize: 18,
                                  value: () {
                                    if (output.start == 0) return 'flow';
                                    if (index > 0 &&
                                        output.start == previousCum) {
                                      return 'inline';
                                    }
                                    return 'other';
                                  }(),
                                  dropdownColor: const Color(0xFF2D3436),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'flow',
                                      child: Text(
                                        'Flow',
                                        style: TextStyle(color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'inline',
                                      child: Text(
                                        'Inline',
                                        style: TextStyle(color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'other',
                                      child: Text(
                                        'Delay',
                                        style: TextStyle(color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val == null) return;
                                    if (val == 'flow') {
                                      onChanged(output.copyWith(start: 0));
                                    } else if (val == 'inline') {
                                      onChanged(
                                        output.copyWith(start: previousCum),
                                      );
                                    } else {
                                      // Switch to custom delay; set default to 20
                                      onChanged(output.copyWith(start: 20));
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          if (isOtherStart) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: TextFormField(
                                initialValue: output.start.toString(),
                                style: inputTextStyle,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(5),
                                ],
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  enabledBorder: border,
                                  focusedBorder: border.copyWith(
                                    borderSide: const BorderSide(
                                      color: Colors.blue,
                                    ),
                                  ),
                                  hintText: '0',
                                  hintStyle: const TextStyle(
                                    color: Colors.white24,
                                  ),
                                ),
                                onChanged: (s) {
                                  final v = int.tryParse(s);
                                  if (v != null) {
                                    onChanged(output.copyWith(start: v));
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _NumberField(
                    label: 'Length',
                    value: output.length,
                    onChanged: (v) => onChanged(output.copyWith(length: v)),
                    inputTextStyle: inputTextStyle,
                    border: border,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data GPIO',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: Builder(
                                builder: (context) {
                                  final parentState = context
                                      .findAncestorStateOfType<
                                        _DeviceSettingsScreenState
                                      >();
                                  final Set<int> usedGpios = {
                                    if (parentState != null)
                                      ...parentState._ledOutputs
                                          .asMap()
                                          .entries
                                          .where((e) => e.key != index)
                                          .map((e) => e.value.gpio),
                                  };
                                  String currentValue =
                                      const [16, 2, 3].contains(output.gpio)
                                      ? output.gpio.toString()
                                      : 'other';
                                  final List<int> fixedOptions = const [
                                    16,
                                    2,
                                    3,
                                  ];
                                  return DropdownButton<String>(
                                    isDense: true,
                                    value: currentValue,
                                    dropdownColor: const Color(0xFF2D3436),
                                    items: [
                                      for (final opt in fixedOptions)
                                        DropdownMenuItem(
                                          value: opt.toString(),
                                          enabled: !usedGpios.contains(opt),
                                          child: Text(
                                            usedGpios.contains(opt)
                                                ? '${opt == 3 ? 'Y Split' : opt} (used)'
                                                : opt == 3
                                                ? 'Y Split'
                                                : '$opt',
                                            style: TextStyle(
                                              color: usedGpios.contains(opt)
                                                  ? Colors.white24
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                      const DropdownMenuItem(
                                        value: 'other',
                                        child: Text(
                                          'Other',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val == null) return;
                                      if (val == 'other') {
                                        onChanged(output.copyWith(gpio: 0));
                                      } else {
                                        final parsed = int.tryParse(val);
                                        if (parsed == null) return;
                                        onChanged(
                                          output.copyWith(gpio: parsed),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        if (![16, 2, 3].contains(output.gpio)) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 64,
                            child: TextFormField(
                              initialValue: output.gpio.toString(),
                              style: inputTextStyle,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                enabledBorder: border,
                                focusedBorder: border.copyWith(
                                  borderSide: const BorderSide(
                                    color: Colors.blue,
                                  ),
                                ),
                                hintText: '00',
                                hintStyle: const TextStyle(
                                  color: Colors.white24,
                                ),
                              ),
                              onChanged: (s) {
                                final v = int.tryParse(s);
                                if (v == null) return;
                                // Prevent duplicate GPIO among outputs
                                final parentState = context
                                    .findAncestorStateOfType<
                                      _DeviceSettingsScreenState
                                    >();
                                if (parentState != null) {
                                  final dup = parentState._ledOutputs
                                      .asMap()
                                      .entries
                                      .any(
                                        (e) =>
                                            e.key != index && e.value.gpio == v,
                                      );
                                  if (dup) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'GPIO already used by another output',
                                        ),
                                      ),
                                    );
                                  } else {
                                    onChanged(output.copyWith(gpio: v));
                                  }
                                } else {
                                  onChanged(output.copyWith(gpio: v));
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _NumberField(
                  label: 'Skip first LEDs',
                  value: output.skip,
                  onChanged: (v) => onChanged(output.copyWith(skip: v)),
                  inputTextStyle: inputTextStyle,
                  border: border,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Reversed:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Checkbox(
                      value: output.reversed,
                      onChanged: (v) =>
                          onChanged(output.copyWith(reversed: v ?? false)),
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final TextStyle inputTextStyle;
  final OutlineInputBorder border;
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.inputTextStyle,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value.toString(),
          style: inputTextStyle,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
          onChanged: (s) {
            final v = int.tryParse(s);
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  final StorageService _storageService = StorageService();
  final WledApi _wledApi = WledApi();
  bool _isDeviceOnline = false;
  bool _isCheckingConnection = true;
  String? _deviceIpAddress;
  bool _isLoadingJson = false;
  Map<String, dynamic>? _fullJson;
  String? _jsonError;
  bool _loadingLedCfg = false;
  bool _savingLedCfg = false;

  final List<_LedOutput> _ledOutputs = [];
  // Brightness limiter (always enabled); PSU current (mA)
  bool _limitEnabled = true;
  int? _limitMaxMa; // 14500 (350W) or 24000 (600W)

  @override
  void initState() {
    super.initState();
    _checkDeviceConnection();
  }

  Future<void> _checkDeviceConnection() async {
    if (!mounted) return;
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
        final isOnline = await _testDeviceConnection(ipAddress);
        if (isOnline) {
          if (!mounted) return;
          setState(() {
            _isDeviceOnline = true;
            _deviceIpAddress = ipAddress;
            _isCheckingConnection = false;
          });
          await _loadLedOutputs();
          await _fetchFullJson();
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
          if (!mounted) return;
          setState(() {
            _isDeviceOnline = true;
            _deviceIpAddress = discoveredIp;
            _isCheckingConnection = false;
          });
          await _loadLedOutputs();
          await _fetchFullJson();
          return;
        }
      }

      // If discovery failed, mark as offline
      if (!mounted) return;
      setState(() {
        _isDeviceOnline = false;
        _deviceIpAddress = null;
        _isCheckingConnection = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeviceOnline = false;
        _deviceIpAddress = null;
        _isCheckingConnection = false;
      });
    }
  }

  Future<bool> _testDeviceConnection(String ipAddress) async {
    try {
      final url = Uri.parse('http://$ipAddress/json/info');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchFullJson() async {
    if (_deviceIpAddress == null) return;
    setState(() {
      _isLoadingJson = true;
      _jsonError = null;
    });
    try {
      final url = Uri.parse('http://$_deviceIpAddress/json');
      print('[DeviceSettings] GET /json -> $url');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _fullJson = decoded;
            _isLoadingJson = false;
          });
          print(
            '[DeviceSettings] /json bytes=${response.bodyBytes.length} keys=${_fullJson!.keys.join(', ')}',
          );
        } else {
          setState(() {
            _jsonError = 'Unexpected JSON structure';
            _isLoadingJson = false;
          });
          print(
            '[DeviceSettings] /json unexpected structure: ${decoded.runtimeType}',
          );
        }
      } else {
        setState(() {
          _jsonError = 'HTTP ${response.statusCode}';
          _isLoadingJson = false;
        });
        print('[DeviceSettings] /json HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _jsonError = e.toString();
        _isLoadingJson = false;
      });
      print('[DeviceSettings] /json error: $e');
    }
  }

  Future<void> _loadLedOutputs() async {
    if (_deviceIpAddress == null) return;
    setState(() {
      _loadingLedCfg = true;
      _ledOutputs.clear();
    });
    try {
      final cfg = await _wledApi.getConfig(_deviceIpAddress!);
      print('[DeviceSettings] Loaded cfg.json (keys=${cfg.keys})');
      // Prefer newer hw.led.ins if present
      List<dynamic> hwIns = const [];
      try {
        final hwRaw = cfg['hw'];
        final hw = hwRaw is Map
            ? Map<String, dynamic>.from(hwRaw)
            : <String, dynamic>{};
        final ledRaw = hw['led'];
        final led = ledRaw is Map
            ? Map<String, dynamic>.from(ledRaw)
            : <String, dynamic>{};
        final insRaw = led['ins'];
        hwIns = insRaw is List ? List<dynamic>.from(insRaw) : const [];
      } catch (_) {}

      if (hwIns.isNotEmpty) {
        for (final item in hwIns) {
          if (item is Map<String, dynamic>) {
            final pins = (item['pin'] ?? []) as List?;
            final gpio = (pins != null && pins.isNotEmpty)
                ? (pins.first is int
                      ? pins.first as int
                      : int.tryParse('${pins.first}') ?? 2)
                : 2;
            final start = item['start'] is int
                ? item['start'] as int
                : int.tryParse('${item['start'] ?? 0}') ?? 0;
            final len = item['len'] is int
                ? item['len'] as int
                : int.tryParse('${item['len'] ?? 0}') ?? 0;
            final rev = item['rev'] == true;
            final skip = item['skip'] is int
                ? item['skip'] as int
                : int.tryParse('${item['skip'] ?? 0}') ?? 0;
            _ledOutputs.add(
              _LedOutput(
                gpio: gpio,
                start: start,
                length: len,
                reversed: rev,
                skip: skip,
              ),
            );
          }
        }
        // Nothing to do for globals; we enforce constants on save
        // read limiter from hw.led
        try {
          final hwRaw = cfg['hw'];
          final hw = hwRaw is Map
              ? Map<String, dynamic>.from(hwRaw)
              : <String, dynamic>{};
          final ledRaw = hw['led'];
          final led = ledRaw is Map
              ? Map<String, dynamic>.from(ledRaw)
              : <String, dynamic>{};
          final int? maxVal = led['maxpwr'] is int
              ? led['maxpwr'] as int
              : int.tryParse('${led['maxpwr'] ?? ''}');
          if (maxVal != null) {
            _limitEnabled = maxVal > 0;
            _limitMaxMa = maxVal;
          } else {
            _limitEnabled = led['ld'] == true;
            _limitMaxMa = null;
          }
        } catch (_) {}
      } else {
        final ledsRaw = cfg['leds'];
        final leds = ledsRaw is Map
            ? Map<String, dynamic>.from(ledsRaw)
            : <String, dynamic>{};
        final insRaw = leds['ins'];
        final ins = insRaw is List ? List<dynamic>.from(insRaw) : const [];
        if (ins.isNotEmpty) {
          for (final item in ins) {
            if (item is Map<String, dynamic>) {
              final pins = (item['pin'] ?? []) as List?;
              final gpio = (pins != null && pins.isNotEmpty)
                  ? (pins.first is int
                        ? pins.first as int
                        : int.tryParse('${pins.first}') ?? 2)
                  : 2;
              final start = item['start'] is int
                  ? item['start'] as int
                  : int.tryParse('${item['start'] ?? 0}') ?? 0;
              final len = item['len'] is int
                  ? item['len'] as int
                  : int.tryParse('${item['len'] ?? 0}') ?? 0;
              final rev = item['rev'] == true;
              final skip = item['skip'] is int
                  ? item['skip'] as int
                  : int.tryParse('${item['skip'] ?? 0}') ?? 0;
              _ledOutputs.add(
                _LedOutput(
                  gpio: gpio,
                  start: start,
                  length: len,
                  reversed: rev,
                  skip: skip,
                ),
              );
            }
          }
          // Nothing to do for globals; we enforce constants on save
          // fallback limiter from leds
          try {
            final ledsRaw = cfg['leds'];
            final leds = ledsRaw is Map
                ? Map<String, dynamic>.from(ledsRaw)
                : <String, dynamic>{};
            final int? maxVal = leds['maxpwr'] is int
                ? leds['maxpwr'] as int
                : int.tryParse('${leds['maxpwr'] ?? ''}');
            if (maxVal != null) {
              _limitEnabled = maxVal > 0;
              _limitMaxMa = maxVal;
            } else {
              _limitEnabled = leds['ld'] == true;
              _limitMaxMa = null;
            }
          } catch (_) {}
        } else {
          final pins = (leds['pin'] is List)
              ? List.from(leds['pin'] as List)
              : null;
          final len = leds['len'] is int
              ? leds['len'] as int
              : int.tryParse('${leds['len'] ?? 0}') ?? 0;
          final start = leds['start'] is int
              ? leds['start'] as int
              : int.tryParse('${leds['start'] ?? 0}') ?? 0;
          final rev = leds['rev'] == true;
          final skip = leds['skip'] is int
              ? leds['skip'] as int
              : int.tryParse('${leds['skip'] ?? 0}') ?? 0;
          final gpio = (pins != null && pins.isNotEmpty)
              ? (pins.first is int
                    ? pins.first as int
                    : int.tryParse('${pins.first}') ?? 2)
              : 2;
          _ledOutputs.add(
            _LedOutput(
              gpio: gpio,
              start: start,
              length: len,
              reversed: rev,
              skip: skip,
            ),
          );
        }
      }
      print(
        '[DeviceSettings] Parsed ${_ledOutputs.length} LED outputs -> ${_ledOutputs.map((o) => '{gpio:${o.gpio},start:${o.start},len:${o.length},rev:${o.reversed},skip:${o.skip}}').join(' | ')}',
      );
    } catch (e) {
      // ignore and leave empty
      print('[DeviceSettings] Error loading LED outputs: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingLedCfg = false;
        });
      }
    }
  }

  Future<void> _saveLedOutputs() async {
    if (_deviceIpAddress == null) return;
    setState(() => _savingLedCfg = true);
    try {
      final cfg = await _wledApi.getConfig(_deviceIpAddress!);
      print(
        '[DeviceSettings] Preparing to save LED outputs to $_deviceIpAddress',
      );
      cfg['leds'] ??= {};
      final ledsRaw = cfg['leds'];
      final Map<String, dynamic> leds = ledsRaw is Map
          ? Map<String, dynamic>.from(ledsRaw)
          : <String, dynamic>{};
      final List oldLedsIns = (leds['ins'] is List)
          ? List.from(leds['ins'] as List)
          : <dynamic>[];

      final List<Map<String, dynamic>> newLedsIns = [];
      for (int i = 0; i < _ledOutputs.length; i++) {
        final o = _ledOutputs[i];
        final Map<String, dynamic> base =
            (i < oldLedsIns.length && oldLedsIns[i] is Map)
            ? Map<String, dynamic>.from(oldLedsIns[i] as Map)
            : <String, dynamic>{};
        base['pin'] = [o.gpio];
        base['start'] = o.start; // user-defined start
        base['len'] = o.length;
        base['rev'] = o.reversed == true;
        base['skip'] = o.skip;
        // Enforce uniform properties
        base['type'] = 30; // LED type
        base['ledma'] = 42; // mA per LED
        base['order'] = 1; // color order
        newLedsIns.add(base);
      }
      leds['ins'] = newLedsIns;
      cfg['leds'] = leds;

      // Mirror to newer hw.led.ins while preserving extra keys like type/order/ledma
      cfg['hw'] ??= {};
      final hwRaw = cfg['hw'];
      final Map<String, dynamic> hw = hwRaw is Map
          ? Map<String, dynamic>.from(hwRaw)
          : <String, dynamic>{};
      hw['led'] ??= {};
      final hwLedRaw = hw['led'];
      final Map<String, dynamic> hwLed = hwLedRaw is Map
          ? Map<String, dynamic>.from(hwLedRaw)
          : <String, dynamic>{};
      final List oldHwIns = (hwLed['ins'] is List)
          ? List.from(hwLed['ins'] as List)
          : <dynamic>[];
      final List<Map<String, dynamic>> newHwIns = [];
      int total = 0;
      for (int i = 0; i < _ledOutputs.length; i++) {
        final o = _ledOutputs[i];
        final Map<String, dynamic> base =
            (i < oldHwIns.length && oldHwIns[i] is Map)
            ? Map<String, dynamic>.from(oldHwIns[i] as Map)
            : <String, dynamic>{};
        base['pin'] = [o.gpio];
        base['start'] = o.start; // user-defined start
        base['len'] = o.length;
        base['rev'] = o.reversed == true;
        base['skip'] = o.skip;
        // Enforce uniform properties
        base['type'] = 30;
        base['ledma'] = 42;
        base['order'] = 1;
        newHwIns.add(base);
        total += o.length;
      }
      hwLed['ins'] = newHwIns;
      hwLed['total'] = total;
      // Apply limiter settings: maxpwr=0 disables
      final bool limiterOn = _limitEnabled == true && (_limitMaxMa ?? 0) > 0;
      hwLed['ld'] = limiterOn;
      hwLed['maxpwr'] = limiterOn ? _limitMaxMa : 0;
      hw['led'] = hwLed;
      cfg['hw'] = hw;

      print('[DeviceSettings] New leds.ins=$newLedsIns');
      print('[DeviceSettings] New hw.led.ins=$newHwIns, total=$total');
      await _wledApi.updateConfig(_deviceIpAddress!, cfg);
      print('[DeviceSettings] POST /json/cfg sent');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('LED outputs saved')));
      await _fetchFullJson();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save LED outputs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingLedCfg = false);
    }
  }

  List<String> _orderedKeys(Map<String, dynamic> json) {
    const preferred = [
      'info',
      'state',
      'leds',
      'presets',
      'effects',
      'palettes',
    ];
    final keys = json.keys.toList();
    keys.sort((a, b) {
      final ia = preferred.indexOf(a);
      final ib = preferred.indexOf(b);
      if (ia != -1 && ib != -1) return ia.compareTo(ib);
      if (ia != -1) return -1;
      if (ib != -1) return 1;
      return a.compareTo(b);
    });
    return keys;
  }

  String _pretty(dynamic value) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(value);
  }

  String _displayName(String key) {
    switch (key) {
      case 'info':
        return 'Info';
      case 'state':
        return 'State';
      case 'leds':
        return 'LEDs';
      case 'presets':
        return 'Presets';
      case 'effects':
        return 'Effects';
      case 'palettes':
        return 'Palettes';
      default:
        if (key.isEmpty) return 'Section';
        return key[0].toUpperCase() + key.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2526),
      appBar: AppBar(
        title: const Text('Device Settings'),
        backgroundColor: const Color(0xFF2D3436),
        actions: [
          if (_isDeviceOnline)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchFullJson,
              tooltip: 'Refresh JSON',
            ),
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
                    'This screen requires a local network connection to the device.\nPlease connect to the same WiFi network as your WLED device.',
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
          if (_isDeviceOnline)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    color: const Color(0xFF2D3436),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Hardware setup',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (_savingLedCfg)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                ElevatedButton(
                                  onPressed: _ledOutputs.isEmpty
                                      ? null
                                      : _saveLedOutputs,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                  child: const Text(
                                    'Save',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Brightness limiter
                          Row(
                            children: [
                              const Text(
                                'PSU:',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value:
                                    (_limitMaxMa == 14500 ||
                                        _limitMaxMa == 24000 ||
                                        _limitMaxMa == 65000)
                                    ? _limitMaxMa
                                    : 65000,
                                dropdownColor: const Color(0xFF2D3436),
                                items: const [
                                  DropdownMenuItem(
                                    value: 65000,
                                    child: Text(
                                      'Other (disabled)',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 14500,
                                    child: Text(
                                      '350W (14500 mA)',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 24000,
                                    child: Text(
                                      '600W (24000 mA)',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _limitEnabled = true;
                                    _limitMaxMa = v;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          const SizedBox(height: 8),
                          if (_loadingLedCfg)
                            Row(
                              children: const [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Loading LED outputs...',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            )
                          else ...[
                            for (int i = 0; i < _ledOutputs.length; i++) ...[
                              _LedOutputEditor(
                                index: i,
                                output: _ledOutputs[i],
                                prevCumLen: i > 0
                                    ? _ledOutputs
                                          .take(i)
                                          .fold<int>(
                                            0,
                                            (sum, e) => sum + e.length,
                                          )
                                    : 0,
                                onChanged: (o) =>
                                    setState(() => _ledOutputs[i] = o),
                                onRemove: _ledOutputs.length > 1
                                    ? () => setState(
                                        () => _ledOutputs.removeAt(i),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _ledOutputs.add(
                                        _LedOutput(
                                          gpio: 16,
                                          start: 0,
                                          length: 0,
                                          reversed: false,
                                          skip: 0,
                                        ),
                                      );
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Colors.white70,
                                  ),
                                  tooltip: 'Add LED output',
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Card(
                    color: const Color(0xFF2D3436),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        widget.device.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'IP: ${_deviceIpAddress ?? 'Unknown'}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Update Firmware',
                            icon: const Icon(
                              Icons.system_update_alt,
                              color: Colors.white,
                            ),
                            onPressed: _isDeviceOnline
                                ? () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: const Color(0xFF2D3436),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                      ),
                                      builder: (ctx) {
                                        return DraggableScrollableSheet(
                                          expand: false,
                                          initialChildSize: 0.6,
                                          minChildSize: 0.4,
                                          maxChildSize: 0.95,
                                          builder: (context, scrollController) {
                                            return Padding(
                                              padding: EdgeInsets.only(
                                                bottom: MediaQuery.of(
                                                  context,
                                                ).viewInsets.bottom,
                                              ),
                                              child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: FirmwareUpdateDrawer(
                                                  device: widget.device,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isLoadingJson) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Loading device JSON...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ] else if (_jsonError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Failed to load JSON: $_jsonError',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ] else if (_fullJson != null) ...[
                    // Copy all JSON
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _pretty(_fullJson)),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied full JSON to clipboard'),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.copy,
                          color: Colors.white70,
                          size: 18,
                        ),
                        label: const Text(
                          'Copy All',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._orderedKeys(_fullJson!).map((key) {
                      final value = _fullJson![key];
                      final display = _pretty(value);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          color: const Color(0xFF2D3436),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _displayName(key),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: display),
                                        );
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Copied ${_displayName(key)} JSON',
                                            ),
                                          ),
                                        );
                                      },
                                      tooltip: 'Copy ${_displayName(key)}',
                                      icon: const Icon(
                                        Icons.copy,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E2526),
                                    border: Border.all(color: Colors.white12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: SelectableText(
                                    display,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
