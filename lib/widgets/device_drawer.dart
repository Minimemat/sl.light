import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/device.dart';
import '../services/mqtt_service.dart';
import '../services/wp_preset_service.dart';
import '../models/preset.dart';
import '../data/effects_database.dart';
import '../data/palettes_database.dart';
import '../screens/custom_pattern_screen.dart';
import 'color_dots_display.dart';
import 'swiftui_color_picker.dart';
import '../blocs/auth_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/device_bloc.dart';

class DeviceDrawer extends StatefulWidget {
  final Device device;
  final DeviceMqttService? mqttService;
  final Preset? selectedPreset;
  final VoidCallback onSettingsModified;
  final Map<String, dynamic>? currentState;

  // Global key to access the drawer state
  static final GlobalKey<_DeviceDrawerState> globalKey =
      GlobalKey<_DeviceDrawerState>();

  DeviceDrawer({
    required this.device,
    this.mqttService,
    required this.selectedPreset,
    required this.onSettingsModified,
    this.currentState,
  }) : super(key: globalKey);

  @override
  State<DeviceDrawer> createState() => _DeviceDrawerState();
}

class _DeviceDrawerState extends State<DeviceDrawer> {
  // Remove local state for device fields (colors, effect, palette, etc.)
  // Only keep UI-only state if needed (e.g., expansion, drag, timers)
  bool _isCardExpanded = false;
  final WPPresetService _wpPresetService = WPPresetService();

  // Local color storage for the third color (not synced via MQTT)
  List<int> _localColors = [
    0, 0, 0, // First color: black (will be loaded from storage/device)
    0, 0, 0, // Second color: black (will be loaded from storage)
    0, 0, 0, // Third color: black (will be loaded from storage)
  ]; // Default: white, white, black

  // Local storage for option values (o1, o2, o3) since WLED /v doesn't return them
  Map<String, bool> _localOptions = {'o1': false, 'o2': false, 'o3': false};

  // Local storage for custom parameter values (c1, c2, c3) since WLED /v doesn't return them reliably
  Map<String, int> _localCustoms = {'c1': 128, 'c2': 128, 'c3': 16};

  // Local state for current device settings
  int _currentEffect = 0;
  int _currentPalette = 0;
  int _currentSpeed = 128;
  int _currentIntensity = 128;
  bool _currentPower = false;
  int _currentBrightness = 0;

