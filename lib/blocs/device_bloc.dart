import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../models/device.dart';
import '../services/storage_service.dart';
import '../services/wp_api.dart';
import '../services/mqtt_service.dart';

// Events
abstract class DeviceEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadDevices extends DeviceEvent {}

class AddDevice extends DeviceEvent {
  final Device device;
  final String? jwt;

  AddDevice(this.device, {this.jwt});

  @override
  List<Object?> get props => [device, jwt];
}

class UpdateDevice extends DeviceEvent {
  final Device device;
  final String? jwt;

  UpdateDevice(this.device, {this.jwt});

  @override
  List<Object?> get props => [device, jwt];
}

class DeleteDevice extends DeviceEvent {
  final String deviceId;
  final String? jwt;

  DeleteDevice(this.deviceId, {this.jwt});

  @override
  List<Object?> get props => [deviceId, jwt];
}

class SetDevices extends DeviceEvent {
  final List<Device> devices;

  SetDevices(this.devices);

  @override
  List<Object?> get props => [devices];
}

class SyncWithWordPress extends DeviceEvent {
  final String jwt;

  SyncWithWordPress(this.jwt);

  @override
  List<Object?> get props => [jwt];
}

class ToggleDevicePower extends DeviceEvent {
  final String deviceId;
  final bool isOn;

  ToggleDevicePower(this.deviceId, this.isOn);

  @override
  List<Object?> get props => [deviceId, isOn];
}

class UpdateDeviceBrightness extends DeviceEvent {
  final String deviceId;
  final int brightness;

  UpdateDeviceBrightness(this.deviceId, this.brightness);

  @override
  List<Object?> get props => [deviceId, brightness];
}

class UpdateDevicePowerFromMqtt extends DeviceEvent {
  final String deviceId;
  final bool isPoweredOn;

  UpdateDevicePowerFromMqtt(this.deviceId, this.isPoweredOn);

  @override
  List<Object?> get props => [deviceId, isPoweredOn];
}

class UpdateDeviceStateFromMqtt extends DeviceEvent {
  final String deviceId;
  final Map<String, dynamic> state;

  UpdateDeviceStateFromMqtt(this.deviceId, this.state);

  @override
  List<Object?> get props => [deviceId, state];
}

class UpdateDeviceOnlineStatus extends DeviceEvent {
  final String deviceId;
  final bool isOnline;

  UpdateDeviceOnlineStatus(this.deviceId, this.isOnline);

  @override
  List<Object?> get props => [deviceId, isOnline];
}

class PingDevice extends DeviceEvent {
  final String deviceId;

  PingDevice(this.deviceId);

  @override
  List<Object?> get props => [deviceId];
}

// States
abstract class DeviceState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DeviceInitial extends DeviceState {}

class DeviceLoading extends DeviceState {}

class DeviceLoaded extends DeviceState {
  final List<Device> devices;

  DeviceLoaded(this.devices);

  @override
  List<Object?> get props => [devices];
}

class DeviceError extends DeviceState {
  final String message;

  DeviceError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  final StorageService _storageService = StorageService();
  final WPApiService _wpApiService = WPApiService();

  DeviceBloc() : super(DeviceInitial()) {
    on<LoadDevices>(_onLoadDevices);
    on<AddDevice>(_onAddDevice);
    on<UpdateDevice>(_onUpdateDevice);
    on<DeleteDevice>(_onDeleteDevice);
    on<SetDevices>(_onSetDevices);
    on<SyncWithWordPress>(_onSyncWithWordPress);
    on<ToggleDevicePower>(_onToggleDevicePower);
    on<UpdateDeviceBrightness>(_onUpdateDeviceBrightness);
    on<UpdateDevicePowerFromMqtt>(_onUpdateDevicePowerFromMqtt);
    on<UpdateDeviceStateFromMqtt>(_onUpdateDeviceStateFromMqtt);
    on<UpdateDeviceOnlineStatus>(_onUpdateDeviceOnlineStatus);
    on<PingDevice>(_onPingDevice);
  }

  Future<void> _onLoadDevices(
    LoadDevices event,
    Emitter<DeviceState> emit,
  ) async {
    emit(DeviceLoading());
    try {
      final devices = await _storageService.loadDevices();
      emit(DeviceLoaded(devices));

      // Ping all devices to get their current state after loading
      if (devices.isNotEmpty) {
        print('🔄 BLOC: Pinging all devices after loading from storage');
        _pingAllDevicesDirectly(devices);
      }
    } catch (e) {
      emit(DeviceError('Failed to load devices: $e'));
    }
  }

