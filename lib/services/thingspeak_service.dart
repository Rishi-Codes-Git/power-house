import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ThingSpeakService {
  static const String channelId = '3305058';
  static const String readApiKey = 'NF3UFVDKCXGIRTEK';
  static const String baseUrl =
      'https://api.thingspeak.com/channels/$channelId/feeds.json';
  static const int connectionWindowSeconds = 20;
  static const int pollIntervalSeconds = 10;

  Timer? _pollTimer;
  final StreamController<LiveData> _dataController =
      StreamController<LiveData>.broadcast();

  Stream<LiveData> get liveDataStream => _dataController.stream;
  LiveData? _lastData;
  LiveData? get lastData => _lastData;

  void startPolling() {
    _pollTimer?.cancel();
    _fetchData();
    _pollTimer = Timer.periodic(
      Duration(seconds: pollIntervalSeconds),
      (_) => _fetchData(),
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchData() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl?api_key=$readApiKey&results=1'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final feeds = data['feeds'] as List?;

        if (feeds != null && feeds.isNotEmpty) {
          final latest = feeds.last;
          final liveData = LiveData.fromThingSpeak(latest);
          _lastData = liveData;
          _dataController.add(liveData);
        }
      }
    } catch (e) {
      _dataController.addError('Failed to fetch data: $e');
    }
  }

  Future<LiveData?> fetchOnce() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl?api_key=$readApiKey&results=1'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final feeds = data['feeds'] as List?;

        if (feeds != null && feeds.isNotEmpty) {
          final latest = feeds.last;
          _lastData = LiveData.fromThingSpeak(latest);
          return _lastData;
        }
      }
    } catch (e) {
      // Return null on error
    }
    return null;
  }

  void dispose() {
    stopPolling();
    _dataController.close();
  }
}

class LiveData {
  final double voltage;
  final double current;
  final double power;
  final double temperature;
  final DateTime? createdAt;
  final bool isConnected;

  LiveData({
    required this.voltage,
    required this.current,
    required this.power,
    required this.temperature,
    this.createdAt,
    this.isConnected = false,
  });

  factory LiveData.fromThingSpeak(Map<String, dynamic> json) {
    final createdAtStr = json['created_at'] as String?;
    DateTime? createdAt;
    bool isConnected = false;

    if (createdAtStr != null) {
      createdAt = DateTime.tryParse(createdAtStr);
      if (createdAt != null) {
        final age = DateTime.now()
            .toUtc()
            .difference(createdAt.toUtc())
            .inSeconds;
        isConnected = age <= ThingSpeakService.connectionWindowSeconds;
      }
    }

    return LiveData(
      voltage: _parseDouble(json['field1']),
      current: _parseDouble(json['field2']),
      power: _parseDouble(json['field3']),
      temperature: _parseDouble(json['field4']),
      createdAt: createdAt,
      isConnected: isConnected,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Calculate derived values
  double get apparentPowerKVA => (voltage * current) / 1000.0;

  double get loadPercent {
    const ratedKVA = 150.0;
    return (apparentPowerKVA / ratedKVA) * 100.0;
  }

  int get ageSeconds {
    if (createdAt == null) return 999;
    return DateTime.now().toUtc().difference(createdAt!.toUtc()).inSeconds;
  }
}
