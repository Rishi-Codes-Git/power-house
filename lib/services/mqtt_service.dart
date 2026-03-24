import 'dart:async';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

enum RelayState { relay1On, relay2On, bothOff }

class MqttService {
  // Singleton pattern
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  // HiveMQ Cloud broker settings
  static const String broker =
      '1f38f79c17c44b53bf84e7e6fd6b165e.s1.eu.hivemq.cloud';
  static const int port = 8883;
  static const String username = 'esp32';
  static const String password = 'Prvn@2005';
  static const String clientId = 'flutter_powerhouse_app';

  // MQTT Topics
  static const String topicRelay1Command = 'powerhouse/relay1/command';
  static const String topicRelay1State = 'powerhouse/relay1/state';
  static const String topicRelay2Command = 'powerhouse/relay2/command';
  static const String topicRelay2State = 'powerhouse/relay2/state';
  static const String topicStatus = 'powerhouse/status';

  // Metrics Topics
  static const String topicVoltage = 'powerhouse/metrics/voltage';
  static const String topicCurrent = 'powerhouse/metrics/current';
  static const String topicPower = 'powerhouse/metrics/power';

  MqttServerClient? _client;

  // Track active screen count to prevent disconnecting while screens are still using it
  int _activeScreens = 0;

  final StreamController<RelayState> _relayStateController =
      StreamController<RelayState>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<Map<String, double>> _metricsController =
      StreamController<Map<String, double>>.broadcast();

  Stream<RelayState> get relayStateStream => _relayStateController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, double>> get metricsStream => _metricsController.stream;

  RelayState _currentState = RelayState.bothOff;
  RelayState get currentState => _currentState;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String _lastCommand = '';
  String get lastCommand => _lastCommand;

  String _lastStatus = 'Not connected';
  String get lastStatus => _lastStatus;

  bool _relay1On = false;
  bool _relay2On = false;

  bool get relay1On => _relay1On;
  bool get relay2On => _relay2On;

  // Metrics state
  double _voltage = 0.0;
  double _current = 0.0;
  double _power = 0.0;

  double get voltage => _voltage;
  double get current => _current;
  double get power => _power;

  // Called when a screen starts using the MQTT service
  void registerScreen() {
    _activeScreens++;
  }

  // Called when a screen stops using the MQTT service
  void unregisterScreen() {
    _activeScreens--;
  }