  Future<void> _onAddDevice(AddDevice event, Emitter<DeviceState> emit) async {
    final currentState = state;
    try {
      Device deviceToAdd = event.device;
      if (event.jwt != null) {
        deviceToAdd = await _wpApiService.addDevice(event.device, event.jwt!);
      }
      if (currentState is DeviceLoaded) {
        final updated = List<Device>.from(currentState.devices)
          ..add(deviceToAdd);
        await _storageService.saveDevices(updated);
        emit(DeviceLoaded(updated));
      }
    } catch (e) {
      emit(DeviceError('Failed to add device: $e'));
    }
  }

  Future<void> _onUpdateDevice(
    UpdateDevice event,
    Emitter<DeviceState> emit,
  ) async {
    final currentState = state;
    try {
      Device deviceToUpdate = event.device;
      if (event.jwt != null) {
        deviceToUpdate = await _wpApiService.updateDevice(
          event.device,
          event.jwt!,
        );
      }
      if (currentState is DeviceLoaded) {
        final updated = currentState.devices
            .map((d) => d.id == deviceToUpdate.id ? deviceToUpdate : d)
            .toList();
        await _storageService.saveDevices(updated);
        emit(DeviceLoaded(updated));
      }
    } catch (e) {
      emit(DeviceError('Failed to update device: $e'));
    }
  }

  Future<void> _onDeleteDevice(
    DeleteDevice event,
    Emitter<DeviceState> emit,
  ) async {
    final currentState = state;
    try {
      if (event.jwt != null) {
        await _wpApiService.deleteDevice(event.deviceId, event.jwt!);
      }
      if (currentState is DeviceLoaded) {
        final updated = currentState.devices
            .where((d) => d.id != event.deviceId)
            .toList();
        await _storageService.saveDevices(updated);
        emit(DeviceLoaded(updated));
      }
    } catch (e) {
      emit(DeviceError('Failed to delete device: $e'));
    }
  }

  Future<void> _onSetDevices(
    SetDevices event,
    Emitter<DeviceState> emit,
  ) async {
    await _storageService.saveDevices(event.devices);
    emit(DeviceLoaded(event.devices));
  }

  Future<void> _onSyncWithWordPress(
    SyncWithWordPress event,
    Emitter<DeviceState> emit,
  ) async {
    print('🔄 BLOC: Starting WordPress sync');
    print('🔄 BLOC: JWT token length: ${event.jwt.length}');

    try {
      print('🔄 BLOC: Calling WordPress API service');
      final wpDevices = await _wpApiService.getDevices(event.jwt);
      print('🔄 BLOC: WordPress API returned ${wpDevices.length} devices');

      // Get current devices to preserve MQTT state
      final currentState = state;
      List<Device> currentDevices = [];
      if (currentState is DeviceLoaded) {
        currentDevices = currentState.devices;
        print('🔄 BLOC: Found ${currentDevices.length} current devices');
      }

      // Merge WordPress devices with configuration from WordPress and state from current local devices (if present)
      final Map<String, Device> currentById = {
        for (final d in currentDevices) d.id: d,
      };
      final mergedDevices = wpDevices.map((wpDevice) {
        final current = currentById[wpDevice.id];
        if (current != null) {
          return wpDevice.copyWith(
            isOnline: current.isOnline,
            isPoweredOn: current.isPoweredOn,
            brightness: current.brightness,
            color: current.color,
            colors: current.colors,
            effect: current.effect,
            palette: current.palette,
            speed: current.speed,
            intensity: current.intensity,
            options: current.options,
            customs: current.customs,
          );
        }
        return wpDevice;
      }).toList();

      print(
        '🔄 BLOC: Merged ${mergedDevices.length} devices (preserving MQTT state)',
      );

      print('🔄 BLOC: Saving devices to local storage');
      await _storageService.saveDevices(mergedDevices);
      print('🔄 BLOC: Devices saved to local storage');

      print('🔄 BLOC: Emitting DeviceLoaded state');
      emit(DeviceLoaded(mergedDevices));
      print('🔄 BLOC: WordPress sync completed successfully');

      // Ping all devices to get their current state
      print('🔄 BLOC: Pinging all devices to sync current state');
      _pingAllDevicesDirectly(mergedDevices);

      // Device cards will handle their own MQTT connections and state syncing
    } catch (e) {
      print('🔄 BLOC: WordPress sync failed: $e');
      emit(DeviceError('Failed to sync with WordPress: $e'));
    }
  }

