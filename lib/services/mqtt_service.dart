import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:xml/xml.dart';
import '../models/device.dart';
import '../utils/constants.dart';

class DeviceMqttService {
  final Device device;
  MqttClient? _client;
  bool _isConnected = false;
  bool _isConnecting = false;

  // Callbacks for MQTT updates - MQTT is the source of truth
  Function(int brightness)? onBrightnessUpdate;
  Function(bool isPoweredOn)? onPowerUpdate;
  Function(Map<String, dynamic> state)? onStateUpdate;

  // Rate limiting
  DateTime? _lastCommandTime;
  static const Duration _minCommandInterval = Duration(milliseconds: 100);

  // Command queuing
  Timer? _debounceTimer;
  Timer? _reprocessTimer;
  bool _isCommandInProgress = false;
  final List<Map<String, dynamic>> _commandQueue = [];
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  // Connection pooling
  static final Map<String, DeviceMqttService> _activeConnections = {};
  static const int _maxConcurrentConnections = 3;
  static int _currentConnections = 0;
  static final Queue<DeviceMqttService> _connectionQueue =
      Queue<DeviceMqttService>();

  // Retry mechanism
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // Message subscription
  StreamSubscription<MqttReceivedMessage<MqttMessage>>? _subscription;

  DeviceMqttService(this.device);

  bool get isConnected => _isConnected;

  /// Creates a native MQTT client for all platforms
  MqttClient _createMqttClient(String clientId) {
    final client = MqttServerClient(mqttBroker, clientId);
    client.port = mqttPort;
    client.secure = false; // Disable SSL/TLS for plain MQTT
    client.autoReconnect = true;
    client.connectTimeoutPeriod = 5000;
    return client;
  }

