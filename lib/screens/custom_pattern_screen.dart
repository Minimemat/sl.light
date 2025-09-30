import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/device.dart';
import '../widgets/swiftui_color_picker.dart';
import '../services/wp_preset_service.dart';
import '../services/storage_service.dart';
import '../models/preset.dart' as wp;
import '../widgets/preset_card.dart';
import '../blocs/device_bloc.dart';
import '../data/effects_database.dart';
import '../services/mqtt_service.dart';

class CustomPatternScreen extends StatefulWidget {
  final Device device;
  final int ledCount;

  const CustomPatternScreen({
    super.key,
    required this.device,
    this.ledCount = 1000,
  });

  @override
  State<CustomPatternScreen> createState() => _CustomPatternScreenState();
}

class _CustomPatternScreenState extends State<CustomPatternScreen> {
  final List<Color> _colors = [
    Colors.red,
    Colors.orange,
    Colors.white,
    Colors.blue,
  ];

  int _selectedEffect = 0;
  final WPPresetService _wpPresetService = WPPresetService();
  final StorageService _storage = StorageService();
  List<wp.Preset> _presets = [];
  bool _loadingPresets = false;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickColor(int index) async {
    final initial = _colors[index];
    final result = await showDialog<Color>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: Center(
            child: SwiftUIColorPicker(
              initialColor: initial,
              onColorChanged: (_) {},
              showOpacity: false,
            ),
          ),
        );
      },
    );
    if (result != null) {
      setState(() {
        _colors[index] = result;
        _presets = _presets.map((e) => e.copyWith(isSelected: false)).toList();
      });
    }
  }

  void _addColor() {
    if (_colors.length >= 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 16 colors reached')),
      );
      return;
    }
    setState(() {
      _colors.add(Colors.grey);
      _presets = _presets.map((e) => e.copyWith(isSelected: false)).toList();
    });
  }

  void _removeColor() {
    if (_colors.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Minimum 1 color required')));
      return;
    }
    setState(() {
      _colors.removeLast();
      _presets = _presets.map((e) => e.copyWith(isSelected: false)).toList();
    });
  }

  List<int> _toRgb(Color c) => [c.red, c.green, c.blue, 0];

  Map<String, dynamic> _buildSettingsFromColors() {
    // Get current device brightness from DeviceBloc state
    final blocState = context.read<DeviceBloc>().state;
    final currentDevice = blocState is DeviceLoaded
        ? blocState.devices.firstWhere(
            (d) => d.id == widget.device.id,
            orElse: () => widget.device,
          )
        : widget.device;
    final brightness = currentDevice.brightness;
    final int count = _colors.length;
    final int spacing = count > 1 ? count - 1 : 0;

    // Active segments (one per color)
    final activeSegments = List.generate(
      count,
      (i) => {
        'id': i,
        'start': i,
        'stop': widget.ledCount,
        'grp': 1,
        'spc': spacing, // All segments use same spacing = numColors-1
        'of': 0,
        'on': true,
        'frz': false,
        'bri': 255,
        'cct': 127,
        'set': 0,
        'n': '',
        'col': [
          _toRgb(_colors[i]),
          [0, 0, 0],
          [0, 0, 0],
        ], // Each segment has its color + black backgrounds
        'fx': _selectedEffect,
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
      },
    );

    // Empty segments to fill the array
    final emptySegments = List.generate(28 - count, (i) => {'stop': 0});

    return {
      'on': true,
      'bri': brightness,
      'transition': 7,
      'mainseg': 0,
      'seg': [...activeSegments, ...emptySegments],
    };
  }

  Future<void> _apply() async {
    try {
      final settings = _buildSettingsFromColors();
      debugPrint(
        'Applying custom pattern: ${_colors.length} segments (interleaved), spacing ${settings['seg'][0]['spc']}',
      );

      // Send command via MQTT
      final mqttService = DeviceMqttService(widget.device);
      await mqttService.connect();

      // Wait for connection
      int waitCount = 0;
      while (!mqttService.isConnected && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }

      if (!mqttService.isConnected) {
        throw Exception('Failed to connect to device');
      }

      mqttService.sendCommand(settings);
      debugPrint(
        'Custom pattern applied successfully to ${widget.device.name}',
      );

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pattern applied to ${widget.device.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error applying custom pattern: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply pattern: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final user = await _storage.loadUser();
    final jwt = user?.jwtToken;
    if (jwt == null || jwt.isEmpty) {
      return; // not logged in; silently skip
    }

    // Determine if updating an existing selected preset
    wp.Preset? selected;
    for (final p in _presets) {
      if (p.isSelected) {
        selected = p;
        break;
      }
    }

    final hexColors = _colorsToHex(_colors);

    try {
      if (selected != null && selected.id != null) {
        final name = await _promptPresetName(initialName: selected.name);
        if (name == null) return;
        // Update existing preset, ensure it is tagged correctly
        final ensureCategories = selected.categories.contains('Custom Pattern')
            ? selected.categories
            : [...selected.categories, 'Custom Pattern'];
        final toUpdate = selected.copyWith(
          name: name,
          fx: _selectedEffect,
          colors: hexColors,
          categories: ensureCategories,
          iconName: selected.iconName ?? 'pattern',
          status: selected.status ?? 'private',
        );
        final saved = await _wpPresetService.updatePreset(jwt, toUpdate);

        // Update local list and selection
        setState(() {
          _presets = _presets
              .map(
                (e) => e.id == saved.id
                    ? saved.copyWith(isSelected: true)
                    : e.copyWith(isSelected: false),
              )
              .toList();
          _selectedEffect = saved.fx;
          _colors
            ..clear()
            ..addAll(_colorsFromPreset(saved));
        });
      } else {
        final name = await _promptPresetName(initialName: 'Custom Pattern');
        if (name == null) return;
        // Create new preset with required tagging
        final newPreset = wp.Preset(
          name: name,
          description: '',
          icon: Icons.pattern,
          categories: const ['Custom Pattern'],
          fx: _selectedEffect,
          colors: hexColors,
          status: 'private',
          iconName: 'pattern',
          on: true,
          mainseg: 0,
        );
        final saved = await _wpPresetService.createPreset(jwt, newPreset);

        // Add to local list and select
        setState(() {
          final savedSel = saved.copyWith(isSelected: true);
          _presets = [
            savedSel,
            ..._presets.map((e) => e.copyWith(isSelected: false)),
          ];
          _selectedEffect = saved.fx;
          _colors
            ..clear()
            ..addAll(_colorsFromPreset(saved));
        });
      }
    } catch (_) {
      // Silent failure per design
    }
  }

  Future<void> _loadPresets() async {
    setState(() {
      _loadingPresets = true;
    });
    try {
      final user = await _storage.loadUser();
      final jwt = user?.jwtToken;
      final list = await _wpPresetService.getPresets(jwt: jwt);
      final customPatternPresets = list
          .where((p) => p.categories.contains('Custom Pattern'))
          .toList();
      setState(() {
        _presets = customPatternPresets;
      });
    } catch (_) {}
    if (mounted) {
      setState(() {
        _loadingPresets = false;
      });
    }
  }

  // Convert preset hex color strings to Flutter Colors
  List<Color> _colorsFromPreset(wp.Preset p) {
    if (p.colors == null || p.colors!.isEmpty) return _colors;
    final parsed = <Color>[];
    for (final s in p.colors!) {
      final hex = s.replaceAll('#', '');
      final safe = hex.length == 6 ? 'FF$hex' : hex.padLeft(8, 'F');
      try {
        parsed.add(Color(int.parse(safe, radix: 16)));
      } catch (_) {}
    }
    return parsed.isEmpty ? _colors : parsed;
  }

  // Convert current colors to hex strings without '#', e.g., 'RRGGBB'
  List<String> _colorsToHex(List<Color> colors) {
    return colors
        .map(
          (c) => c.value
              .toRadixString(16)
              .padLeft(8, '0')
              .substring(2)
              .toUpperCase(),
        )
        .toList();
  }

  void _selectPreset(wp.Preset p) {
    setState(() {
      _selectedEffect = p.fx;
      _colors
        ..clear()
        ..addAll(_colorsFromPreset(p));
      // Update visual selection on cards
      _presets = _presets
          .map((e) => e.copyWith(isSelected: e.id == p.id))
          .toList();
    });
  }

  Future<String?> _promptPresetName({String? initialName}) async {
    final controller = TextEditingController(text: initialName ?? '');
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D3436),
          title: const Text(
            'Preset Name',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter a name',
              hintStyle: TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    return (name != null && name.isNotEmpty) ? name : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2526),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D3436),
        title: const Text('Custom Pattern'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF2D3436),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _removeColor,
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.white70,
                      ),
                      tooltip: 'Remove Color',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${_colors.length} Color${_colors.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _addColor,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white70,
                      ),
                      tooltip: 'Add Color',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF2D3436),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: List.generate(_colors.length, (index) {
                    final color = _colors[index];
                    return GestureDetector(
                      onTap: () => _pickColor(index),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(
                                color: Colors.black54,
                                width: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Effects dropdown
            Card(
              color: const Color(0xFF2D3436),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Effect',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2526),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedEffect,
                          dropdownColor: const Color(0xFF2D3436),
                          style: const TextStyle(color: Colors.white),
                          items: EffectsDatabase.effectsDatabase.map((effect) {
                            return DropdownMenuItem<int>(
                              value: effect['id'] as int,
                              child: Text(
                                effect['name'] as String,
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedEffect = value;
                                _presets = _presets
                                    .map((e) => e.copyWith(isSelected: false))
                                    .toList();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.check),
                    label: const Text('Apply'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Presets list shown at the bottom
            if (_loadingPresets)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              const Text(
                'Presets',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _presets.length,
                itemBuilder: (context, index) {
                  final p = _presets[index];
                  return PresetCard(preset: p, onTap: () => _selectPreset(p));
                },
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