  Future<void> _onToggleDevicePower(
    ToggleDevicePower event,
    Emitter<DeviceState> emit,
  ) async {
    print('🔌 BLOC: _onToggleDevicePower called');
    print('🔌 BLOC: Device ID: ${event.deviceId}, Power state: ${event.isOn}');
    print('🔌 BLOC: Current state type: ${state.runtimeType}');

    final currentState = state;
    if (currentState is! DeviceLoaded) {
      print('🔌 BLOC: Error - current state is not DeviceLoaded');
      return;
    }

    try {
      // Find the device
      final deviceIndex = currentState.devices.indexWhere(
        (d) => d.id == event.deviceId,
      );
      if (deviceIndex == -1) {
        print('🔌 BLOC: Error - device not found with ID: ${event.deviceId}');
        print(
          '🔌 BLOC: Available devices: ${currentState.devices.map((d) => '${d.name}(${d.id})').join(', ')}',
        );
        return;
      }

      final device = currentState.devices[deviceIndex];
      print('🔌 BLOC: Found device: ${device.name} (${device.id})');
      print('🔌 BLOC: Current device power state: ${device.isPoweredOn}');

      // Optimistically update the UI
      final updatedDevice = device.copyWith(isPoweredOn: event.isOn);
      print(
        '🔌 BLOC: Updated device power state to: ${updatedDevice.isPoweredOn}',
      );

      final updatedDevices = List<Device>.from(currentState.devices);
      updatedDevices[deviceIndex] = updatedDevice;

      // Emit the optimistic update immediately
      print('🔌 BLOC: Emitting optimistic update');
      emit(DeviceLoaded(updatedDevices));

      // Save to local storage
      print('🔌 BLOC: Saving to local storage');
      await _storageService.saveDevices(updatedDevices);
      print('🔌 BLOC: Local storage saved successfully');

      // Send MQTT command
      print('🔌 BLOC: Sending MQTT command');
      final mqttService = DeviceMqttService(device);
      await mqttService.togglePower(event.isOn);
      print('🔌 BLOC: MQTT command sent successfully');

      print(
        '🔌 BLOC: Power toggle completed for ${device.name} to ${event.isOn ? 'ON' : 'OFF'}',
      );
    } catch (e) {
      print('🔌 BLOC: Error toggling power: $e');
      print('🔌 BLOC: Stack trace: ${StackTrace.current}');
      // Revert the optimistic update on error
      print('🔌 BLOC: Reverting optimistic update due to error');
      emit(DeviceLoaded(currentState.devices));
    }
  }

  Future<void> _onUpdateDeviceBrightness(
    UpdateDeviceBrightness event,
    Emitter<DeviceState> emit,
  ) async {
    print('💡 BLOC: _onUpdateDeviceBrightness called');
    print(
      '💡 BLOC: Device ID: ${event.deviceId}, Brightness: ${event.brightness}',
    );

    final currentState = state;
    if (currentState is! DeviceLoaded) {
      print('💡 BLOC: Error - current state is not DeviceLoaded');
      return;
    }

    try {
      // Find the device
      final deviceIndex = currentState.devices.indexWhere(
        (d) => d.id == event.deviceId,
      );
      if (deviceIndex == -1) {
        print('💡 BLOC: Error - device not found with ID: ${event.deviceId}');
        return;
      }

      final device = currentState.devices[deviceIndex];
      print('💡 BLOC: Found device: ${device.name} (${device.id})');
      print(
        '💡 BLOC: Current brightness: ${device.brightness}, New brightness: ${event.brightness}',
      );

      // Update the device with new brightness
      final updatedDevice = device.copyWith(brightness: event.brightness);
      final updatedDevices = List<Device>.from(currentState.devices);
      updatedDevices[deviceIndex] = updatedDevice;

      // Emit the update immediately
      print('💡 BLOC: Emitting brightness update');
      emit(DeviceLoaded(updatedDevices));

      // Save to local storage
      print('💡 BLOC: Saving to local storage');
      await _storageService.saveDevices(updatedDevices);
      print('💡 BLOC: Local storage saved successfully');

      print(
        '💡 BLOC: Brightness update completed for ${device.name} to ${event.brightness}',
      );
    } catch (e) {
      print('💡 BLOC: Error updating brightness: $e');
    }
  }

