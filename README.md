# StayLit - WLED Device Controller

A Flutter app for controlling WLED devices with WordPress backend integration.

## Features

### Device Card Implementation
- **Device Name** displayed prominently at the top
- **Connection Status** indicator (Online/Offline) with color-coded dots
- **Brightness Display** showing percentage when device is on
- **Power Toggle** switch for easy on/off control
- **Individual Refresh** button for each device
- **Last Updated** timestamp display

### Logic Flow

#### Initial Load/Refresh
1. App loads → Pull device state from WordPress REST API
2. Extract `bri` (brightness), `on` (power), and `is_connected` fields
3. Set local UI state: power = (bri > 0), brightness = bri, connected = is_connected

#### MQTT State Updates (Incoming)
1. MQTT `/v` message received → Parse brightness value
2. Update UI immediately: power = (brightness > 0), brightness = received_value
3. Send updated state to WordPress API (`bri`, `on`, `is_connected`)
4. Set device as "connected" since we received a response

#### User Actions (Outgoing)
1. User toggles power/changes brightness → Update UI optimistically
2. Send MQTT command to device (`/api` topic with full state)
3. Start 5-second timeout timer
4. Send updated state to WordPress immediately (don't wait for device response)
5. **Connection Status Logic**:
   - If MQTT response received within 5 seconds → mark "connected"
   - If no response after 5 seconds → mark "disconnected"
   - User can still send commands regardless of connection status

#### State Management
- **UI State**: Always reflects latest known state (optimistic updates)
- **WordPress**: Acts as persistent storage, updated on every change
- **MQTT**: Confirms device received commands and provides real device state
- **Three Separate Variables**:
  1. `brightness` (0-255): Raw brightness value from `/v` topic
  2. `power` (boolean): Derived from brightness (brightness > 0)
  3. `connected` (boolean): Based on MQTT response timing

### Home Screen Features
- **Sync Button** in top-right corner syncs all devices with WordPress
- **Pull-to-refresh** functionality
- **Device List** with individual device cards
- **Add Device** floating action button (placeholder)

## Architecture

### Models
- **Device**: Core device information (name, MQTT credentials, etc.)
- **DeviceState**: Current state (brightness, connection, timestamps)

### Services
- **DeviceStateService**: Handles WordPress API communication, MQTT logic, and state caching

### Widgets
- **DeviceCard**: Modular card component that can be used in home screen and device drawer
- **HomeScreen**: Main screen with device list and sync functionality

## WordPress Integration

The app integrates with WordPress using the custom REST endpoints defined in `functions.php`:
- Device registration and management
- State persistence (`bri`, `on`, `is_connected`, `last_state_update`)
- Command logging (`last_mqtt_command`)

## Technical Notes

### Connection Timeout
- 5-second timeout for MQTT responses
- Devices marked as disconnected if no response
- Users can still send commands to disconnected devices

### Optimistic Updates
- UI updates immediately when user interacts
- WordPress state updated simultaneously
- MQTT confirms actual device response

### Caching
- Device states cached for immediate UI responsiveness
- Cache updated on WordPress sync and MQTT responses

## Future Enhancements

1. **MQTT Service**: Complete MQTT client implementation
2. **Device Details Screen**: Full device control interface
3. **Authentication**: User login and JWT management
4. **Device Discovery**: Automatic WLED device detection
5. **Presets**: Apply lighting presets to devices

## Running the App

1. Ensure Flutter SDK is installed
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the app

The app currently shows demo devices. In production, devices would be loaded from WordPress and controlled via MQTT.