  // Method to update local state from preset selection
  void updateFromPreset(Preset preset) {
    print('🔧 DEVICE DRAWER: Updating from preset: ${preset.name}');
    // Build state from preset while preserving unspecified fields
    final device = context.read<DeviceBloc>().state is DeviceLoaded
        ? (context.read<DeviceBloc>().state as DeviceLoaded).devices.firstWhere(
            (d) => d.id == widget.device.id,
            orElse: () => widget.device,
          )
        : widget.device;
    // Colors from preset (hex -> rgb) - start with current device colors
    List<List<int>> colors = List.generate(3, (i) {
      if (i < device.colors.length) {
        return List<int>.from(device.colors[i]);
      }
      return [0, 0, 0]; // Default to black for missing colors
    });

    // Apply preset colors if available
    if (preset.colors != null && preset.colors!.isNotEmpty) {
      for (int i = 0; i < preset.colors!.length && i < 3; i++) {
        final rgb = _hexToRgb(preset.colors![i]);
        colors[i] = [rgb[0], rgb[1], rgb[2]];
      }
    }

    // Update local state variables
    setState(() {
      _currentEffect = preset.fx;
      _currentPalette = preset.paletteId ?? device.palette;
      _currentSpeed = preset.sx ?? device.speed;
      _currentIntensity = preset.ix ?? device.intensity;

      // Update local colors array
      if (preset.colors != null && preset.colors!.isNotEmpty) {
        for (int i = 0; i < preset.colors!.length && i < 3; i++) {
          final rgb = _hexToRgb(preset.colors![i]);
          final startIndex = i * 3;
          if (startIndex + 2 < _localColors.length) {
            _localColors[startIndex] = rgb[0];
            _localColors[startIndex + 1] = rgb[1];
            _localColors[startIndex + 2] = rgb[2];
          }
        }
      }
    });

    final state = {
      'fx': preset.fx,
      'sx': preset.sx ?? device.speed,
      'ix': preset.ix ?? device.intensity,
      'pal': preset.paletteId ?? device.palette,
      'colors': colors
          .expand((color) => color)
          .toList(), // Flatten to [R,G,B,R,G,B,R,G,B]
      if (preset.c1 != null) 'c1': preset.c1,
      if (preset.c2 != null) 'c2': preset.c2,
      if (preset.c3 != null) 'c3': preset.c3,
      if (preset.o1 != null) 'o1': preset.o1,
      if (preset.o2 != null) 'o2': preset.o2,
      if (preset.o3 != null) 'o3': preset.o3,
    };

    // Update BLoC so drawer reflects preset immediately (no MQTT send here)
    try {
      context.read<DeviceBloc>().add(
        UpdateDeviceStateFromMqtt(widget.device.id, state),
      );
    } catch (_) {}

    // After applying preset, reset baseline and unsaved flag
    _captureInitialState();
    setState(() {
      _hasUnsavedChanges = false;
    });
    // Ensure baseline reflects BLoC-updated values after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _captureInitialState();
      setState(() {
        _hasUnsavedChanges = false;
      });
    });
    // This is just a UI state update from preset selection
    print(
      '🔧 DEVICE DRAWER: Preset applied to local state only - no commands sent',
    );
  }

  List<int> _hexToRgb(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      final r = int.parse(hex.substring(0, 2), radix: 16);
      final g = int.parse(hex.substring(2, 4), radix: 16);
      final b = int.parse(hex.substring(4, 6), radix: 16);
      return [r, g, b];
    }
    return [255, 255, 255];
  }

  // Generate effect + palette name for preset
  String _generatePresetName() {
    final effect = _getEffectById(_currentEffect);
    final effectName = effect['name'] as String? ?? 'Unknown';

    final palette = _getPaletteById(
      _currentPalette,
      PalettesDatabase.palettesDatabase,
    );
    final paletteName = palette['name'] as String? ?? 'Unknown';

    return '$effectName + $paletteName';
  }

  // Command queuing and debouncing
  Timer? _debounceTimer;

  // Additional protection against rapid changes

  // Preset saving state
  bool _hasUnsavedChanges = false;
  Map<String, dynamic>? _initialState;
  bool _isSaving = false;

  // Phase 1: Local dragging state for smooth slider interaction
  final Map<String, double?> _draggingValues = {};
  bool _isDragging = false;

  // Phase 5: Batched storage operations
  Timer? _storageTimer;

  // MQTT update control
  Timer? _mqttUpdateDelay;

  @override
  void initState() {
    super.initState();
    // Capture initial state from the incoming device so we can detect changes
    try {
      final c0 = widget.device.colors.isNotEmpty
          ? widget.device.colors[0]
          : const [255, 255, 255];
      final c1 = widget.device.colors.length > 1
          ? widget.device.colors[1]
          : const [
              0,
              0,
              0,
            ]; // Don't default to white, let storage load the real colors
      final c2 = widget.device.colors.length > 2
          ? widget.device.colors[2]
          : const [
              0,
              0,
              0,
            ]; // Don't default to white, let storage load the real colors
      _localColors = [
        c0[0],
        c0[1],
        c0[2],
        c1[0],
        c1[1],
        c1[2],
        c2[0],
        c2[1],
        c2[2],
      ];
      _currentEffect = widget.device.effect;
      _currentPalette = widget.device.palette;
      _currentSpeed = widget.device.speed;
      _currentIntensity = widget.device.intensity;
      _captureInitialState();
    } catch (_) {}
  }

  @override
  void didUpdateWidget(DeviceDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if selectedPreset has changed
    if (widget.selectedPreset != oldWidget.selectedPreset &&
        widget.selectedPreset != null) {
      print('🔧 DEVICE DRAWER: Selected preset changed, updating local state');
      updateFromPreset(widget.selectedPreset!);
    }
  }

  // Helper function to decode HTML entities
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rdquo;', '"')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&#215;', '×')
        .replaceAll('&#8211;', '–')
        .replaceAll('&#8212;', '—')
        .replaceAll('&nbsp;', ' ')
        .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
          final code = int.tryParse(match.group(1)!);
          return code != null ? String.fromCharCode(code) : match.group(0)!;
        });
  }

  void _captureInitialState() {
    // Use current device from BLoC as source of truth
    final device = context.read<DeviceBloc>().state is DeviceLoaded
        ? (context.read<DeviceBloc>().state as DeviceLoaded).devices.firstWhere(
            (d) => d.id == widget.device.id,
            orElse: () => widget.device,
          )
        : widget.device;

    // Flatten colors to 9 ints from device state
    final List<List<int>> dcolors = device.colors;
    final List<int> flatColors = <int>[
      if (dcolors.isNotEmpty) ...dcolors[0] else ...[255, 255, 255],
      if (dcolors.length > 1) ...dcolors[1] else ...[255, 255, 255],
      if (dcolors.length > 2) ...dcolors[2] else ...[0, 0, 0],
    ];

    // Options and customs from device with local fallbacks
    final Map<String, bool> options = {
      'o1': device.options['o1'] ?? _localOptions['o1'] ?? false,
      'o2': device.options['o2'] ?? _localOptions['o2'] ?? false,
      'o3': device.options['o3'] ?? _localOptions['o3'] ?? false,
    };
    final Map<String, int> customs = {
      'c1': device.customs['c1'] ?? _localCustoms['c1'] ?? 128,
      'c2': device.customs['c2'] ?? _localCustoms['c2'] ?? 128,
      'c3': device.customs['c3'] ?? _localCustoms['c3'] ?? 16,
    };

    _initialState = {
      'colors': flatColors,
      'fx': device.effect,
      'pal': device.palette,
      'sx': device.speed,
      'ix': device.intensity,
      'on': _currentPower,
      'bri': _currentBrightness,
      'o1': options['o1'],
      'o2': options['o2'],
      'o3': options['o3'],
      'c1': customs['c1'],
      'c2': customs['c2'],
      'c3': customs['c3'],
    };
  }

  void _checkForChanges() {
    if (_initialState == null) return;

    // Read latest device state from BLoC
    final device = context.read<DeviceBloc>().state is DeviceLoaded
        ? (context.read<DeviceBloc>().state as DeviceLoaded).devices.firstWhere(
            (d) => d.id == widget.device.id,
            orElse: () => widget.device,
          )
        : widget.device;

    // Build flattened colors (9 ints) from device
    final List<List<int>> dcolors = device.colors;
    final List<int> currentColors = <int>[
      if (dcolors.isNotEmpty) ...dcolors[0] else ...[255, 255, 255],
      if (dcolors.length > 1) ...dcolors[1] else ...[255, 255, 255],
      if (dcolors.length > 2) ...dcolors[2] else ...[0, 0, 0],
    ];

    bool hasChanges = false;

    // Check colors
    final initialColors = List<int>.from(_initialState!['colors'] as List<int>);
    if (!_listEquals(initialColors, currentColors)) {
      hasChanges = true;
    }

    // Check other settings against initial state
    if (_initialState!['fx'] != device.effect ||
        _initialState!['pal'] != device.palette ||
        _initialState!['sx'] != device.speed ||
        _initialState!['ix'] != device.intensity) {
      hasChanges = true;
    }

    if (_hasUnsavedChanges != hasChanges) {
      final wasUnsaved = _hasUnsavedChanges;
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
      if (!wasUnsaved && hasChanges) {
        // First change detected since last reset/save: inform parent to clear selected preset
        try {
          widget.onSettingsModified();
        } catch (_) {}
      }
    }
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _showSavePresetDialog() async {
    final TextEditingController nameController = TextEditingController(
      text: _generatePresetName(),
    );

    // Available categories (excluding "All" and "Deleted")
    final availableCategories = [
      'Architectural',
      'Canada',
      'Christmas',
      'Diwali',
      'Easter',
      'Events',
      'Fall',
      'Halloween',
      'Ramadan',
      'Spring',
      'Sports',
      'St. Patrick\'s',
      'Summer',
      'Valentines',
      'Winter',
      'Other',
    ];

    // Track selected categories
    final selectedCategories = <String>{'Other'}; // Default to "Other"

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Save Preset'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Enter a name for your preset:'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Preset name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text('Select categories:'),
                        const Spacer(),
                        Text(
                          '${availableCategories.length} options',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            child: Column(
                              children: availableCategories.map((category) {
                                final isSelected = selectedCategories.contains(
                                  category,
                                );
                                return CheckboxListTile(
                                  title: Text(category),
                                  value: isSelected,
                                  onChanged: (selected) {
                                    setDialogState(() {
                                      if (selected == true) {
                                        selectedCategories.add(category);
                                      } else {
                                        selectedCategories.remove(category);
                                      }
                                    });
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                );
                              }).toList(),
                            ),
                          ),
                          // Scroll indicator at bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 20,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0),
                                    Colors.white.withOpacity(0.8),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey[600],
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty && selectedCategories.isNotEmpty) {
                      Navigator.of(context).pop({
                        'name': name,
                        'categories': selectedCategories.toList(),
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _savePreset(result['name'], result['categories']);
    }
  }

  Future<void> _savePreset(String name, List<String> categories) async {
    try {
      setState(() {
        _isSaving = true;
      });

      // Get JWT token from auth bloc
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save presets')),
        );
        return;
      }

      final jwt = authState.user.jwtToken;
      if (jwt.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token not found')),
        );
        return;
      }

      // Read latest device from BLoC as source of truth
      final dev = context.read<DeviceBloc>().state is DeviceLoaded
          ? (context.read<DeviceBloc>().state as DeviceLoaded).devices
                .firstWhere(
                  (d) => d.id == widget.device.id,
                  orElse: () => widget.device,
                )
          : widget.device;

      // Convert device colors to hex strings (pad to 3 colors)
      final List<List<int>> devColors = dev.colors;
      final List<List<int>> padded = [
        if (devColors.isNotEmpty) devColors[0] else [255, 255, 255],
        if (devColors.length > 1) devColors[1] else [255, 255, 255],
        if (devColors.length > 2) devColors[2] else [0, 0, 0],
      ];
      List<String> colorsHex = padded.map((rgb) {
        final r = rgb[0].toRadixString(16).padLeft(2, '0').toUpperCase();
        final g = rgb[1].toRadixString(16).padLeft(2, '0').toUpperCase();
        final b = rgb[2].toRadixString(16).padLeft(2, '0').toUpperCase();
        return '$r$g$b';
      }).toList();

      // Create preset from current device state
      final preset = Preset(
        name: name,
        description: 'Custom preset created on device',
        icon: Icons.lightbulb,
        fx: dev.effect,
        paletteId: dev.palette,
        sx: dev.speed,
        ix: dev.intensity,
        c1: dev.customs['c1'] ?? _localCustoms['c1'] ?? 128,
        c2: dev.customs['c2'] ?? _localCustoms['c2'] ?? 128,
        c3: dev.customs['c3'] ?? _localCustoms['c3'] ?? 16,
        o1: dev.options['o1'] ?? _localOptions['o1'] ?? false,
        o2: dev.options['o2'] ?? _localOptions['o2'] ?? false,
        o3: dev.options['o3'] ?? _localOptions['o3'] ?? false,
        colors: colorsHex,
        categories: categories,
        status: 'private', // Default to private
        iconName: 'lightbulb', // Default icon
        on: _currentPower,
        mainseg: 0,
      );

      await _wpPresetService.createPreset(jwt, preset);

      // Reset change tracking
      _captureInitialState();
      _checkForChanges();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preset "$name" saved successfully!')),
      );

      // Notify parent to refresh preset list
      widget.onSettingsModified();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save preset: $e')));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _storageTimer?.cancel();
    _mqttUpdateDelay?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _getEffectById(int fxId) {
    return EffectsDatabase.effectsDatabase.firstWhere(
      (e) => e['id'] == fxId,
      orElse: () => {
        'name': 'Unknown',
        'flags': [],
        'colors': [],
        'parameters': [],
      },
    );
  }

  Map<String, dynamic> _getPaletteById(
    int paletteId,
    List<Map<String, dynamic>> palettes,
  ) {
    return palettes.firstWhere(
      (p) => p['id'] == paletteId,
      orElse: () => {'name': 'Unknown', 'colors': []},
    );
  }

  // Determine which device key a numeric effect parameter should control
  // Prefer name-based mapping; fall back to index-based c1/c2/c3
  String _mapNumericParamToKey(String paramLabel, int numericIndex) {
    final label = paramLabel.toLowerCase();
    // Explicit label mappings
    if (label.contains('foreground') || label.contains('fg')) return 'sx';
    if (label.contains('background') || label.contains('bg')) return 'ix';
    if (label.contains('intensity') || label == 'ix') return 'ix';
    if (label.contains('speed') || label == 'sx') {
      // If multiple speed-like params exist (e.g., Blends: Shift speed, Blend speed),
      // map the first to SX and the second to IX for UI clarity
      if (numericIndex == 0) return 'sx';
      if (numericIndex == 1) return 'ix';
      // further speeds fall through to fallback by position
    }
    if (label.contains('size')) {
      return 'ix'; // e.g., Solid Pattern Tri -> IX only
    }
    if (label.contains('custom1') || label == 'c1') return 'c1';
    if (label.contains('custom2') || label == 'c2') return 'c2';
    if (label.contains('custom3') || label == 'c3') return 'c3';
    // Fallback by position
    if (numericIndex == 0) return 'sx';
    if (numericIndex == 1) return 'ix';
    if (numericIndex == 2) return 'c1';
    if (numericIndex == 3) return 'c2';
    if (numericIndex == 4) return 'c3';
    return 'c1';
  }

  // Helper to determine text color based on background luminance
  Color _getTextColorForBackground(Color bgColor) {
    final luminance =
        (0.299 * bgColor.red + 0.587 * bgColor.green + 0.114 * bgColor.blue) /
        255;
    return luminance > 0.5 ? Colors.grey[900]! : Colors.white;
  }

  Future<void> _sendApiCommand(Map<String, dynamic> command) async {
    print('🔧 DEVICE DRAWER: Sending command: $command');
    if (widget.mqttService == null) {
      print(
        '🔧 DEVICE DRAWER: MQTT service not available, skipping command: $command',
      );
      return;
    }
    try {
      // Build current segment from BLoC device state
      final dev = context.read<DeviceBloc>().state is DeviceLoaded
          ? (context.read<DeviceBloc>().state as DeviceLoaded).devices
                .firstWhere(
                  (d) => d.id == widget.device.id,
                  orElse: () => widget.device,
                )
          : widget.device;
      final devColors = dev.colors;
      List<List<int>> col = [
        (devColors.isNotEmpty ? devColors[0] : [255, 255, 255]),
        (devColors.length > 1 ? devColors[1] : [255, 255, 255]),
        (devColors.length > 2 ? devColors[2] : [0, 0, 0]),
      ].map((rgb) => [rgb[0], rgb[1], rgb[2], 0]).toList();

      final seg = <String, dynamic>{'id': 0, 'col': col, 'mi': false};

      // Apply seg-level overrides only if present and non-null to avoid unintentionally resetting values
      const segKeys = {
        'fx',
        'pal',
        'sx',
        'ix',
        'o1',
        'o2',
        'o3',
        'c1',
        'c2',
        'c3',
      };
      for (final entry in command.entries) {
        if (segKeys.contains(entry.key) && entry.value != null) {
          seg[entry.key] = entry.value;
        }
      }

      final payload = <String, dynamic>{
        'mainseg': 0,
        'seg': [seg],
      };

      print(
        '🔧 DEVICE DRAWER: Sending JSON command via mqttService.sendCommand: $payload',
      );
      widget.mqttService?.sendCommand(payload);
      print('🔧 DEVICE DRAWER: Command sent successfully');
    } catch (e) {
      print('Failed to send API command: $e');
    }
  }

  Future<void> _updateColor(int colorIndex, Color newColor) async {
    print(
      '🔧 DEVICE DRAWER: Updating color $colorIndex to ${newColor.toString()}',
    );
    // Build new colors array from current device colors and local storage
    final colors = <List<int>>[];

    // Use local colors as the source of truth, converted back to nested format
    for (int i = 0; i < 3; i++) {
      final startIndex = i * 3;
      if (startIndex + 2 < _localColors.length) {
        colors.add([
          _localColors[startIndex],
          _localColors[startIndex + 1],
          _localColors[startIndex + 2],
        ]);
      } else {
        colors.add([
          0,
          0,
          0,
        ]); // Only add black defaults if absolutely necessary
      }
    }
    colors[colorIndex] = [newColor.red, newColor.green, newColor.blue];

    // Update local colors to match
    _localColors = colors.expand((color) => color).toList();

    // Persist complete device state via BLoC (saves to storage)
    try {
      final completeState = {
        'effect': _currentEffect,
        'palette': _currentPalette,
        'speed': _currentSpeed,
        'intensity': _currentIntensity,
        'power': _currentPower,
        'brightness': _currentBrightness,
        'colors': colors
            .expand((color) => color)
            .toList(), // Flatten to [R,G,B,R,G,B,R,G,B]
        'options': _localOptions,
        'customs': _localCustoms,
      };
      context.read<DeviceBloc>().add(
        UpdateDeviceStateFromMqtt(widget.device.id, completeState),
      );
    } catch (e) {
      print('🔧 DEVICE DRAWER: Error dispatching complete state to BLoC: $e');
    }
    // Immediately clear selected preset in parent
    try {
      if (widget.selectedPreset != null) widget.onSettingsModified();
    } catch (_) {}
    // Enable Save button by checking for changes
    _checkForChanges();
    // Send to device via MQTT with built-in debounce/queue
    if (widget.mqttService != null) {
      try {
        if (!widget.mqttService!.isConnected) {
          await widget.mqttService!.connect();
        }
        final command = {
          'seg': [
            {
              'col': [
                colors[0],
                colors.length > 1 ? colors[1] : [255, 255, 255],
                colors.length > 2 ? colors[2] : [0, 0, 0],
              ],
            },
          ],
        };
        widget.mqttService!.sendCommand(command);
      } catch (e) {
        print('🔧 DEVICE DRAWER: Error sending color command: $e');
      }
    }
    setState(() {});
  }

  Future<void> _showColorPicker(int colorIndex, String colorLabel) async {
    // Read current color from BLoC device state
    final device = context.read<DeviceBloc>().state is DeviceLoaded
        ? (context.read<DeviceBloc>().state as DeviceLoaded).devices.firstWhere(
            (d) => d.id == widget.device.id,
            orElse: () => widget.device,
          )
        : widget.device;
    final currentTriplet =
        device.colors.isNotEmpty && device.colors.length > colorIndex
        ? device.colors[colorIndex]
        : [255, 255, 255];
    final currentColor = Color.fromRGBO(
      currentTriplet[0],
      currentTriplet[1],
      currentTriplet[2],
      1,
    );
    final Color? result = await showDialog<Color>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwiftUIColorPicker(
            initialColor: currentColor,
            onColorChanged: (color) {},
            onCctChanged: (cct) async {
              if (widget.mqttService != null) {
                try {
                  if (!widget.mqttService!.isConnected) {
                    await widget.mqttService!.connect();
                  }
                  widget.mqttService!.sendCommand({
                    'seg': [
                      {'cct': cct},
                    ],
                  });
                } catch (_) {}
              }
            },
          ),
        );
      },
    );
    if (result != null && result != currentColor) {
      await _updateColor(colorIndex, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = context.select<DeviceBloc, Device>((bloc) {
      final state = bloc.state;
      if (state is DeviceLoaded) {
        return state.devices.firstWhere(
          (d) => d.id == widget.device.id,
          orElse: () => widget.device,
        );
      }
      return widget.device;
    });
    // device is non-null due to select with fallback; no need for null guard
    final effectId = device.effect;
    final effect = _getEffectById(effectId);
    final effectName = effect['name'] as String? ?? '';
    final paletteId = device.palette;
    final sx = device.speed;
    final ix = device.intensity;
    final effectColors = (effect['colors'] as List<dynamic>?) ?? [];
    final effectParameters = (effect['parameters'] as List<dynamic>?) ?? [];
    final paddedColors = device.colors;
    final updatedPalettes = PalettesDatabase.updatePalettesWithSelectedColors(
      paddedColors,
    );
    final palette = _getPaletteById(paletteId, updatedPalettes);
    final paletteName = palette['name'] as String? ?? '';
    final paletteColors = palette['colors'] as List<dynamic>? ?? [];
    final bool isCustomPatternSelected =
        widget.selectedPreset != null &&
        widget.selectedPreset!.categories.contains('Custom Pattern');

    // Color swatches logic - use bottom drawer approach for palettes 0-5
    int numColorsToShow;
    List<String> swatchLabels = [];
    List<List<dynamic>> swatchColors = [];

    if ([2, 3, 4, 5].contains(paletteId)) {
      if (paletteId == 2) {
        numColorsToShow = 1;
        swatchLabels = ['Fx'];
        swatchColors = [paddedColors[0]];
      } else if (paletteId == 3) {
        numColorsToShow = 2;
        swatchLabels = ['Fx', 'Bg'];
        swatchColors = [paddedColors[0], paddedColors[1]];
      } else {
        numColorsToShow = 3;
        swatchLabels = ['Fx', 'Bg', 'Cs'];
        swatchColors = [paddedColors[0], paddedColors[1], paddedColors[2]];
      }
    } else {
      numColorsToShow = effectColors.where((c) => c != 'Pal').length;
      swatchLabels = effectColors
          .where((c) => c != 'Pal')
          .toList()
          .cast<String>();
      swatchColors = List.generate(numColorsToShow, (index) {
        final colorIdx =
            {
              'Fx': 0,
              'Bg': 1,
              'Cs': 2,
              '1': 0,
              '2': 1,
              '3': 2,
              'Fg': 0,
            }[swatchLabels[index]] ??
            0;
        return paddedColors[colorIdx];
      });
    }

    final showPaletteGradientInTopBox = paletteId != 0;
    // Always show preset name when selected, fall back to effect + palette when no preset or modified
    final String decodedPresetName = widget.selectedPreset != null
        ? _decodeHtmlEntities(widget.selectedPreset!.name)
        : '';
    String displayName =
        (widget.selectedPreset != null && decodedPresetName.isNotEmpty)
        ? decodedPresetName
        : _decodeHtmlEntities('$effectName + $paletteName');

    // Derive primary color from first palette color or fallback
    final baseColor = paletteColors.isNotEmpty
        ? Color.fromRGBO(
            int.parse(
              paletteColors[0]['color']
                  .replaceAll(RegExp(r'rgb\(|\)'), '')
                  .split(',')[0],
            ),
            int.parse(
              paletteColors[0]['color']
                  .replaceAll(RegExp(r'rgb\(|\)'), '')
                  .split(',')[1],
            ),
            int.parse(
              paletteColors[0]['color']
                  .replaceAll(RegExp(r'rgb\(|\)'), '')
                  .split(',')[2],
            ),
            1,
          )
        : const Color(0xFF2196F3); // Material Blue fallback
    final surfaceColor = const Color(0xFFF5F5F5); // Light surface for contrast
    // final textColor = _getTextColorForBackground(baseColor); // not used

    // Determine which color swatches to show based on effect and palette
    List<Map<String, dynamic>> colorSwatches = [];

    if ([2, 3, 4, 5].contains(paletteId)) {
      // Special palettes with specific color roles
      if (paletteId == 2) {
        colorSwatches = [
          {
            'label': 'Fx',
            'index': 0,
            'color': Color.fromRGBO(
              paddedColors[0][0],
              paddedColors[0][1],
              paddedColors[0][2],
              1,
            ),
          },
        ];
      } else if (paletteId == 3) {
        colorSwatches = [
          {
            'label': 'Fx',
            'index': 0,
            'color': Color.fromRGBO(
              paddedColors[0][0],
              paddedColors[0][1],
              paddedColors[0][2],
              1,
            ),
          },
          {
            'label': 'Bg',
            'index': 1,
            'color': Color.fromRGBO(
              paddedColors[1][0],
              paddedColors[1][1],
              paddedColors[1][2],
              1,
            ),
          },
        ];
      } else {
        colorSwatches = [
          {
            'label': 'Fx',
            'index': 0,
            'color': Color.fromRGBO(
              paddedColors[0][0],
              paddedColors[0][1],
              paddedColors[0][2],
              1,
            ),
          },
          {
            'label': 'Bg',
            'index': 1,
            'color': Color.fromRGBO(
              paddedColors[1][0],
              paddedColors[1][1],
              paddedColors[1][2],
              1,
            ),
          },
          {
            'label': 'Cs',
            'index': 2,
            'color': Color.fromRGBO(
              paddedColors[2][0],
              paddedColors[2][1],
              paddedColors[2][2],
              1,
            ),
          },
        ];
      }
    } else {
      // Standard effect colors
      final filteredEffectColors = effectColors
          .where((c) => c != 'Pal')
          .toList();
      final numColors = filteredEffectColors.length;
      for (int i = 0; i < numColors && i < 3; i++) {
        final colorIndex = i;
        final color = Color.fromRGBO(
          paddedColors[colorIndex][0],
          paddedColors[colorIndex][1],
          paddedColors[colorIndex][2],
          1,
        );
        colorSwatches.add({
          'label': filteredEffectColors[i],
          'index': colorIndex,
          'color': color,
        });
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isCardExpanded ? null : 80,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Use the centralized ColorDotsDisplay for both dots and gradient
                  Builder(
                    builder: (_) {
                      final bool isCustomPatternSelected =
                          widget.selectedPreset != null &&
                          widget.selectedPreset!.categories.contains(
                            'Custom Pattern',
                          );
                      final List<String> hexColorsForDots =
                          isCustomPatternSelected
                          ? (widget.selectedPreset!.colors ?? const <String>[])
                          : swatchColors.map((rgb) {
                              final r = (rgb[0] as int)
                                  .toRadixString(16)
                                  .padLeft(2, '0');
                              final g = (rgb[1] as int)
                                  .toRadixString(16)
                                  .padLeft(2, '0');
                              final b = (rgb[2] as int)
                                  .toRadixString(16)
                                  .padLeft(2, '0');
                              return '$r$g$b'.toUpperCase();
                            }).toList();

                      final double displayHeight = isCustomPatternSelected
                          ? 36
                          : 24;
                      return ColorDotsDisplay(
                        hexColors: hexColorsForDots,
                        width: 48,
                        height: displayHeight,
                        dotSize: 12,
                        horizontalMargin: 1,
                        verticalMargin: 1,
                        borderColor: Colors.black,
                        gradientColors:
                            (!isCustomPatternSelected &&
                                showPaletteGradientInTopBox)
                            ? paletteColors
                                  .map<Color>(
                                    (c) => Color.fromRGBO(
                                      int.parse(
                                        c['color']
                                            .replaceAll(RegExp(r'rgb\(|\)'), '')
                                            .split(',')[0],
                                      ),
                                      int.parse(
                                        c['color']
                                            .replaceAll(RegExp(r'rgb\(|\)'), '')
                                            .split(',')[1],
                                      ),
                                      int.parse(
                                        c['color']
                                            .replaceAll(RegExp(r'rgb\(|\)'), '')
                                            .split(',')[2],
                                      ),
                                      1,
                                    ),
                                  )
                                  .toList()
                            : null,
                        gradientStops:
                            (!isCustomPatternSelected &&
                                showPaletteGradientInTopBox)
                            ? paletteColors
                                  .map<double>((c) => (c['stop'] as num) / 100)
                                  .toList()
                            : null,
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isCardExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[600],
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        _isCardExpanded = !_isCardExpanded;
                      });
                    },
                  ),
                ],
              ),
            ),
            if (_isCardExpanded && isCustomPatternSelected)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              CustomPatternScreen(device: widget.device),
                        ),
                      );
                    },
                    child: const Text('Edit Custom Pattern'),
                  ),
                ),
              ),
            if (_isCardExpanded && !isCustomPatternSelected)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Color Swatches and Save button
                    Row(
                      children: [
                        Expanded(
                          child: colorSwatches.isNotEmpty
                              ? Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: colorSwatches.map((swatch) {
                                    final label = swatch['label'] as String;
                                    final colorIndex = swatch['index'] as int;
                                    final color = swatch['color'] as Color;
                                    final isFx = label == 'Fx';
                                    final usePaletteGradient =
                                        isFx &&
                                        paletteColors.isNotEmpty &&
                                        paletteId != 0;
                                    final isFirstSwatch = colorIndex == 0;
                                    final isClickablePalette = [
                                      2,
                                      3,
                                      4,
                                      5,
                                    ].contains(paletteId);
                                    final allowClicking =
                                        (isFx && paletteId == 0) ||
                                        (!isFx ||
                                            !usePaletteGradient ||
                                            (isFirstSwatch &&
                                                isClickablePalette));

                                    return GestureDetector(
                                      onTap: allowClicking
                                          ? () => _showColorPicker(
                                              colorIndex,
                                              label,
                                            )
                                          : null,
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: usePaletteGradient
                                              ? LinearGradient(
                                                  colors: paletteColors
                                                      .map<Color>(
                                                        (c) => Color.fromRGBO(
                                                          int.parse(
                                                            c['color']
                                                                .replaceAll(
                                                                  RegExp(
                                                                    r'rgb\(|\)',
                                                                  ),
                                                                  '',
                                                                )
                                                                .split(',')[0],
                                                          ),
                                                          int.parse(
                                                            c['color']
                                                                .replaceAll(
                                                                  RegExp(
                                                                    r'rgb\(|\)',
                                                                  ),
                                                                  '',
                                                                )
                                                                .split(',')[1],
                                                          ),
                                                          int.parse(
                                                            c['color']
                                                                .replaceAll(
                                                                  RegExp(
                                                                    r'rgb\(|\)',
                                                                  ),
                                                                  '',
                                                                )
                                                                .split(',')[2],
                                                          ),
                                                          1,
                                                        ),
                                                      )
                                                      .toList(),
                                                  stops: paletteColors
                                                      .map<double>(
                                                        (c) =>
                                                            (c['stop'] as num) /
                                                            100,
                                                      )
                                                      .toList(),
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                )
                                              : null,
                                          color: !usePaletteGradient
                                              ? color
                                              : null,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                            width: 1.5,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 4,
                                              offset: Offset(2, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: usePaletteGradient
                                                  ? Colors.white
                                                  : _getTextColorForBackground(
                                                      color,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 8),
                        // Save button
                        ElevatedButton(
                          onPressed: _hasUnsavedChanges && !_isSaving
                              ? _showSavePresetDialog
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasUnsavedChanges
                                ? Theme.of(context).primaryColor
                                : Colors.grey[300],
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Save',
                                  style: TextStyle(
                                    color: _hasUnsavedChanges
                                        ? Colors.white
                                        : Colors.grey[500],
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Effect:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: effectId,
                                    isExpanded: true,
                                    dropdownColor: Colors.white,
                                    items:
                                        EffectsDatabase.visibleEffectsIncludingId(
                                          effectId,
                                        ).map((effect) {
                                          return DropdownMenuItem<int>(
                                            value: effect['id'] as int,
                                            child: Text(
                                              effect['name'] as String,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[900],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                    onChanged: (newEffectId) async {
                                      if (newEffectId != null) {
                                        // Update via BLoC (source of truth)
                                        context.read<DeviceBloc>().add(
                                          UpdateDeviceStateFromMqtt(
                                            widget.device.id,
                                            {'fx': newEffectId},
                                          ),
                                        );
                                        // Send to device with full segment
                                        await _sendApiCommand({
                                          'fx': newEffectId,
                                        });
                                        // Immediately clear selected preset in parent
                                        try {
                                          if (widget.selectedPreset != null) {
                                            widget.onSettingsModified();
                                          }
                                        } catch (_) {}
                                        // Enable Save button by checking for changes
                                        _checkForChanges();
                                      }
                                    },
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.grey[600],
                                      size: 24,
                                    ),
                                    style: TextStyle(color: Colors.grey[900]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (effectColors.contains('Pal'))
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Palette:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[900],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: paletteId,
                                      isExpanded: true,
                                      dropdownColor: Colors.white,
                                      items: updatedPalettes.map((palette) {
                                        final paletteColors =
                                            palette['colors']
                                                as List<dynamic>? ??
                                            [];
                                        final paletteId = palette['id'] as int;
                                        return DropdownMenuItem<int>(
                                          value: paletteId,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      palette['name'] as String,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.grey[900],
                                                      ),
                                                    ),
                                                    if (paletteId != 0)
                                                      const SizedBox(height: 6),
                                                    if (paletteId != 0)
                                                      Container(
                                                        height: 12,
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                          gradient:
                                                              paletteColors
                                                                  .isNotEmpty
                                                              ? LinearGradient(
                                                                  colors: paletteColors
                                                                      .map<
                                                                        Color
                                                                      >(
                                                                        (
                                                                          c,
                                                                        ) => Color.fromRGBO(
                                                                          int.parse(
                                                                            c['color']
                                                                                .replaceAll(
                                                                                  RegExp(
                                                                                    r'rgb\(|\)',
                                                                                  ),
                                                                                  '',
                                                                                )
                                                                                .split(
                                                                                  ',',
                                                                                )[0],
                                                                          ),
                                                                          int.parse(
                                                                            c['color']
                                                                                .replaceAll(
                                                                                  RegExp(
                                                                                    r'rgb\(|\)',
                                                                                  ),
                                                                                  '',
                                                                                )
                                                                                .split(
                                                                                  ',',
                                                                                )[1],
                                                                          ),
                                                                          int.parse(
                                                                            c['color']
                                                                                .replaceAll(
                                                                                  RegExp(
                                                                                    r'rgb\(|\)',
                                                                                  ),
                                                                                  '',
                                                                                )
                                                                                .split(
                                                                                  ',',
                                                                                )[2],
                                                                          ),
                                                                          1,
                                                                        ),
                                                                      )
                                                                      .toList(),
                                                                  stops: paletteColors
                                                                      .map<
                                                                        double
                                                                      >(
                                                                        (c) =>
                                                                            (c['stop']
                                                                                as num) /
                                                                            100,
                                                                      )
                                                                      .toList(),
                                                                  begin: Alignment
                                                                      .centerLeft,
                                                                  end: Alignment
                                                                      .centerRight,
                                                                )
                                                              : null,
                                                          color:
                                                              paletteColors
                                                                  .isEmpty
                                                              ? Colors.grey[300]
                                                              : null,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (newPaletteId) async {
                                        if (newPaletteId != null) {
                                          // Update via BLoC (source of truth)
                                          context.read<DeviceBloc>().add(
                                            UpdateDeviceStateFromMqtt(
                                              widget.device.id,
                                              {'pal': newPaletteId},
                                            ),
                                          );
                                          // Send to device with full segment
                                          await _sendApiCommand({
                                            'pal': newPaletteId,
                                          });
                                          // Immediately clear selected preset in parent
                                          try {
                                            if (widget.selectedPreset != null) {
                                              widget.onSettingsModified();
                                            }
                                          } catch (_) {}
                                          // Enable Save button by checking for changes
                                          _checkForChanges();
                                        }
                                      },
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.grey[600],
                                        size: 24,
                                      ),
                                      style: TextStyle(color: Colors.grey[900]),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    effectParameters.isNotEmpty
                        ? Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: effectParameters.asMap().entries.map((
                              entry,
                            ) {
                              final paramIndex = entry.key;
                              final param = entry.value;
                              final paramKey = param.toLowerCase();

                              // Detect if this parameter should be a toggle switch
                              // These are common parameter names that represent boolean options
                              final booleanParameterNames = [
                                'overlay',
                                'one color',
                                'custom color',
                                'us style',
                                'random',
                                'smooth',
                                'boost',
                                'solid',
                                'gradient',
                                'dots',
                                'dance',
                                'trail',
                              ];
                              final isSwitch = booleanParameterNames.contains(
                                paramKey,
                              );

                              // Count how many boolean parameters come before this one
                              int booleanIndex = 0;
                              if (isSwitch) {
                                for (int i = 0; i < paramIndex; i++) {
                                  final prevParam = effectParameters[i]
                                      .toLowerCase();
                                  if (booleanParameterNames.contains(
                                    prevParam,
                                  )) {
                                    booleanIndex++;
                                  }
                                }
                              }

                              // Count how many numeric parameters come before this one
                              int numericIndex = 0;
                              if (!isSwitch) {
                                for (int i = 0; i < paramIndex; i++) {
                                  final prevParam = effectParameters[i]
                                      .toLowerCase();
                                  if (!booleanParameterNames.contains(
                                    prevParam,
                                  )) {
                                    numericIndex++;
                                  }
                                }
                              }

                              // Get the current parameter value based on parameter type and order
                              dynamic paramValue;
                              if (isSwitch) {
                                // For switch parameters, use device.options and map to o1, o2, o3 based on boolean order
                                if (booleanIndex == 0) {
                                  paramValue = device.options['o1'] ?? false;
                                } else if (booleanIndex == 1)
                                  paramValue = device.options['o2'] ?? false;
                                else if (booleanIndex == 2)
                                  paramValue = device.options['o3'] ?? false;
                                else
                                  paramValue = false;
                              } else {
                                // Map using label-aware logic (restores previous correct behavior for IX-only effects)
                                final mappedKey = _mapNumericParamToKey(
                                  paramKey,
                                  numericIndex,
                                );
                                if (mappedKey == 'sx') {
                                  paramValue = sx;
                                } else if (mappedKey == 'ix') {
                                  paramValue = ix;
                                } else if (mappedKey == 'c1') {
                                  paramValue = device.customs['c1'] ?? 128;
                                } else if (mappedKey == 'c2') {
                                  paramValue = device.customs['c2'] ?? 128;
                                } else if (mappedKey == 'c3') {
                                  paramValue = device.customs['c3'] ?? 16;
                                } else {
                                  paramValue = 128;
                                }
                              }

                              if (isSwitch) {
                                return SizedBox(
                                  width:
                                      (MediaQuery.of(context).size.width - 56) /
                                      2,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$param',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[900],
                                        ),
                                      ),
                                      Switch(
                                        value: paramValue as bool,
                                        activeColor: baseColor,
                                        activeTrackColor: baseColor.withOpacity(
                                          0.5,
                                        ),
                                        inactiveThumbColor: Colors.grey[400],
                                        inactiveTrackColor: Colors.grey[200],
                                        // Phase 7: Improved switch appearance
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (newValue) async {
                                          // Phase 7: Haptic feedback
                                          try {
                                            await HapticFeedback.lightImpact();
                                          } catch (e) {
                                            // Haptic feedback not available, continue silently
                                          }

                                          // Dispatch BLoC update for options (won't be overwritten by /v)
                                          Map<String, dynamic> updated = {};
                                          if (booleanIndex == 0) {
                                            updated = {'o1': newValue};
                                          } else if (booleanIndex == 1) {
                                            updated = {'o2': newValue};
                                          } else if (booleanIndex == 2) {
                                            updated = {'o3': newValue};
                                          }
                                          if (updated.isNotEmpty) {
                                            context.read<DeviceBloc>().add(
                                              UpdateDeviceStateFromMqtt(
                                                widget.device.id,
                                                updated,
                                              ),
                                            );
                                            // Send inside current segment 0 so WLED applies immediately
                                            await _sendApiCommand({
                                              'o1': updated['o1'],
                                              'o2': updated['o2'],
                                              'o3': updated['o3'],
                                            });
                                          }
                                          setState(() {});
                                          // Enable Save button by checking for changes
                                          _checkForChanges();
                                          // Immediately clear selected preset in parent
                                          try {
                                            if (widget.selectedPreset != null) {
                                              widget.onSettingsModified();
                                            }
                                          } catch (_) {}
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Phase 1: Get display value (dragging value or actual value)
                              final sliderKey = 'param_$numericIndex';
                              final displayValue =
                                  _isDragging &&
                                      _draggingValues.containsKey(sliderKey)
                                  ? _draggingValues[sliderKey]!.round()
                                  : paramValue;

                              return SizedBox(
                                width:
                                    (MediaQuery.of(context).size.width - 56) /
                                    2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$param: $displayValue',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[900],
                                      ),
                                    ),
                                    Slider(
                                      min: 0,
                                      // c3 has range 0-31, others have 0-255
                                      max: (numericIndex == 4) ? 31 : 255,
                                      value:
                                          (_isDragging &&
                                              _draggingValues.containsKey(
                                                sliderKey,
                                              )
                                          ? _draggingValues[sliderKey]
                                          : paramValue.toDouble())!,
                                      activeColor: baseColor,
                                      inactiveColor: Colors.grey[300],
                                      label: displayValue.toString(),
                                      // c3 has 31 divisions, others have 255
                                      divisions: (numericIndex == 4) ? 31 : 255,
                                      thumbColor: baseColor,
                                      // Phase 7: Improved slider appearance
                                      overlayColor: WidgetStateProperty.all(
                                        baseColor.withOpacity(0.1),
                                      ),
                                      // Phase 1: Only update dragging state during slide
                                      onChanged: (newValue) {
                                        setState(() {
                                          _isDragging = true;
                                          _draggingValues[sliderKey] = newValue;
                                        });
                                      },
                                      // Phase 1: Commit value when sliding ends
                                      onChangeEnd: (newValue) async {
                                        setState(() {
                                          _isDragging = false;
                                          _draggingValues.remove(sliderKey);
                                        });

                                        // Phase 7: Haptic feedback
                                        try {
                                          await HapticFeedback.lightImpact();
                                        } catch (e) {
                                          // Haptic feedback not available, continue silently
                                        }

                                        // Map numeric parameters using label-aware logic
                                        Map<String, dynamic> updated = {};
                                        final mappedKey = _mapNumericParamToKey(
                                          paramKey,
                                          numericIndex,
                                        );
                                        updated = {mappedKey: newValue.round()};
                                        if (updated.isNotEmpty) {
                                          context.read<DeviceBloc>().add(
                                            UpdateDeviceStateFromMqtt(
                                              widget.device.id,
                                              updated,
                                            ),
                                          );
                                          // Send via seg 0 (sx/ix and c1/c2/c3 all inside seg per requirement)
                                          await _sendApiCommand(updated);
                                        }

                                        // Update UI immediately for optimistic updates
                                        setState(() {});
                                        // Check for changes after local state update
                                        _checkForChanges();
                                        // Immediately clear selected preset in parent
                                        try {
                                          if (widget.selectedPreset != null) {
                                            widget.onSettingsModified();
                                          }
                                        } catch (_) {}
                                        // Sent via _sendApiCommand above when updated populated
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          )
                        : const SizedBox.shrink(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
