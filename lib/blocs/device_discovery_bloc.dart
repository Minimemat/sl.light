import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../services/mdns_service.dart';
import '../services/add_device_service.dart';

// Events
abstract class DeviceDiscoveryEvent extends Equatable {
  const DeviceDiscoveryEvent();

  @override
  List<Object?> get props => [];
}

class StartDeviceDiscovery extends DeviceDiscoveryEvent {
  final String? jwtToken;

  const StartDeviceDiscovery({this.jwtToken});

  @override
  List<Object?> get props => [jwtToken];
}

class StopDeviceDiscovery extends DeviceDiscoveryEvent {}

class DeviceFound extends DeviceDiscoveryEvent {
  final Map<String, String> device;

  const DeviceFound(this.device);

  @override
  List<Object?> get props => [device];
}

class ClearDiscoveredDevices extends DeviceDiscoveryEvent {}

// States
abstract class DeviceDiscoveryState extends Equatable {
  const DeviceDiscoveryState();

  @override
  List<Object?> get props => [];
}

class DeviceDiscoveryInitial extends DeviceDiscoveryState {}

class DeviceDiscoveryLoading extends DeviceDiscoveryState {}

class DeviceDiscoverySuccess extends DeviceDiscoveryState {
  final List<Map<String, String>> devices;
  final bool isDiscovering;

  const DeviceDiscoverySuccess({
    required this.devices,
    this.isDiscovering = false,
  });

  @override
  List<Object?> get props => [devices, isDiscovering];

  DeviceDiscoverySuccess copyWith({
    List<Map<String, String>>? devices,
    bool? isDiscovering,
  }) {
    return DeviceDiscoverySuccess(
      devices: devices ?? this.devices,
      isDiscovering: isDiscovering ?? this.isDiscovering,
    );
  }
}

class DeviceDiscoveryError extends DeviceDiscoveryState {
  final String message;

  const DeviceDiscoveryError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class DeviceDiscoveryBloc
    extends Bloc<DeviceDiscoveryEvent, DeviceDiscoveryState> {
  final MdnsService _mdnsService = MdnsService();
  final DeviceDiscoveryService _discoveryService = DeviceDiscoveryService();

  StreamSubscription? _discoverySubscription;
  Timer? _discoveryTimer;
  int _deviceCounter = 0;
  final List<Map<String, String>> _discoveredDevices = [];

  DeviceDiscoveryBloc() : super(DeviceDiscoveryInitial()) {
    on<StartDeviceDiscovery>(_onStartDeviceDiscovery);
    on<StopDeviceDiscovery>(_onStopDeviceDiscovery);
    on<DeviceFound>(_onDeviceFound);
    on<ClearDiscoveredDevices>(_onClearDiscoveredDevices);
  }

  Future<void> _onStartDeviceDiscovery(
    StartDeviceDiscovery event,
    Emitter<DeviceDiscoveryState> emit,
  ) async {
    _deviceCounter = 0; // Reset counter for new discovery
    _discoveredDevices.clear(); // Clear previous discoveries
    emit(const DeviceDiscoverySuccess(devices: [], isDiscovering: true));

    try {
      // Start MDNS discovery first
      await _startMdnsDiscovery(emit, event.jwtToken);

      // Then get MAC addresses for devices found via MDNS
      await _getMacAddressesForDevices(emit, event.jwtToken);
    } catch (e) {
      emit(DeviceDiscoveryError('Failed to start discovery: $e'));
    }
  }

  Future<void> _onStopDeviceDiscovery(
    StopDeviceDiscovery event,
    Emitter<DeviceDiscoveryState> emit,
  ) async {
    await _discoverySubscription?.cancel();
    _discoveryTimer?.cancel();

    if (state is DeviceDiscoverySuccess) {
      final currentState = state as DeviceDiscoverySuccess;
      emit(currentState.copyWith(isDiscovering: false));
    }
  }

  void _onDeviceFound(DeviceFound event, Emitter<DeviceDiscoveryState> emit) {
    if (state is DeviceDiscoverySuccess) {
      final currentState = state as DeviceDiscoverySuccess;
      final devices = List<Map<String, String>>.from(currentState.devices);

      // Check if device already exists by IP
      final existingIndex = devices.indexWhere(
        (d) => d['ip'] == event.device['ip'],
      );

      if (existingIndex >= 0) {
        // Update existing device, but prefer MAC-based names over sequential names
        final newDevice = event.device;

        // If new device has MAC-based name, use it
        if (newDevice['name']?.startsWith('Lit House-') == true) {
          devices[existingIndex] = newDevice;
        }
      } else {
        // Add new device
        devices.add(event.device);
      }

      emit(currentState.copyWith(devices: devices));
    }
  }

  void _onClearDiscoveredDevices(
    ClearDiscoveredDevices event,
    Emitter<DeviceDiscoveryState> emit,
  ) {
    emit(const DeviceDiscoverySuccess(devices: [], isDiscovering: false));
  }

  Future<void> _startMdnsDiscovery(
    Emitter<DeviceDiscoveryState> emit,
    String? jwtToken,
  ) async {
    try {
      await for (final device in _mdnsService.discoverWledDevicesStream(
        timeout: const Duration(seconds: 5),
      )) {
        // Collect devices internally without emitting immediately
        final deviceWithName = Map<String, String>.from(device);
        _deviceCounter++;
        deviceWithName['name'] =
            'Lit House-ABC${_deviceCounter.toString().padLeft(3, '0')}';
        _discoveredDevices.add(deviceWithName);
      }
    } catch (e) {
      print('MDNS discovery error: $e');
    }
  }

  String _generateDeviceName(String mac) {
    final cleanMac = mac.replaceAll(':', '').replaceAll('-', '').toUpperCase();
    final prefix = cleanMac.length >= 6 ? cleanMac.substring(0, 6) : cleanMac;
    return 'Lit House-$prefix';
  }

  Future<void> _getMacAddressesForDevices(
    Emitter<DeviceDiscoveryState> emit,
    String? jwtToken,
  ) async {
    final List<Map<String, String>> finalDevices = [];

    // Process all discovered devices to get MAC addresses
    for (final device in _discoveredDevices) {
      final ip = device['ip'] ?? '';

      if (ip.isNotEmpty) {
        try {
          final mac = await _discoveryService.getMacAddress(ip);
          if (mac != null) {
            final updatedDevice = Map<String, String>.from(device);
            updatedDevice['mac'] = mac;
            updatedDevice['name'] = _generateDeviceName(mac);

            // Check if device is already added to user's account
            if (jwtToken != null) {
              final isAlreadyAdded = await _discoveryService
                  .isDeviceInWordPress(mac, jwtToken);
              if (isAlreadyAdded) {
                // Skip device if already added
                continue;
              }
            }

            finalDevices.add(updatedDevice);
          }
        } catch (e) {
          print('Failed to get MAC for $ip: $e');
        }
      }
    }

    // Emit final results only when discovery is complete
    emit(DeviceDiscoverySuccess(devices: finalDevices, isDiscovering: false));
  }

  @override
  Future<void> close() {
    _discoverySubscription?.cancel();
    return super.close();
  }
}