  Future<void> connect() async {
    if (_isConnecting || _isConnected) return;

    // Check if we already have an active connection for this device
    if (_activeConnections.containsKey(device.id)) {
      final existingService = _activeConnections[device.id]!;
      if (existingService != this) {
        // Use the existing connection without adding another listener
        _client = existingService._client;
        _isConnected = existingService._isConnected;
        return;
      }
    }

    // Check connection limits
    if (_currentConnections >= _maxConcurrentConnections) {
      // Add to queue and wait
      _connectionQueue.add(this);
      print('⏳ QUEUE: ${device.name} - connection limit reached');
      return;
    }

    _isConnecting = true;
    _currentConnections++;

    try {
      final clientId =
          'staylit_app_${device.mqttClientId}_${DateTime.now().millisecondsSinceEpoch}';

      _client = _createMqttClient(clientId);

      _client!.keepAlivePeriod = 60;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.onSubscribed = _onSubscribed;

      final connMessage = MqttConnectMessage()
          .withWillTopic('wled/${device.mqttClientId}/status')
          .withWillMessage('offline')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      _client!.connectionMessage = connMessage;

      await _client!.connect(device.mqttUsername, device.mqttPassword);

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _isConnected = true;
        _activeConnections[device.id] = this;
        _subscribeToTopics();
        _subscription?.cancel();
        _subscription = messages.listen(_handleMessage);
        print('✅ READY: ${device.name} - connection established');
      }
    } catch (e) {
      print('❌ CONNECT FAIL: ${device.name} - $e');
      _isConnected = false;

      // Retry with exponential backoff
      if (_retryCount < _maxRetries) {
        _retryCount++;
        final delay = Duration(seconds: _retryCount * 2);
        print(
          '🔄 RETRY: ${device.name} - attempt $_retryCount in ${delay.inSeconds}s',
        );
        Timer(delay, () {
          if (!_isConnected && !_isConnecting) {
            connect();
          }
        });
      }
    } finally {
      _isConnecting = false;
      _currentConnections--;

      // Process queued connections
      if (_connectionQueue.isNotEmpty) {
        final nextService = _connectionQueue.removeFirst();
        Timer(const Duration(milliseconds: 1000), () {
          nextService.connect();
        });
      }
    }
  }

  void _handleMessage(MqttReceivedMessage<MqttMessage> msg) {
    print('📥 RECEIVE: ${device.name} - ${msg.topic}');

    // Handle /v topic for state updates (source of truth)
    if (msg.topic == 'wled/${device.mqttClientId}/v') {
      try {
        final payload = msg.payload as MqttPublishMessage;
        // Ignore retained messages to avoid using stale state from the broker
        final bool isRetained = payload.header?.retain ?? false;
        if (isRetained) {
          print('⚠️ RETAINED: ${device.name} - ignoring retained /v message');
          return;
        }
        final message = MqttPublishPayload.bytesToStringAsString(
          payload.payload.message,
        );
        print('📥 XML: ${device.name} - $message');

        // Parse XML response
        final document = XmlDocument.parse(message);

        // Parse brightness and power - more robust parsing
        final acElement = document.findAllElements('ac').firstOrNull;
        final brightness = acElement != null
            ? int.tryParse(acElement.text.trim()) ?? 0
            : 0;
        final isPoweredOn = brightness > 0;

        print('🔧 MQTT: Parsed brightness: $brightness, power: $isPoweredOn');

        // Parse effect, speed, intensity, palette - more robust parsing
        final fxElement = document.findAllElements('fx').firstOrNull;
        final sxElement = document.findAllElements('sx').firstOrNull;
        final ixElement = document.findAllElements('ix').firstOrNull;
        final fpElement = document.findAllElements('fp').firstOrNull;

        final fx = fxElement != null
            ? int.tryParse(fxElement.text.trim()) ?? 0
            : 0;
        final sx = sxElement != null
            ? int.tryParse(sxElement.text.trim()) ?? 128
            : 128;
        final ix = ixElement != null
            ? int.tryParse(ixElement.text.trim()) ?? 128
            : 128;
        final fp = fpElement != null
            ? int.tryParse(fpElement.text.trim()) ?? 0
            : 0;

        print('🔧 MQTT: Parsed elements - fx: $fx, sx: $sx, ix: $ix, fp: $fp');

        // Parse first color (cl elements) - more robust parsing
        final clElements = document.findAllElements('cl').toList();
        int cl1 = 255, cl2 = 255, cl3 = 255;
        if (clElements.isNotEmpty) {
          cl1 = int.tryParse(clElements[0].text.trim()) ?? 255;
          if (clElements.length > 1) {
            cl2 = int.tryParse(clElements[1].text.trim()) ?? 255;
          }
          if (clElements.length > 2) {
            cl3 = int.tryParse(clElements[2].text.trim()) ?? 255;
          }
          print(
            '🔧 MQTT: Parsed color elements: ${clElements.length} elements, values: [$cl1, $cl2, $cl3]',
          );
        } else {
          print('🔧 MQTT: No color elements found in XML');
        }

        print('💡 BRIGHTNESS: ${device.name} - $brightness');
        print(
          '🔌 POWER: ${device.name} - ${isPoweredOn ? 'ON' : 'OFF'} (brightness: $brightness)',
        );
        print('🎨 EFFECT: ${device.name} - fx: $fx, sx: $sx, ix: $ix, fp: $fp');
        print('🎨 FIRST COLOR: ${device.name} - R: $cl1, G: $cl2, B: $cl3');

        // Create comprehensive state map
        final state = {
          'on': isPoweredOn,
          'bri': brightness,
          'ac': brightness,
          'fx': fx,
          'sx': sx,
          'ix': ix,
          'fp': fp,
          'cl1': cl1,
          'cl2': cl2,
          'cl3': cl3,
        };

        // Call callbacks in order - MQTT is the source of truth
        onBrightnessUpdate?.call(brightness);
        onPowerUpdate?.call(isPoweredOn);
        onStateUpdate?.call(state);

        print(
          '📡 MQTT UPDATE: ${device.name} - Power: $isPoweredOn, Brightness: $brightness, Effect: $fx, Speed: $sx, Intensity: $ix, Palette: $fp, Color: RGB($cl1,$cl2,$cl3)',
        );
      } catch (e) {
        print('❌ XML PARSE ERROR: ${device.name} - $e');
      }
    }
  }

  void _onConnected() {
    print('🔗 CONNECT: ${device.name}');
    _isConnected = true;
  }

  void _onDisconnected() {
    print('🔌 DISCONNECT: ${device.name}');
    _isConnected = false;
    _activeConnections.remove(device.id);
  }

  void _onSubscribed(String topic) {
    print('📡 SUBSCRIBE: ${device.name} - $topic');
  }

  void _subscribeToTopics() {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      // Subscribe to /v topic for brightness updates
      _client!.subscribe('wled/${device.mqttClientId}/v', MqttQos.atLeastOnce);
      print('📡 SUBSCRIBE: ${device.name} - wled/${device.mqttClientId}/v');
    }
  }

  void subscribe(String topic, {MqttQos qos = MqttQos.atLeastOnce}) {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.subscribe(topic, qos);
    }
  }

  void publish(
    String topic,
    String payload, {
    MqttQos qos = MqttQos.atLeastOnce,
  }) {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);
      _client!.publishMessage(topic, qos, builder.payload!);
    }
  }

  Stream<MqttReceivedMessage<MqttMessage>> get messages {
    return _client?.updates?.expand((messages) => messages) ??
        const Stream.empty();
  }

  void sendCommand(Map<String, dynamic> command) {
    // Rate limiting check
    final now = DateTime.now();
    if (_lastCommandTime != null &&
        now.difference(_lastCommandTime!) < _minCommandInterval) {
      print('🚫 RATE LIMIT: ${device.name} - command too fast, skipping');
      return;
    }
    _lastCommandTime = now;

    // Add to queue
    _commandQueue.add(command);

    // Cancel existing debounce timer
    _debounceTimer?.cancel();

    // Start new debounce timer
    _debounceTimer = Timer(_debounceDelay, () {
      _processCommandQueue();
    });

    // Ensure connection is in progress if not connected
    if (!_isConnected && !_isConnecting) {
      // Fire and forget
      connect();
    }
  }

  Future<void> _processCommandQueue() async {
    if (_isCommandInProgress || _commandQueue.isEmpty) return;
    _isCommandInProgress = true;
    try {
      // Ensure we are connected before attempting to publish
      if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
        if (!_isConnecting) {
          try {
            await connect();
          } catch (_) {}
        }
      }
      if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
        // Not connected yet; schedule a retry and keep the queue intact
        _isCommandInProgress = false;
        _reprocessTimer?.cancel();
        _reprocessTimer = Timer(const Duration(seconds: 2), () {
          _processCommandQueue();
        });
        return;
      }
      // Get the latest command from the queue (discard older ones)
      final command = _commandQueue.removeLast();
      _commandQueue.clear();
      final topic = 'wled/${device.mqttClientId}/api';
      final payload = jsonEncode(command);
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print('📤 SEND: ${device.name} - $command');
    } catch (e) {
      print('❌ ERROR: ${device.name} - failed to send: $e');
    } finally {
      _isCommandInProgress = false;
      if (_commandQueue.isNotEmpty) {
        Timer(const Duration(milliseconds: 50), () {
          _processCommandQueue();
        });
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _debounceTimer?.cancel();
    _reprocessTimer?.cancel();
    _activeConnections.remove(device.id);
    _client?.disconnect();
    _client = null;
    _isConnected = false;
  }

  Future<void> savePresetMqtt(
    int presetId,
    String presetName,
    Map<String, dynamic> presetState,
  ) async {
    await connect();
    final topic = 'wled/${device.mqttClientId}/api';
    final payload = jsonEncode({
      'psave': presetId,
      'n': presetName,
      ...presetState,
    });
    print(
      'MQTT: Saving preset $presetId ($presetName) to ${device.name}: $payload',
    );
    publish(topic, payload);
  }

  Future<void> saveTimerMqtt(
    int timerSlot,
    Map<String, dynamic> timerSettings,
  ) async {
    await connect();
    final topic = 'wled/${device.mqttClientId}/api';
    final payload = jsonEncode({
      'timer': {'$timerSlot': timerSettings},
    });
    print('MQTT: Saving timer slot $timerSlot to ${device.name}: $payload');
    publish(topic, payload);
  }

  Future<void> togglePower(bool isOn) async {
    print('🔌 MQTT: togglePower called for ${device.name}');
    print('🔌 MQTT: Target power state: ${isOn ? 'ON' : 'OFF'}');
    print('🔌 MQTT: Current connection status: $_isConnected');

    await connect();
    print('🔌 MQTT: Connection attempt completed, status: $_isConnected');

    if (!_isConnected) {
      print('🔌 MQTT: Error - not connected after connect attempt');
      throw Exception('Failed to connect to MQTT broker');
    }

    final topic = 'wled/${device.mqttClientId}/api';
    final payload = jsonEncode({'on': isOn});
    print('🔌 MQTT: Publishing to topic: $topic');
    print('🔌 MQTT: Payload: $payload');

    publish(topic, payload);
    print('🔌 MQTT: Power toggle command sent successfully');
  }

  /// Ping device to get current state
  Future<void> pingDevice() async {
    print('🏓 MQTT: Pinging device ${device.name} for current state');

    await connect();

    if (!_isConnected) {
      print('🏓 MQTT: Error - not connected after connect attempt');
      throw Exception('Failed to connect to MQTT broker');
    }

    final topic = 'wled/${device.mqttClientId}/api';
    final payload = jsonEncode({
      'seg': [
        {'frz': false},
      ],
    });

    print('🏓 MQTT: Publishing ping to topic: $topic');
    print('🏓 MQTT: Ping payload: $payload');

    publish(topic, payload);
    print('🏓 MQTT: Ping command sent successfully');
  }
}
