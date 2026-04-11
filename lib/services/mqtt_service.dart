import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// Relay control modes
enum RelayMode { grid, solar, off }

// Relay snapshot for immutable state
class RelaySnapshot {
  final int relayNumber;
  final double current;
  final String statusRaw;
  final bool isOn;
  final DateTime lastUpdated;

  RelaySnapshot({
    required this.relayNumber,
    required this.current,
    required this.statusRaw,
    required this.isOn,
    required this.lastUpdated,
  });

  RelayMode get inferredMode {
    if (statusRaw == '10') return RelayMode.grid;
    if (statusRaw == '01') return RelayMode.solar;
    return RelayMode.off;
  }
}

class MqttService {
  // Singleton pattern
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  // Local MQTT Broker settings
  static const String broker = '192.168.137.1';
  static const int port = 1883;
  static const String clientId = 'flutter_powerhouse_app';

  // Meter Topics (Subscribe)
  static const String topicMeterVoltage = 'PowerHouse/meter/voltage';
  static const String topicMeterCurrent = 'PowerHouse/meter/current';
  static const String topicMeterRealPower = 'PowerHouse/meter/realpower';
  static const String topicMeterApparentPower = 'PowerHouse/meter/apparentpower';
  static const String topicMeterPF = 'PowerHouse/meter/pf';
  static const String topicMeterKWh = 'PowerHouse/meter/kwh';

  // Relay Topics (Subscribe)
  static const String topicRelayVoltage = 'PowerHouse/Relays/Voltage';
  static const String topicRelay1Current = 'PowerHouse/Relays/Relay_1/Current';
  static const String topicRelay1Status = 'PowerHouse/Relays/Relay_1/Status';
  static const String topicRelay2Current = 'PowerHouse/Relays/Relay_2/Current';
  static const String topicRelay2Status = 'PowerHouse/Relays/Relay_2/Status';
  static const String topicRelay3Current = 'PowerHouse/Relays/Relay_3/Current';
  static const String topicRelay3Status = 'PowerHouse/Relays/Relay_3/Status';
  static const String topicRelay4Current = 'PowerHouse/Relays/Relay_4/Current';
  static const String topicRelay4Status = 'PowerHouse/Relays/Relay_4/Status';

  // Relay Topics (Publish - Control)
  static const String topicRelay1Control = 'PowerHouse/Relays/Relay_1/Control';
  static const String topicRelay2Control = 'PowerHouse/Relays/Relay_2/Control';
  static const String topicRelay3Control = 'PowerHouse/Relays/Relay_3/Control';
  static const String topicRelay4Control = 'PowerHouse/Relays/Relay_4/Control';

  MqttServerClient? _client;

  // Track active screen count
  int _activeScreens = 0;

  // Stream controllers
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<Map<String, double>> _metricsController =
      StreamController<Map<String, double>>.broadcast();
  final StreamController<Map<String, RelaySnapshot>> _relayController =
      StreamController<Map<String, RelaySnapshot>>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, double>> get metricsStream => _metricsController.stream;
  Stream<Map<String, RelaySnapshot>> get relayStream => _relayController.stream;

  // Connection state
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Meter metrics (6 data points)
  double _voltage = 0.0;
  double _current = 0.0;
  double _realPower = 0.0;
  double _apparentPower = 0.0;
  double _powerFactor = 0.0;
  double _kwh = 0.0;
  DateTime? _lastMetricsAt;

  double get voltage => _voltage;
  double get current => _current;
  double get power => _realPower;
  double get apparentPower => _apparentPower;
  double get powerFactor => _powerFactor;
  double get kwh => _kwh;
  DateTime? get lastMetricsAt => _lastMetricsAt;

  // Relay data
  double _relayVoltage = 0.0;
  Map<String, RelaySnapshot> _relays = {};

  double get relayVoltage => _relayVoltage;
  Map<String, RelaySnapshot> get relays => _relays;

  // Called when a screen starts using the MQTT service
  void registerScreen() {
    _activeScreens++;
  }

