import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../models/device.dart';
import '../models/preset.dart';
import '../services/mqtt_service.dart';
import '../services/wp_preset_service.dart';
import '../blocs/auth_bloc.dart';
import '../widgets/device_drawer.dart';
import '../services/storage_service.dart';
import '../widgets/preset_card.dart';
import '../widgets/device_settings_drawer.dart';
import '../widgets/categories_widget.dart';
import '../data/presets_database.dart' as PresetDB;
import 'timers_screen.dart';
import '../blocs/device_bloc.dart';

// Temporary override to force using local presets for testing
const bool _useLocalPresetsForTesting = false;

class DeviceScreen extends StatefulWidget {
  final Device device;
  final DeviceMqttService? mqttService;

  const DeviceScreen({super.key, required this.device, this.mqttService});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Preset> allPresets = [];
  List<Preset> filteredPresets = [];
  final TextEditingController _searchController = TextEditingController();
  String _currentCategory = 'All';
  Preset? selectedPreset;
  bool _isSearchExpanded = false;
  DeviceMqttService? _deviceMqttService;
  final WPPresetService _wpPresetService = WPPresetService();
  Map<String, dynamic>? _currentState;
  bool _isLoadingPresets = false;
  String? _jwt;
  final StorageService _storageService = StorageService();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentCategory = _getCategoryFromIndex(_tabController.index);
        _filterPresets();
      });
    });
    _searchController.addListener(_filterPresets);
    _loadJwt();
    _loadDeviceState();
    _loadPresets();

    // Device state will be synced via device card MQTT connection
  }

  void _loadJwt() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _jwt = authState.user.jwtToken;
    }
  }

  Future<void> _loadDeviceState() async {
    try {
      // Create MQTT service for device drawer to use (but don't connect yet)
      _deviceMqttService = DeviceMqttService(widget.device);

      // Get initial device state from DeviceBloc instead of creating MQTT connection
      // Device card already handles MQTT communication
      final deviceState = context.read<DeviceBloc>().state;
      if (deviceState is DeviceLoaded) {
        final currentDevice = deviceState.devices.firstWhere(
          (d) => d.id == widget.device.id,
          orElse: () => widget.device,
        );

        print(
          '📱 INIT: Loading device state - Power: ${currentDevice.isPoweredOn}, Effect: ${currentDevice.effect}, Colors: ${currentDevice.colors}',
        );

        setState(() {
          _currentState = {
            'on': currentDevice.isPoweredOn,
            'bri': currentDevice.brightness,
            'fx': currentDevice.effect,
            'sx': currentDevice.speed,
            'ix': currentDevice.intensity,
            'pal': currentDevice.palette,
            'colors': currentDevice.colors,
          };
        });
      } else {
        // Initialize device state to default values if no state available
        print('📱 INIT: DeviceBloc not loaded, using defaults');
        setState(() {
          _currentState = {
            'on': false,
            'bri': 0,
            'fx': 0,
            'sx': 128,
            'ix': 128,
            'pal': 0,
            'colors': [
              [255, 255, 255],
              [0, 0, 0],
              [0, 0, 0],
            ],
          };
        });
      }
    } catch (e) {
      print('Error loading device state: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _deviceMqttService?.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    setState(() {
      _isLoadingPresets = true;
    });

    try {
      List<Preset> presets;

      if (_useLocalPresetsForTesting) {
        // Temporary testing override: always use local presets
        print('Using local presets (temporary testing override)...');
        presets = PresetDB.PresetDatabase.presets
            .map(
              (p) => Preset(
                id: 'local_${p.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}', // Generate consistent ID for local presets
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
      } else {
        // Try to load presets from WordPress if authenticated
        if (_jwt != null) {
          print('Loading presets from WordPress...');
          try {
            presets = await _wpPresetService.getPresets(jwt: _jwt!);
            print(
              'Successfully loaded ${presets.length} presets from WordPress',
            );

            // Sort presets: personal presets first, then others
            final authState = context.read<AuthBloc>().state;
            if (authState is AuthAuthenticated) {
              final userEmail = authState.user.email;
              presets.sort((a, b) {
                // Personal presets are those created by the current user or private status
                final aIsPersonal =
                    a.createdBy == userEmail || a.status == 'private';
                final bIsPersonal =
                    b.createdBy == userEmail || b.status == 'private';

                if (aIsPersonal && !bIsPersonal) return -1;
                if (!aIsPersonal && bIsPersonal) return 1;

                // Within each group, sort by name
                return a.name.compareTo(b.name);
              });
            }
          } catch (e) {
            print('Failed to load presets from WordPress: $e');
            // Fallback to local presets on WordPress error
            print('Falling back to local presets...');
            presets = PresetDB.PresetDatabase.presets
                .map(
                  (p) => Preset(
                    id: 'local_${p.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}', // Generate consistent ID for local presets
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
        } else {
          // Not authenticated, use local presets
          print('Not authenticated, using local presets...');
          presets = PresetDB.PresetDatabase.presets
              .map(
                (p) => Preset(
                  id: 'local_${p.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}', // Generate consistent ID for local presets
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
      }

      // Load favorite presets from local storage
      final favoriteIds = await _storageService.loadFavoritePresets();

      // Update presets with favorite status
      for (int i = 0; i < presets.length; i++) {
        final presetId = presets[i].id ?? '';
        if (favoriteIds.contains(presetId)) {
          presets[i] = presets[i].copyWith(isFavorite: true);
        }
      }

      // Sort presets: favorites first, then user-created, then others
      presets.sort((a, b) {
        // Favorites always come first
        if (a.isFavorite && !b.isFavorite) return -1;
        if (!a.isFavorite && b.isFavorite) return 1;

        // Within favorites or non-favorites, user-created come before system presets
        if (a.isFavorite == b.isFavorite) {
          if (a.isUserCreated && !b.isUserCreated) return -1;
          if (!a.isUserCreated && b.isUserCreated) return 1;
        }

        // Within same category, sort by name
        return a.name.compareTo(b.name);
      });

      setState(() {
        allPresets = presets;
        filteredPresets = presets;
        _isLoadingPresets = false;
      });

      _filterPresets();

      // Restore previously selected preset for this device (by ID)
      try {
        final savedId = await _storageService.loadSelectedPresetForDevice(
          widget.device.id,
        );
        if (savedId != null && savedId.isNotEmpty) {
          Preset? match;
          // First try to match by ID
          for (final p in allPresets) {
            if (p.id == savedId) {
              match = p;
              break;
            }
          }
          // If no ID match and savedId looks like a local preset ID, try matching by generated ID
          if (match == null && savedId.startsWith('local_')) {
            for (final p in allPresets) {
              final generatedId =
                  'local_${p.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
              if (generatedId == savedId) {
                match = p;
                break;
              }
            }
          }
          if (match != null) {
            setState(() {
              for (var p in allPresets) {
                p.isSelected = p == match;
              }
              selectedPreset = match;
            });
            // Update drawer to reflect restored preset
            DeviceDrawer.globalKey.currentState?.updateFromPreset(match);
          }
        }
      } catch (_) {}
    } catch (e) {
      print('Error loading presets: $e');
      setState(() {
        allPresets = [];
        filteredPresets = [];
        _isLoadingPresets = false;
      });
      _filterPresets();
    }
  }

  void _filterPresets() {
    if (_currentCategory == 'All') {
      // For "All" category, exclude deleted presets
      filteredPresets = allPresets.where((preset) {
        return !preset.categories.contains('Deleted');
      }).toList();
    } else if (_currentCategory == 'Deleted') {
      // Show only deleted presets
      filteredPresets = allPresets.where((preset) {
        return preset.categories.contains('Deleted');
      }).toList();
    } else {
      // For other categories, show presets in that category but exclude deleted ones
      filteredPresets = allPresets.where((preset) {
        return preset.categories.contains(_currentCategory) &&
            !preset.categories.contains('Deleted');
      }).toList();
    }

    if (_searchController.text.isNotEmpty) {
      filteredPresets = filteredPresets.where((preset) {
        return preset.name.toLowerCase().contains(
          _searchController.text.toLowerCase(),
        );
      }).toList();
    }

    setState(() {});
  }

  String _getCategoryFromIndex(int index) {
    switch (index) {
      case 0:
        return 'All';
      case 1:
        return 'Christmas';
      case 2:
        return 'Halloween';
      case 3:
        return 'Events';
      case 4:
        return 'Timers';
      case 5:
        return 'Other';
      case 6:
        return 'Deleted';
      default:
        return 'All';
    }
  }

  int _getIndexFromCategory(String category) {
    switch (category) {
      case 'All':
        return 0;
      case 'Christmas':
        return 1;
      case 'Halloween':
        return 2;
      case 'Events':
        return 3;
      case 'Timers':
        return 4;
      case 'Other':
        return 5;
      case 'Deleted':
        return 6;
      default:
        return 0;
    }
  }

  Future<Map<String, dynamic>> _convertPresetToSettings(Preset preset) async {
    // Get current device brightness from DeviceBloc state
    final blocState = context.read<DeviceBloc>().state;
    final currentDevice = blocState is DeviceLoaded
        ? blocState.devices.firstWhere(
            (d) => d.id == widget.device.id,
            orElse: () => widget.device,
          )
        : widget.device;
    final brightness = currentDevice.brightness;

    // If preset is a Custom Pattern, build multi-segment state (one segment per color)
    // matching the CustomPatternScreen/Timers behavior so device receives identical layout.
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

      final emptySegments = List.generate(28 - count, (i) => {'stop': 0});

      return {
        'on': true,
        'bri': brightness,
        'transition': 7,
        'mainseg': 0,
        'seg': [...activeSegments, ...emptySegments],
      };
    }

    // Read current device state to use as defaults for unspecified preset fields
    final dev = context.read<DeviceBloc>().state is DeviceLoaded
        ? (context.read<DeviceBloc>().state as DeviceLoaded).devices.firstWhere(
            (d) => d.id == widget.device.id,
            orElse: () => widget.device,
          )
        : widget.device;

    // Colors: use preset colors if provided, otherwise keep current device colors
    final List<List<int>> currentColors = dev.colors.isNotEmpty
        ? dev.colors.map((c) => [c[0], c[1], c[2], 0]).toList()
        : [
            [255, 255, 255, 0],
            [255, 255, 255, 0],
            [0, 0, 0, 0],
          ];
    final List<List<int>> segColors =
        preset.colors != null && preset.colors!.isNotEmpty
        ? preset.colors!.map((hex) => _hexToRgb(hex)).toList()
        : currentColors;

    final int fx = preset.fx;
    final int sx = preset.sx ?? dev.speed;
    final int ix = preset.ix ?? dev.intensity;
    final int pal = preset.paletteId ?? dev.palette;
    final int c1 = preset.c1 ?? (dev.customs['c1'] ?? 128);
    final int c2 = preset.c2 ?? (dev.customs['c2'] ?? 128);
    final int c3 = preset.c3 ?? (dev.customs['c3'] ?? 16);
    final bool? o1 = preset.o1 ?? (dev.options['o1']);
    final bool? o2 = preset.o2 ?? (dev.options['o2']);
    final bool? o3 = preset.o3 ?? (dev.options['o3']);

    final mainSeg = <String, dynamic>{
      'id': 0,
      'start': 0,
      'stop': 1000,
      'grp': 1,
      'spc': 0,
      'of': 0,
      'on': true,
      'bri': 255,
      'col': segColors,
      'fx': fx,
      'sx': sx,
      'ix': ix,
      'pal': pal,
      // Include customs and options within the segment so they aren't lost
      'c1': c1,
      'c2': c2,
      'c3': c3,
      if (o1 != null) 'o1': o1,
      if (o2 != null) 'o2': o2,
      if (o3 != null) 'o3': o3,
      'sel': true,
      'rev': false,
      'mi': false,
    };

    // Fill remaining segments with stop: 0 to clear any old segments
    final List<Map<String, dynamic>> segArray = [
      mainSeg,
      ...List.generate(15, (_) => {'stop': 0}),
    ];

    return <String, dynamic>{
      'on': true,
      'bri': brightness,
      'mainseg': 0,
      'seg': segArray,
      'transition': 7,
    };
  }

  List<int> _hexToRgb(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      final r = int.parse(hex.substring(0, 2), radix: 16);
      final g = int.parse(hex.substring(2, 4), radix: 16);
      final b = int.parse(hex.substring(4, 6), radix: 16);
      return [r, g, b, 0];
    }
    return [255, 255, 255, 0];
  }

  void _selectPreset(Preset preset) async {
    setState(() {
      for (var p in allPresets) {
        p.isSelected = p == preset;
      }
      selectedPreset = preset;
    });

    // Persist selection per device
    try {
      final presetId =
          preset.id ??
          'local_${preset.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      await _storageService.saveSelectedPresetForDevice(
        widget.device.id,
        presetId,
      );
    } catch (_) {}

    // Update the drawer immediately with preset data
    DeviceDrawer.globalKey.currentState?.updateFromPreset(preset);

    final settings = await _convertPresetToSettings(preset);

    // Send preset command directly via MQTT (reuse existing service)
    try {
      print('🎯 PRESET: Applying ${preset.name} via MQTT');

      // Use the existing MQTT service instead of creating a new one
      if (_deviceMqttService != null) {
        _deviceMqttService!.sendCommand(settings);
        print('🎯 PRESET: ${preset.name} command sent to device');
      } else {
        print('❌ PRESET: No MQTT service available');
      }

      // Update local state optimistically
      setState(() {
        _currentState = {..._currentState ?? {}, ...settings};
      });
    } catch (e) {
      print('❌ Failed to apply preset: $e');
    }
  }

  Future<void> _togglePresetFavorite(Preset preset) async {
    try {
      // Update local storage
      await _storageService.togglePresetFavorite(preset.id ?? '');

      // Update WordPress if authenticated and preset has an ID
      if (_jwt != null &&
          preset.id != null &&
          !preset.id!.startsWith('local_')) {
        await _wpPresetService.toggleFavorite(_jwt!, preset);
      }

      // Update local state
      setState(() {
        final index = allPresets.indexWhere((p) => p.id == preset.id);
        if (index != -1) {
          allPresets[index] = preset.copyWith(isFavorite: !preset.isFavorite);
        }
      });

      _filterPresets();

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            preset.isFavorite ? 'Removed from favorites' : 'Added to favorites',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update favorite status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sharePreset(Preset preset) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "${preset.name}" to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deletePreset(Preset preset) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text(
          'Are you sure you want to delete "${preset.name}"? This will move it to the Deleted category where you can restore it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update WordPress if authenticated and preset has an ID
      if (_jwt != null &&
          preset.id != null &&
          !preset.id!.startsWith('local_')) {
        await _wpPresetService.markAsDeleted(_jwt!, preset);
      }

      // Update the preset in local list to mark it as deleted
      setState(() {
        final index = allPresets.indexWhere((p) => p.id == preset.id);
        if (index != -1) {
          // Add 'Deleted' to categories if not already present
          final categories = List<String>.from(preset.categories);
          if (!categories.contains('Deleted')) {
            categories.add('Deleted');
          }
          allPresets[index] = preset.copyWith(categories: categories);
        }
      });

      _filterPresets();

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${preset.name}"'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // TODO: Implement undo functionality
            },
          ),
        ),
      );
    } catch (e) {
      print('Error deleting preset: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete preset'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _togglePower() {
    try {
      final blocState = context.read<DeviceBloc>().state;
      final currentDevice = blocState is DeviceLoaded
          ? blocState.devices.firstWhere(
              (d) => d.id == widget.device.id,
              orElse: () => widget.device,
            )
          : widget.device;

      final bool currentIsOn =
          (_currentState != null && _currentState!.containsKey('on'))
          ? (_currentState!['on'] as bool)
          : currentDevice.isPoweredOn;
      final bool newIsOn = !currentIsOn;

      // Optimistic local update for immediate UI feedback
      setState(() {
        _currentState = {...(_currentState ?? {}), 'on': newIsOn};
      });

      // Dispatch BLoC event which also sends MQTT command
      context.read<DeviceBloc>().add(
        ToggleDevicePower(widget.device.id, newIsOn),
      );
    } catch (e) {
      print('Error toggling power: $e');
    }
  }

  void _onSettingsModified() {
    setState(() {
      for (var preset in allPresets) {
        preset.isSelected = false;
      }
      selectedPreset = null;
    });

    // Clear stored selection for this device
    try {
      _storageService.clearSelectedPresetForDevice(widget.device.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DeviceBloc, DeviceState>(
      listener: (context, state) {
        // Update local state when DeviceBloc state changes (from MQTT updates)
        if (state is DeviceLoaded) {
          final currentDevice = state.devices.firstWhere(
            (d) => d.id == widget.device.id,
            orElse: () => widget.device,
          );

          print(
            '📱 DEVICE SCREEN: Syncing with DeviceBloc - Power: ${currentDevice.isPoweredOn}, Effect: ${currentDevice.effect}',
          );

          setState(() {
            _currentState = {
              'on': currentDevice.isPoweredOn,
              'bri': currentDevice.brightness,
              'fx': currentDevice.effect,
              'sx': currentDevice.speed,
              'ix': currentDevice.intensity,
              'pal': currentDevice.palette,
              'colors': currentDevice.colors,
            };
          });
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Builder(
            builder: (context) {
              final blocState = context.watch<DeviceBloc>().state;
              final currentDevice = blocState is DeviceLoaded
                  ? blocState.devices.firstWhere(
                      (d) => d.id == widget.device.id,
                      orElse: () => widget.device,
                    )
                  : widget.device;
              return Text(currentDevice.name);
            },
          ),
          actions: [
            Builder(
              builder: (context) {
                final blocState = context.watch<DeviceBloc>().state;
                final currentDevice = blocState is DeviceLoaded
                    ? blocState.devices.firstWhere(
                        (d) => d.id == widget.device.id,
                        orElse: () => widget.device,
                      )
                    : widget.device;
                final bool isOn =
                    (_currentState != null && _currentState!.containsKey('on'))
                    ? (_currentState!['on'] as bool)
                    : currentDevice.isPoweredOn;
                return IconButton(
                  icon: Icon(
                    Icons.power_settings_new,
                    color: isOn ? Colors.green : Colors.white,
                  ),
                  onPressed: _togglePower,
                  tooltip: isOn ? 'Turn off' : 'Turn on',
                );
              },
            ),
            // Settings button
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              tooltip: 'Settings',
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
          ],
        ),
        endDrawer: DeviceSettingsDrawer(device: widget.device),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Stack(
                    children: [
                      // Categories widget - full width background
                      CategoriesWidget(
                        currentCategory: _currentCategory,
                        presets: allPresets,
                        onCategoryChanged: (category) {
                          if (category == 'Timers') {
                            // Navigate to timers screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    TimersScreen(device: widget.device),
                              ),
                            );
                          } else {
                            setState(() {
                              _currentCategory = category;
                              _tabController.index = _getIndexFromCategory(
                                category,
                              );
                              _filterPresets();
                            });
                          }
                        },
                        isSearchExpanded: _isSearchExpanded,
                      ),
                      // Search overlay - positioned over categories
                      if (_isSearchExpanded)
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white70),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search Presets',
                              filled: true,
                              fillColor: Colors.transparent,
                              hintStyle: const TextStyle(color: Colors.white70),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.white70,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSearchExpanded = false;
                                    _searchController.clear();
                                  });
                                },
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _currentCategory =
                                    'All'; // Override category when searching
                                _filterPresets();
                              });
                            },
                          ),
                        ),
                      // Search button - positioned in top left when not expanded
                      if (!_isSearchExpanded)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white70),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.search,
                                color: Colors.white70,
                                size: 24,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isSearchExpanded = true;
                                  _currentCategory =
                                      'All'; // Override category when searching
                                });
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoadingPresets
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Loading presets...',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        )
                      : filteredPresets.isEmpty
                      ? const Center(
                          child: Text(
                            'No presets found',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(
                            8.0,
                          ).copyWith(bottom: 100),
                          itemCount: filteredPresets.length,
                          itemBuilder: (context, index) {
                            final preset = filteredPresets[index];
                            return PresetCard(
                              preset: preset,
                              onTap: () => _selectPreset(preset),
                              onFavoriteToggle: () =>
                                  _togglePresetFavorite(preset),
                              onShare: () => _sharePreset(preset),
                              onDelete: preset.canBeDeleted
                                  ? () => _deletePreset(preset)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DeviceDrawer(
                device: widget.device,
                mqttService: _deviceMqttService,
                selectedPreset: selectedPreset,
                onSettingsModified: _onSettingsModified,
                currentState: _currentState,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