  Future<void> _onUpdateDevicePowerFromMqtt(
    UpdateDevicePowerFromMqtt event,
    Emitter<DeviceState> emit,
  ) async {
    print('📡 BLOC: _onUpdateDevicePowerFromMqtt called');
    print(
      '📡 BLOC: Device ID: ${event.deviceId}, Power state: ${event.isPoweredOn}',
    );

    final currentState = state;
    if (currentState is! DeviceLoaded) {
      print('📡 BLOC: Error - current state is not DeviceLoaded');
      return;
    }

    try {
      // Find the device
      final deviceIndex = currentState.devices.indexWhere(
        (d) => d.id == event.deviceId,
      );
      if (deviceIndex == -1) {
        print('📡 BLOC: Error - device not found with ID: ${event.deviceId}');
        return;
      }

      final device = currentState.devices[deviceIndex];
      print('📡 BLOC: Found device: ${device.name} (${device.id})');
      print(
        '📡 BLOC: Current power state: ${device.isPoweredOn}, New power state: ${event.isPoweredOn}',
      );

      // Update the device with new power state (MQTT is source of truth)
      final updatedDevice = device.copyWith(isPoweredOn: event.isPoweredOn);
      final updatedDevices = List<Device>.from(currentState.devices);
      updatedDevices[deviceIndex] = updatedDevice;

      // Emit the update immediately
      print('📡 BLOC: Emitting MQTT power update');
      emit(DeviceLoaded(updatedDevices));

      // Save to local storage
      print('📡 BLOC: Saving to local storage');
      await _storageService.saveDevices(updatedDevices);
      print('📡 BLOC: Local storage saved successfully');

      print(
        '📡 BLOC: MQTT power update completed for ${device.name} to ${event.isPoweredOn ? 'ON' : 'OFF'}',
      );
    } catch (e) {
      print('📡 BLOC: Error updating power from MQTT: $e');
    }
  }

  Future<void> _onUpdateDeviceStateFromMqtt(
    UpdateDeviceStateFromMqtt event,
    Emitter<DeviceState> emit,
  ) async {
    print('📡 BLOC: _onUpdateDeviceStateFromMqtt called');
    print('📡 BLOC: Device ID: ${event.deviceId}, State: ${event.state}');
    final currentState = state;
    if (currentState is! DeviceLoaded) {
      print('📡 BLOC: Error - current state is not DeviceLoaded');
      return;
    }
    try {
      final deviceIndex = currentState.devices.indexWhere(
        (d) => d.id == event.deviceId,
      );
      if (deviceIndex == -1) {
        print('📡 BLOC: Error - device not found with ID: ${event.deviceId}');
        return;
      }
      final device = currentState.devices[deviceIndex];
      bool isPoweredOn = device.isPoweredOn;
      int brightness = device.brightness;
      int effect = device.effect;
      int palette = device.palette;
      int speed = device.speed;
      int intensity = device.intensity;
      List<List<int>> colors = device.colors
          .map((c) => List<int>.from(c))
          .toList();
      Map<String, bool> options = Map<String, bool>.from(device.options);
      Map<String, int> customs = Map<String, int>.from(device.customs);
      if (event.state.containsKey('on')) {
        isPoweredOn = event.state['on'] ?? isPoweredOn;
      }
      if (event.state.containsKey('bri') || event.state.containsKey('ac')) {
        brightness = event.state['bri'] ?? event.state['ac'] ?? brightness;
      }
      if (event.state.containsKey('fx')) {
        effect = event.state['fx'] ?? effect;
      }
      if (event.state.containsKey('pal') || event.state.containsKey('fp')) {
        palette = event.state['pal'] ?? event.state['fp'] ?? palette;
      }
      if (event.state.containsKey('sx')) {
        speed = event.state['sx'] ?? speed;
      }
      if (event.state.containsKey('ix')) {
        intensity = event.state['ix'] ?? intensity;
      }
      if (event.state['colors'] is List) {
        final flatColors = (event.state['colors'] as List)
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 255)
            .toList();

        // Convert flat color list to nested format [[R,G,B], [R,G,B], ...]
        final incoming = <List<int>>[];
        for (int i = 0; i < flatColors.length; i += 3) {
          if (i + 2 < flatColors.length) {
            incoming.add([flatColors[i], flatColors[i + 1], flatColors[i + 2]]);
          }
        }

        if (incoming.isNotEmpty) {
          // Merge incoming colors with existing colors, preserving unmodified slots
          for (int i = 0; i < incoming.length && i < 3; i++) {
            colors[i] = incoming[i];
          }
        }
      } else if (event.state['cl'] is List) {
        final cl = (event.state['cl'] as List)
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 255)
            .toList();
        if (cl.length >= 3) {
          colors[0] = [cl[0], cl[1], cl[2]];
        }
      } else if (event.state.containsKey('cl1') ||
          event.state.containsKey('cl2') ||
          event.state.containsKey('cl3')) {
        final r = event.state['cl1'] ?? colors[0][0];
        final g = event.state['cl2'] ?? colors[0][1];
        final b = event.state['cl3'] ?? colors[0][2];
        colors[0] = [r, g, b];
      }