  Future<bool> connect() async {
    // If already connected, just return true
    if (_isConnected && _client != null) {
      return true;
    }

    try {
      _lastStatus = 'Connecting to MQTT broker...';

      _client = MqttServerClient.withPort(broker, clientId, port);
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 60;
      _client!.connectTimeoutPeriod = 5000;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.autoReconnect = true;

      // Set up SSL/TLS (insecure mode for self-signed certs)
      _client!.secure = true;
      _client!.securityContext = SecurityContext.defaultContext;
      _client!.onBadCertificate = (dynamic certificate) => true;

      // Set Last Will and Testament
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .authenticateAs(username, password)
          .withWillTopic(topicStatus)
          .withWillMessage('offline')
          .withWillQos(MqttQos.atLeastOnce)
          .withWillRetain()
          .startClean()
          .withWillRetain();

      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _isConnected = true;
        _lastStatus = 'Connected to MQTT broker';
        _connectionController.add(true);

        // Subscribe to state topics
        _client!.subscribe(topicRelay1State, MqttQos.atLeastOnce);
        _client!.subscribe(topicRelay2State, MqttQos.atLeastOnce);
        _client!.subscribe(topicStatus, MqttQos.atLeastOnce);

        // Subscribe to metrics topics
        _client!.subscribe(topicVoltage, MqttQos.atLeastOnce);
        _client!.subscribe(topicCurrent, MqttQos.atLeastOnce);
        _client!.subscribe(topicPower, MqttQos.atLeastOnce);

        // Listen to messages
        _client!.updates!.listen(_onMessage);

        // Publish app online status
        _publishMessage(topicStatus, 'app_online', retain: true);

        print('✅ MQTT Connected successfully');
        return true;
      } else {
        _isConnected = false;
        _lastStatus = 'Connection failed: ${_client!.connectionStatus!.state}';
        _connectionController.add(false);
        print('❌ MQTT Connection failed');
        return false;
      }
    } catch (e) {
      _isConnected = false;
      _lastStatus = 'Connection error: $e';
      _connectionController.add(false);
      print('❌ MQTT Connection error: $e');
      return false;
    }
  }

  void _onConnected() {
    _isConnected = true;
    _lastStatus = 'Connected to MQTT broker';
    _connectionController.add(true);
    print('✅ MQTT Connected');
  }

  void _onDisconnected() {
    _isConnected = false;
    _lastStatus = 'Disconnected from MQTT broker';
    _connectionController.add(false);
    print('❌ MQTT Disconnected');
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (var message in messages) {
      final topic = message.topic;
      final payload = MqttPublishPayload.bytesToStringAsString(
        (message.payload as MqttPublishMessage).payload.message,
      );

      print('📨 MQTT Message: $topic = $payload');

      // Handle relay state updates
      if (topic == topicRelay1State) {
        _relay1On = (payload == 'ON' || payload == '1' || payload == 'true');
        _updateRelayState();
      } else if (topic == topicRelay2State) {
        _relay2On = (payload == 'ON' || payload == '1' || payload == 'true');
        _updateRelayState();
      } else if (topic == topicStatus) {
        _lastStatus = 'Device status: $payload';
      }
      // Handle metrics updates
      else if (topic == topicVoltage) {
        _voltage = double.tryParse(payload) ?? _voltage;
        _emitMetrics();
      } else if (topic == topicCurrent) {
        _current = double.tryParse(payload) ?? _current;
        _emitMetrics();
      } else if (topic == topicPower) {
        _power = double.tryParse(payload) ?? _power;
        _emitMetrics();
      }
    }
  }

  void _updateRelayState() {
    if (_relay1On && !_relay2On) {
      _currentState = RelayState.relay1On;
    } else if (_relay2On && !_relay1On) {
      _currentState = RelayState.relay2On;
    } else {
      _currentState = RelayState.bothOff;
    }
    _relayStateController.add(_currentState);
    print(
      '🔄 Relay State Updated: $_currentState (R1:$_relay1On, R2:$_relay2On)',
    );
  }

  void _emitMetrics() {
    _metricsController.add({
      'voltage': _voltage,
      'current': _current,
      'power': _power,
    });
    print('📊 Metrics Updated: V=$_voltage, I=$_current, P=$_power');
  }

  void _publishMessage(String topic, String message, {bool retain = false}) {
    if (_client == null || !_isConnected) {
      print('❌ Cannot publish: Not connected');
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: retain,
    );

    print('📤 Published to $topic: $message');
  }

  Future<bool> sendCommand(String command) async {
    if (!_isConnected || _client == null) {
      _lastStatus = 'Not connected to MQTT';
      return false;
    }

    try {
      if (command == 'RELAY1_ON') {
        _publishMessage(topicRelay1Command, 'ON');
        _publishMessage(topicRelay2Command, 'OFF');
        _lastCommand = 'RELAY1_ON';
        _lastStatus = 'Transformer ON command sent';
      } else if (command == 'RELAY2_ON') {
        _publishMessage(topicRelay1Command, 'OFF');
        _publishMessage(topicRelay2Command, 'ON');
        _lastCommand = 'RELAY2_ON';
        _lastStatus = 'Solar ON command sent';
      } else if (command == 'ALL_OFF') {
        _publishMessage(topicRelay1Command, 'OFF');
        _publishMessage(topicRelay2Command, 'OFF');
        _lastCommand = 'ALL_OFF';
        _lastStatus = 'All OFF command sent';
      }

      // Wait a bit for state update
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      _lastStatus = 'Failed to send command: $e';
      print('❌ Command failed: $e');
      return false;
    }
  }

  // Turn transformer ON (Relay 1 ON, Relay 2 OFF)
  Future<bool> transformerOn() async {
    final result = await sendCommand('RELAY1_ON');
    if (result) {
      _relay1On = true;
      _relay2On = false;
      _updateRelayState();
    }
    return result;
  }

  // Turn transformer OFF / Solar ON (Relay 1 OFF, Relay 2 ON)
  Future<bool> solarOn() async {
    final result = await sendCommand('RELAY2_ON');
    if (result) {
      _relay1On = false;
      _relay2On = true;
      _updateRelayState();
    }
    return result;
  }

  // Turn both OFF
  Future<bool> allOff() async {
    final result = await sendCommand('ALL_OFF');
    if (result) {
      _relay1On = false;
      _relay2On = false;
      _updateRelayState();
    }
    return result;
  }

  void disconnect() {
    if (_client != null && _isConnected) {
      _publishMessage(topicStatus, 'app_offline', retain: true);
      _client!.disconnect();
    }
    _isConnected = false;
    _connectionController.add(false);
  }

  // Called by individual screens - does NOT disconnect the singleton
  void disposeScreen() {
    unregisterScreen();
    // Don't disconnect - other screens may still be using the connection
  }

  // Only call this when the app is actually closing
  void dispose() {
    if (_activeScreens <= 0) {
      disconnect();
      _relayStateController.close();
      _connectionController.close();
      _metricsController.close();
    }
  }
}