  // Called when a screen stops using the MQTT service
  void unregisterScreen() {
    _activeScreens--;
  }

  Future<bool> connect() async {
    if (_isConnected && _client != null) {
      return true;
    }

    try {
      _client = MqttServerClient.withPort(broker, clientId, port);
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 60;
      _client!.connectTimeoutPeriod = 5000;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.autoReconnect = true;

      // Local broker - no TLS
      _client!.secure = false;

      // No authentication for local broker
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean();

      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _isConnected = true;
        _connectionController.add(true);

        // Subscribe to meter metrics (6 topics)
        _client!.subscribe(topicMeterVoltage, MqttQos.atLeastOnce);
        _client!.subscribe(topicMeterCurrent, MqttQos.atLeastOnce);
        _client!.subscribe(topicMeterRealPower, MqttQos.atLeastOnce);
        _client!.subscribe(topicMeterApparentPower, MqttQos.atLeastOnce);
        _client!.subscribe(topicMeterPF, MqttQos.atLeastOnce);
        _client!.subscribe(topicMeterKWh, MqttQos.atLeastOnce);

        // Subscribe to relay data
        _client!.subscribe(topicRelayVoltage, MqttQos.atLeastOnce);
        _client!.subscribe(topicRelay1Current, MqttQos.atLeastOnce);
        _client!.subscribe(topicRelay1Status, MqttQos.atLeastOnce);
        _client!.subscribe(topicRelay2Current, MqttQos.atLeastOnce);
        _client!.subscribe(topicRelay2Status, MqttQos.atLeastOnce);
        _client!.subscribe(topicRelay3Current, MqttQos.atLeastOnce);
        _client!.subscribe(topicRelay3Status, MqttQos.atLeastOnce);
        _client!.subscribe(topicRelay4Current, MqttQos.atLeastOnce);
        _client!.subscribe(topicRelay4Status, MqttQos.atLeastOnce);

        // Listen to messages
        _client!.updates!.listen(_onMessage);

        print('✅ Connected to local MQTT broker at $broker:$port');
        return true;
      } else {
        _isConnected = false;
        _connectionController.add(false);
        print('❌ MQTT connection failed: ${_client!.connectionStatus!.state}');
        return false;
      }
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      print('❌ MQTT connection error: $e');
      return false;
    }
  }

  void _onConnected() {
    _isConnected = true;
    _connectionController.add(true);
    print('✅ MQTT Connected');
  }

  void _onDisconnected() {
    _isConnected = false;
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

      // Meter metrics (6 topics)
      if (topic == topicMeterVoltage) {
        _voltage = double.tryParse(payload) ?? 0.0;
        _lastMetricsAt = DateTime.now();
        _emitMetrics();
      } else if (topic == topicMeterCurrent) {
        _current = double.tryParse(payload) ?? 0.0;
        _lastMetricsAt = DateTime.now();
        _emitMetrics();
      } else if (topic == topicMeterRealPower) {
        _realPower = double.tryParse(payload) ?? 0.0;
        _lastMetricsAt = DateTime.now();
        _emitMetrics();
      } else if (topic == topicMeterApparentPower) {
        _apparentPower = double.tryParse(payload) ?? 0.0;
        _lastMetricsAt = DateTime.now();
        _emitMetrics();
      } else if (topic == topicMeterPF) {
        _powerFactor = double.tryParse(payload) ?? 0.0;
        _lastMetricsAt = DateTime.now();
        _emitMetrics();
      } else if (topic == topicMeterKWh) {
        _kwh = double.tryParse(payload) ?? 0.0;
        _lastMetricsAt = DateTime.now();
        _emitMetrics();
      }
      // Relay voltage
      else if (topic == topicRelayVoltage) {
        _relayVoltage = double.tryParse(payload) ?? 0.0;
        _emitRelayData();
      }
      // Relay currents and statuses
      else if (topic == topicRelay1Current) {
        _updateRelayCurrent(1, payload);
      } else if (topic == topicRelay1Status) {
        _updateRelayStatus(1, payload);
      } else if (topic == topicRelay2Current) {
        _updateRelayCurrent(2, payload);
      } else if (topic == topicRelay2Status) {
        _updateRelayStatus(2, payload);
      } else if (topic == topicRelay3Current) {
        _updateRelayCurrent(3, payload);
      } else if (topic == topicRelay3Status) {
        _updateRelayStatus(3, payload);
      } else if (topic == topicRelay4Current) {
        _updateRelayCurrent(4, payload);
      } else if (topic == topicRelay4Status) {
        _updateRelayStatus(4, payload);
      }
    }
  }

  void _updateRelayCurrent(int relayNumber, String payload) {
    final current = double.tryParse(payload) ?? 0.0;
    final key = 'relay$relayNumber';
    final existing = _relays[key];

    if (existing != null) {
      _relays[key] = RelaySnapshot(
        relayNumber: relayNumber,
        current: current,
        statusRaw: existing.statusRaw,
        isOn: existing.isOn,
        lastUpdated: DateTime.now(),
      );
    } else {
      _relays[key] = RelaySnapshot(
        relayNumber: relayNumber,
        current: current,
        statusRaw: '00',
        isOn: false,
        lastUpdated: DateTime.now(),
      );
    }
    _emitRelayData();
  }

  void _updateRelayStatus(int relayNumber, String payload) {
    final key = 'relay$relayNumber';
    final existing = _relays[key];
    final isOn = (payload == '10' || payload == '01');

    if (existing != null) {
      _relays[key] = RelaySnapshot(
        relayNumber: relayNumber,
        current: existing.current,
        statusRaw: payload,
        isOn: isOn,
        lastUpdated: DateTime.now(),
      );
    } else {
      _relays[key] = RelaySnapshot(
        relayNumber: relayNumber,
        current: 0.0,
        statusRaw: payload,
        isOn: isOn,
        lastUpdated: DateTime.now(),
      );
    }
    _emitRelayData();
  }

  void _emitMetrics() {
    _metricsController.add({
      'voltage': _voltage,
      'current': _current,
      'realPower': _realPower,
      'apparentPower': _apparentPower,
      'pf': _powerFactor,
      'kwh': _kwh,
    });
    print(
      '📊 Metrics: V=$_voltage, I=$_current, P=$_realPower, AP=$_apparentPower, PF=$_powerFactor, kWh=$_kwh',
    );
  }

  void _emitRelayData() {
    _relayController.add({..._relays});
    print('🔄 Relay Data Updated');
  }

  // Control relay with mode: "10" = GRID, "01" = SOLAR, "00" = OFF
  Future<void> setRelayMode(int relayNumber, RelayMode mode) async {
    if (!_isConnected || _client == null) {
      print('❌ Not connected to MQTT broker');
      return;
    }

    final controlTopic = _getRelayControlTopic(relayNumber);
    final payload = _getModePayload(mode);

    try {
      _publishMessage(controlTopic, payload);
      print('✅ Relay $relayNumber set to $mode');
    } catch (e) {
      print('❌ Failed to set relay $relayNumber: $e');
    }
  }

  String _getRelayControlTopic(int relayNumber) {
    switch (relayNumber) {
      case 1:
        return topicRelay1Control;
      case 2:
        return topicRelay2Control;
      case 3:
        return topicRelay3Control;
      case 4:
        return topicRelay4Control;
      default:
        return topicRelay1Control;
    }
  }

  String _getModePayload(RelayMode mode) {
    switch (mode) {
      case RelayMode.grid:
        return '10';
      case RelayMode.solar:
        return '01';
      case RelayMode.off:
        return '00';
    }
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

  void disconnect() {
    if (_client != null && _isConnected) {
      _client!.disconnect();
    }
    _isConnected = false;
    _connectionController.add(false);
  }

  void disposeScreen() {
    unregisterScreen();
  }

  void dispose() {
    if (_activeScreens <= 0) {
      disconnect();
      _connectionController.close();
      _metricsController.close();
      _relayController.close();
    }
  }
}