      // Merge options and customs (not present in /v): keep existing unless provided
      if (event.state['options'] is Map) {
        final incomingOptions = (event.state['options'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as bool)),
        );
        options.addAll(incomingOptions);
      }
      if (event.state['customs'] is Map) {
        final incomingCustoms = (event.state['customs'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as int)),
        );
        customs.addAll(incomingCustoms);
      }
      if (event.state.containsKey('o1')) {
        options['o1'] = (event.state['o1'] as bool?) ?? options['o1'] ?? false;
      }
      if (event.state.containsKey('o2')) {
        options['o2'] = (event.state['o2'] as bool?) ?? options['o2'] ?? false;
      }
      if (event.state.containsKey('o3')) {
        options['o3'] = (event.state['o3'] as bool?) ?? options['o3'] ?? false;
      }
      if (event.state.containsKey('c1')) {
        customs['c1'] = (event.state['c1'] as int?) ?? customs['c1'] ?? 128;
      }
      if (event.state.containsKey('c2')) {
        customs['c2'] = (event.state['c2'] as int?) ?? customs['c2'] ?? 128;
      }
      if (event.state.containsKey('c3')) {
        customs['c3'] = (event.state['c3'] as int?) ?? customs['c3'] ?? 16;
      }
      final updatedDevice = device.copyWith(
        isPoweredOn: isPoweredOn,
        brightness: brightness,
        effect: effect,
        palette: palette,
        speed: speed,
        intensity: intensity,
        colors: colors,
        options: options,
        customs: customs,
        isOnline: true,
      );
      if (updatedDevice == device) {
        print('📡 BLOC: No state change detected, skipping save');
        return;
      }
      final updatedDevices = List<Device>.from(currentState.devices);
      updatedDevices[deviceIndex] = updatedDevice;
      print('📡 BLOC: Emitting MQTT state update (merged partials)');
      emit(DeviceLoaded(updatedDevices));
      await _storageService.saveDevices(updatedDevices);
      print('📡 BLOC: MQTT state merge saved');
    } catch (e) {
      print('📡 BLOC: Error updating state from MQTT: $e');
    }
  }

  Future<void> _onPingDevice(
    PingDevice event,
    Emitter<DeviceState> emit,
  ) async {
    print('🏓 BLOC: Ping device ${event.deviceId}');
    final currentState = state;
    if (currentState is! DeviceLoaded) return;

    final device = currentState.devices.firstWhere(
      (d) => d.id == event.deviceId,
      orElse: () => throw Exception('Device not found'),
    );

    try {
      final mqttService = DeviceMqttService(device);
      await mqttService.pingDevice();
      print('🏓 BLOC: Ping sent successfully for ${device.name}');
    } catch (e) {
      print('🏓 BLOC: Ping failed for ${device.name}: $e');
    }
  }

  void _pingAllDevicesDirectly(List<Device> devices) {
    // Ping all devices asynchronously without blocking the BLoC
    Future.microtask(() async {
      print('🏓 BLOC: Pinging all devices for current state');

      // Ping all devices to get their current state
      for (final device in devices) {
        try {
          print('🏓 BLOC: Pinging ${device.name} (${device.mqttClientId})');
          final mqttService = DeviceMqttService(device);
          await mqttService.pingDevice();
          print('🏓 BLOC: Ping sent successfully for ${device.name}');

          // Small delay between pings to avoid overwhelming the broker
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('🏓 BLOC: Ping failed for ${device.name}: $e');
        }
      }
      print('🏓 BLOC: Finished pinging all ${devices.length} devices');
    });
  }

  Future<void> _onUpdateDeviceOnlineStatus(
    UpdateDeviceOnlineStatus event,
    Emitter<DeviceState> emit,
  ) async {
    print(
      '📶 BLOC: Updating online status for ${event.deviceId} -> ${event.isOnline ? 'online' : 'offline'}',
    );
    final currentState = state;
    if (currentState is! DeviceLoaded) return;
    final deviceIndex = currentState.devices.indexWhere(
      (d) => d.id == event.deviceId,
    );
    if (deviceIndex == -1) return;
    final device = currentState.devices[deviceIndex];
    final updatedDevice = device.copyWith(isOnline: event.isOnline);
    if (updatedDevice == device) return;
    final updatedDevices = List<Device>.from(currentState.devices);
    updatedDevices[deviceIndex] = updatedDevice;
    emit(DeviceLoaded(updatedDevices));
    await _storageService.saveDevices(updatedDevices);
  }
}
