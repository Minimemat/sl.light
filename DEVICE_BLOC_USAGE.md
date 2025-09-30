# Device BLoC Usage Guide

## Overview

All device state is now managed centrally by `DeviceBloc`. MQTT updates automatically flow through the BLoC and all UI components receive updates via `BlocBuilder`.

## ✅ **Correct Usage - Use BlocBuilder**

```dart
// In any widget that needs device state
BlocBuilder<DeviceBloc, DeviceState>(
  builder: (context, state) {
    if (state is DeviceLoaded) {
      final device = state.devices.firstWhere((d) => d.id == deviceId);
      
      return Column(
        children: [
          // Power indicator
          Icon(
            Icons.power_settings_new,
            color: device.isPoweredOn ? Colors.green : Colors.grey,
          ),
          
          // Brightness display
          Text('Brightness: ${device.brightness}'),
          
          // Effect display
          Text('Effect: ${device.effect}'),
          
          // Color display
          Container(
            color: Color.fromRGBO(
              device.colors[0][0], // Red
              device.colors[0][1], // Green  
              device.colors[0][2], // Blue
              1.0,
            ),
          ),
        ],
      );
    }
    return CircularProgressIndicator();
  },
)
```

## ❌ **Old Usage - Don't Use Callbacks**

```dart
// DON'T DO THIS - callbacks are deprecated
_deviceMqttService!.onPowerUpdate = (bool isPoweredOn) {
  setState(() {
    _isPowerOn = isPoweredOn;
  });
};

_deviceMqttService!.onBrightnessUpdate = (int brightness) {
  setState(() {
    _brightness = brightness;
  });
};
```

## 🔄 **MQTT State Flow**

1. **MQTT receives `/v` message** → Complete device state parsed
2. **MqttService calls** → `deviceBloc.add(UpdateDeviceStateFromMqtt(deviceId, state))`
3. **DeviceBloc updates** → Device object with new state
4. **BlocBuilder rebuilds** → UI automatically updates

## 📊 **Available Device Properties**

```dart
class Device {
  final bool isPoweredOn;     // Power state
  final int brightness;       // 0-255
  final int effect;          // Effect ID
  final int palette;         // Palette ID  
  final int speed;           // 0-255
  final int intensity;       // 0-255
  final List<List<int>> colors; // [[R,G,B], [R,G,B], [R,G,B]]
  final Map<String, bool> options;  // Custom options
  final Map<String, int> customs;   // Custom sliders
  final bool isOnline;       // Connection status
}
```

## 🎯 **Common Patterns**

### Device Card
```dart
BlocBuilder<DeviceBloc, DeviceState>(
  builder: (context, state) {
    if (state is DeviceLoaded) {
      final device = state.devices.firstWhere((d) => d.id == widget.deviceId);
      return Card(
        child: ListTile(
          title: Text(device.name),
          subtitle: Text('Brightness: ${device.brightness}'),
          trailing: Icon(
            Icons.power_settings_new,
            color: device.isPoweredOn ? Colors.green : Colors.grey,
          ),
        ),
      );
    }
    return SizedBox.shrink();
  },
)
```

### Power Toggle Button
```dart
BlocBuilder<DeviceBloc, DeviceState>(
  builder: (context, state) {
    if (state is DeviceLoaded) {
      final device = state.devices.firstWhere((d) => d.id == widget.deviceId);
      return IconButton(
        icon: Icon(
          Icons.power_settings_new,
          color: device.isPoweredOn ? Colors.green : Colors.grey,
        ),
        onPressed: () {
          // Send command via BLoC
          context.read<DeviceBloc>().add(
            ToggleDevicePower(device.id, !device.isPoweredOn),
          );
        },
      );
    }
    return SizedBox.shrink();
  },
)
```

### Color Display
```dart
BlocBuilder<DeviceBloc, DeviceState>(
  builder: (context, state) {
    if (state is DeviceLoaded) {
      final device = state.devices.firstWhere((d) => d.id == widget.deviceId);
      final color = device.colors[0]; // Primary color
      
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Color.fromRGBO(color[0], color[1], color[2], 1.0),
          shape: BoxShape.circle,
        ),
      );
    }
    return SizedBox.shrink();
  },
)
```

## 🚀 **Benefits**

1. **Single Source of Truth**: All device state in DeviceBloc
2. **Automatic Updates**: UI rebuilds when MQTT updates arrive
3. **No Manual State Management**: No setState() needed
4. **Consistent State**: All components show identical data
5. **Optimistic Updates**: UI updates immediately, MQTT confirms later

## 🔧 **Migration Steps**

1. **Remove old callbacks**: Delete `onPowerUpdate`, `onBrightnessUpdate` usage
2. **Add BlocBuilder**: Wrap widgets that need device state
3. **Use device properties**: Access `device.isPoweredOn`, `device.brightness`, etc.
4. **Send commands via BLoC**: Use `context.read<DeviceBloc>().add(...)` for actions

The BLoC pattern ensures all UI components automatically stay in sync with the latest device state from MQTT!
