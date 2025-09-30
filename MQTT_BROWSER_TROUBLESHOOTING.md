# MQTT Browser Connection Troubleshooting Guide

This guide helps you diagnose and resolve MQTT WebSocket connection issues when running the StayLit app in Chrome browser.

## Quick Test

1. **Access the MQTT Test Tool**:
   - Open your app in Chrome
   - Go to Home Screen → Menu (☰) → "MQTT Connection Test"
   - Click "Test Connection"

## Common Issues & Solutions

### 1. **Port Mismatch: WLED vs Browser**
**The Core Issue**: WLED devices use standard MQTT (port 1883), but browsers require WebSocket MQTT.

**Solution**: Configure your MQTT broker to support BOTH protocols:
- **Port 1883**: Standard MQTT for WLED devices
- **Port 1883/8080/9001**: WebSocket MQTT for browsers

### 2. **WebSocket Connection Refused**
**Error**: `WebSocket connection to 'ws://staylit.lighting:1883/mqtt' failed`

**Causes & Solutions**:
- **Broker not configured**: Broker needs WebSocket listener enabled
- **Wrong path**: Ensure broker accepts WebSocket connections at `/mqtt` path
- **Firewall**: Check if WebSocket ports are blocked by firewall/network

### 2. **Mixed Content Security Error**
**Error**: `Mixed Content: The page at 'https://...' was loaded over HTTPS, but attempted to connect to the insecure WebSocket endpoint`

**Solution**: 
- Change `ws://` to `wss://` for secure WebSocket
- Or serve your app over HTTP instead of HTTPS
- Update `lib/utils/constants.dart`:
```dart
const String mqttBroker = 'staylit.lighting';
const int mqttWebSocketPort = 8081; // Use secure port
// Use wss:// in browser client connection
```

### 3. **CORS Policy Error**
**Error**: `Access to WebSocket at 'ws://staylit.lighting:8080/mqtt' from origin 'https://...' has been blocked by CORS policy`

**Solution**: Configure MQTT broker to allow WebSocket CORS headers:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type
```

### 4. **Authentication Failure**
**Error**: `Connection failed: badUserNameOrPassword`

**Root Cause**: WLED device credentials don't match your app's device records.

**From WLED Configuration** (Device: 2cbcbb4f01a4):
- Username: `user_1757438242986`
- Password: `pass_1757438242986`
- Client ID: `2cbcbb4f01a4` (MAC: 2C:BC:BB:4F:01:A4)
- Device Topic: `wled/2cbcbb4f01a4`
- Group Topic: `wled/all`
- Port: `1883` (standard MQTT for WLED)
- WebSocket Port: `9001` (for browsers)

**Solutions**:
1. **Update your device records** to match WLED's current credentials
2. **Sync WLED with your database** - push correct credentials to WLED
3. **Check credential format** - WLED uses `user_[timestamp]` / `pass_[timestamp]`
4. **Verify client ID matches** between app and WLED device

### 5. **Connection Timeout**
**Error**: `Connection timed out`

**Solutions**:
- Increase timeout in `mqtt_service.dart`: `connectTimeoutPeriod = 15000`
- Check network connectivity
- Verify broker is reachable from browser

## MQTT Broker Configuration

### Mosquitto Example
Add to `mosquitto.conf`:
```conf
# Standard MQTT
port 1883

# WebSocket support
listener 8080
protocol websockets

# For secure WebSocket (recommended for production)
listener 8081
protocol websockets
certfile /path/to/cert.pem
keyfile /path/to/key.pem

# Allow anonymous (for testing only)
allow_anonymous true

# CORS headers for browser clients
http_dir /usr/share/mosquitto/www
```

### HiveMQ Example
```xml
<websocket-listener>
    <port>8080</port>
    <bind-address>0.0.0.0</bind-address>
    <path>/mqtt</path>
    <name>websocket-listener</name>
    <subprotocols>
        <subprotocol>mqttv3.1</subprotocol>
        <subprotocol>mqtt</subprotocol>
    </subprotocols>
    <allow-extensions>true</allow-extensions>
</websocket-listener>
```

## Browser Developer Tools

1. **Open DevTools**: Press F12 or Ctrl+Shift+I
2. **Console Tab**: Look for WebSocket errors
3. **Network Tab**: Check WebSocket connection attempts
4. **Security Tab**: Check for mixed content warnings

## Testing WebSocket Manually

Test WebSocket connection directly in browser console:
```javascript
const ws = new WebSocket('ws://staylit.lighting:8080/mqtt');
ws.onopen = () => console.log('WebSocket connected');
ws.onerror = (e) => console.log('WebSocket error:', e);
ws.onclose = (e) => console.log('WebSocket closed:', e.code, e.reason);
```

## App Configuration

### Enable Debug Logging
In `mqtt_service.dart`, logging is already enabled for browser clients:
```dart
(_client as MqttBrowserClient).logging(on: true);
```

### Connection Diagnostics
Use the built-in diagnostics method:
```dart
final service = MqttService(device);
final diagnostics = service.getConnectionDiagnostics();
print(diagnostics);
```

## Security Considerations

### Production Setup
- Use `wss://` (secure WebSocket) for production
- Implement proper authentication
- Use certificates for TLS
- Restrict CORS origins

### Development Setup
- `ws://` is acceptable for local development
- Use `allow_anonymous` for testing only
- Allow broad CORS for development

## Fallback Solutions

### 1. HTTP Polling
If WebSocket fails, implement HTTP polling as fallback:
```dart
Timer.periodic(Duration(seconds: 5), (timer) {
  // Poll device status via HTTP API
  _pollDeviceStatus();
});
```

### 2. Server-Sent Events (SSE)
Alternative real-time communication:
```dart
EventSource eventSource = EventSource('http://staylit.lighting/events');
eventSource.listen((event) {
  // Handle real-time updates
});
```

## Contact Support

If issues persist:
1. Check MQTT broker logs
2. Verify network connectivity
3. Test with MQTT client tools (MQTT Explorer, mosquitto_pub/sub)
4. Review browser compatibility

## Browser Compatibility

- ✅ Chrome 16+
- ✅ Firefox 11+
- ✅ Safari 7+
- ✅ Edge 12+

WebSocket support is available in all modern browsers.
