import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../models/transformer_data.dart';
import '../services/thingspeak_service.dart';
import '../services/prediction_service.dart';
import '../services/mqtt_service.dart';

class LiveAnalyticsScreen extends StatefulWidget {
  const LiveAnalyticsScreen({super.key});

  @override
  State<LiveAnalyticsScreen> createState() => _LiveAnalyticsScreenState();
}

class _LiveAnalyticsScreenState extends State<LiveAnalyticsScreen> {
  final ThingSpeakService _thingSpeakService = ThingSpeakService();
  final MqttService _mqttService = MqttService();
  LiveData? _liveData;
  TransformerData? _transformerData;
  HourlyPrediction? _nextHourPrediction;
  PredictiveWarning? _warning;
  StreamSubscription? _subscription;
  bool _isLoading = true;

  // Circuit breaker state
  bool _autoProtectionEnabled = true;
  bool _isTripped = false;
  bool _isMqttConnected = false;
  DateTime? _lastTripTime;

  @override
  void initState() {
    super.initState();
    _mqttService.registerScreen();
    _connectMqtt();
    _startPolling();
  }

  Future<void> _connectMqtt() async {
    try {
      final connected = await _mqttService.connect();
      setState(() => _isMqttConnected = connected);
    } catch (e) {
      setState(() => _isMqttConnected = false);
    }
  }

  void _startPolling() {
    _subscription = _thingSpeakService.liveDataStream.listen(
      (data) {
        setState(() {
          _liveData = data;
          _updateTransformerData(data);
          _isLoading = false;
        });
      },
      onError: (e) {
        setState(() => _isLoading = false);
      },
    );
    _thingSpeakService.startPolling();
  }

  void _updateTransformerData(LiveData data) {
    final loadPct = data.loadPercent.clamp(0.0, 130.0);
    final temp = data.temperature > 0
        ? data.temperature
        : TransformerData.estimateCoreTemperature(loadPct, 32.0);

    _transformerData = TransformerData(
      voltage: data.voltage,
      current: data.current,
      power: data.power,
      temperature: temp,
      loadPercent: loadPct,
      isLive: data.isConnected,
    );

    _nextHourPrediction = PredictionService.getNextHourPrediction(loadPct);
    _warning = PredictionService.getWarning(_nextHourPrediction!.predictedLoad);

    // Auto circuit breaker logic
    _checkAndTripCircuitBreaker();
  }

  Future<void> _checkAndTripCircuitBreaker() async {
    if (!_autoProtectionEnabled || !_isMqttConnected) return;

    final health = _transformerData?.health;
    if (health == null) return;

    // Trip conditions: Critical or Emergency status, or load > 100%
    final shouldTrip =
        health.status == HealthStatus.critical ||
        health.status == HealthStatus.emergency ||
        (_transformerData?.loadPercent ?? 0) > 100;

    if (shouldTrip && !_isTripped) {
      // Trip the transformer (turn off relay 1)
      final success = await _mqttService.allOff();
      if (success) {
        setState(() {
          _isTripped = true;
          _lastTripTime = DateTime.now();
        });
        _showTripNotification();
      }
    }
  }

  void _showTripNotification() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'OVERLOAD DETECTED! Transformer automatically disconnected.',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetCircuitBreaker() async {
    if (!_isMqttConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to ESP32. Please wait...')),
      );
      return;
    }

    // Check if it's safe to reset
    final health = _transformerData?.health;
    if (health != null &&
        (health.status == HealthStatus.critical ||
            health.status == HealthStatus.emergency)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot reset: Transformer still in ${health.statusText} state. Wait for conditions to normalize.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final success = await _mqttService.transformerOn();
    if (success) {
      setState(() => _isTripped = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transformer reconnected', style: GoogleFonts.outfit()),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _thingSpeakService.dispose();
    _mqttService.disposeScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _liveData?.isConnected == true
                    ? Colors.green
                    : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color:
                        (_liveData?.isConnected == true
                                ? Colors.green
                                : Colors.red)
                            .withAlpha(128),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Live Analytics',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _thingSpeakService.fetchOnce().then((data) {
                if (data != null) {
                  setState(() {
                    _liveData = data;
                    _updateTransformerData(data);
                    _isLoading = false;
                  });
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection Status Card
          _buildConnectionStatusCard(),
          const SizedBox(height: 16),

          // Circuit Breaker Control
          _buildCircuitBreakerControl(),
          const SizedBox(height: 16),

          // Health Indicator
          _buildHealthIndicator(),
          const SizedBox(height: 16),

          // Load Gauge
          _buildLoadGauge(),
          const SizedBox(height: 16),

          // Live Parameters
          _buildLiveParameters(),
          const SizedBox(height: 16),

          // Next Hour Prediction
          _buildNextHourPrediction(),
          const SizedBox(height: 16),

          // Predictive Warning
          if (_warning != null) _buildWarningCard(),
          const SizedBox(height: 16),

          // Dynamic Pricing
          _buildDynamicPricing(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    final isConnected = _liveData?.isConnected ?? false;
    final age = _liveData?.ageSeconds ?? 999;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? Colors.green.withAlpha(100)
              : Colors.red.withAlpha(100),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.sensors : Icons.sensors_off,
            color: isConnected ? Colors.green : Colors.red,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'ESP32 Connected' : 'ESP32 Disconnected',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isConnected
                      ? 'Last update: ${age}s ago'
                      : 'No data received in last 20s',
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(50),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.outfit(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCircuitBreakerControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isTripped
              ? Colors.red.withAlpha(150)
              : _isMqttConnected
                  ? Colors.green.withAlpha(100)
                  : Colors.orange.withAlpha(100),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                color: _isTripped ? Colors.red : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'CIRCUIT BREAKER',
                style: GoogleFonts.outfit(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isMqttConnected
                      ? Colors.green.withAlpha(50)
                      : Colors.orange.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isMqttConnected ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isMqttConnected ? 'ESP32 Online' : 'Connecting...',
                      style: GoogleFonts.outfit(
                        color: _isMqttConnected ? Colors.green : Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Breaker Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isTripped
                  ? Colors.red.withAlpha(30)
                  : Colors.green.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isTripped
                    ? Colors.red.withAlpha(100)
                    : Colors.green.withAlpha(100),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isTripped ? Colors.red : Colors.green,
                    boxShadow: [
                      BoxShadow(
                        color: (_isTripped ? Colors.red : Colors.green)
                            .withAlpha(150),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isTripped ? Icons.power_off : Icons.power,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isTripped ? 'TRANSFORMER TRIPPED' : 'TRANSFORMER ACTIVE',
                        style: GoogleFonts.outfit(
                          color: _isTripped ? Colors.red : Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isTripped
                            ? 'Disconnected due to overload protection'
                            : 'Operating normally',
                        style: GoogleFonts.outfit(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      if (_lastTripTime != null && _isTripped)
                        Text(
                          'Tripped at: ${_lastTripTime!.hour}:${_lastTripTime!.minute.toString().padLeft(2, '0')}',
                          style: GoogleFonts.outfit(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Auto Protection Toggle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto Overload Protection',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Automatically trips when load > 100% or critical state',
                      style: GoogleFonts.outfit(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _autoProtectionEnabled,
                onChanged: (value) {
                  setState(() => _autoProtectionEnabled = value);
                },
                activeTrackColor: Colors.green.withAlpha(100),
                activeThumbColor: Colors.green,
              ),
            ],
          ),

          // Reset Button (only show when tripped)
          if (_isTripped) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isMqttConnected ? _resetCircuitBreaker : null,
                icon: const Icon(Icons.restart_alt),
                label: Text(
                  'RESET & RECONNECT TRANSFORMER',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthIndicator() {
    final health = _transformerData?.health;
    if (health == null) return const SizedBox();

    Color healthColor;
    switch (health.status) {
      case HealthStatus.healthy:
        healthColor = Colors.green;
        break;
      case HealthStatus.stressed:
        healthColor = Colors.yellow;
        break;
      case HealthStatus.warning:
        healthColor = Colors.orange;
        break;
      case HealthStatus.critical:
      case HealthStatus.emergency:
        healthColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        children: [
          Text(
            'TRANSFORMER HEALTH',
            style: GoogleFonts.outfit(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Health Score Circle
              CircularPercentIndicator(
                radius: 70,
                lineWidth: 12,
                percent: (health.healthScore / 100).clamp(0.0, 1.0),
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${health.healthScore.toInt()}%',
                      style: GoogleFonts.outfit(
                        color: healthColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      health.statusText,
                      style: GoogleFonts.outfit(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                progressColor: healthColor,
                backgroundColor: Colors.grey.withAlpha(50),
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
              ),

              // Status Indicators
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusRow(
                    'Load',
                    health.loadStateText,
                    health.loadState.index <= 1,
                  ),
                  const SizedBox(height: 8),
                  _buildStatusRow(
                    'Temp',
                    health.temperatureStateText,
                    health.temperatureState.index <= 1,
                  ),
                  const SizedBox(height: 8),
                  _buildStatusRow(
                    'Voltage',
                    health.voltageNormal ? 'Normal' : 'Abnormal',
                    health.voltageNormal,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String status, bool isGood) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isGood ? Colors.green : Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
        ),
        Text(
          status,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadGauge() {
    final load = _transformerData?.loadPercent ?? 0;

    Color loadColor;
    String loadZone;
    if (load < TransformerConstants.safeLoadPct) {
      loadColor = Colors.green;
      loadZone = 'Safe Zone';
    } else if (load <= TransformerConstants.heavyLoadPct) {
      loadColor = Colors.orange;
      loadZone = 'Heavy Zone';
    } else if (load <= TransformerConstants.overloadLoadPct) {
      loadColor = Colors.deepOrange;
      loadZone = 'Near Rated';
    } else {
      loadColor = Colors.red;
      loadZone = 'OVERLOAD';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        children: [
          Text(
            'CURRENT LOAD',
            style: GoogleFonts.outfit(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: 0,
                  maximum: 130,
                  showLabels: true,
                  showTicks: true,
                  axisLineStyle: const AxisLineStyle(
                    thickness: 0.15,
                    color: Color(0xFF333333),
                    thicknessUnit: GaugeSizeUnit.factor,
                  ),
                  labelFormat: '{value}%',
                  labelsPosition: ElementsPosition.outside,
                  axisLabelStyle: GaugeTextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontFamily: GoogleFonts.outfit().fontFamily,
                  ),
                  ranges: <GaugeRange>[
                    GaugeRange(
                      startValue: 0,
                      endValue: 80,
                      color: Colors.green.withAlpha(100),
                      startWidth: 20,
                      endWidth: 20,
                    ),
                    GaugeRange(
                      startValue: 80,
                      endValue: 95,
                      color: Colors.orange.withAlpha(100),
                      startWidth: 20,
                      endWidth: 20,
                    ),
                    GaugeRange(
                      startValue: 95,
                      endValue: 100,
                      color: Colors.deepOrange.withAlpha(100),
                      startWidth: 20,
                      endWidth: 20,
                    ),
                    GaugeRange(
                      startValue: 100,
                      endValue: 130,
                      color: Colors.red.withAlpha(100),
                      startWidth: 20,
                      endWidth: 20,
                    ),
                  ],
                  pointers: <GaugePointer>[
                    NeedlePointer(
                      value: load,
                      needleLength: 0.6,
                      needleStartWidth: 1,
                      needleEndWidth: 5,
                      knobStyle: const KnobStyle(
                        knobRadius: 0.08,
                        color: Colors.white,
                      ),
                      needleColor: loadColor,
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${load.toStringAsFixed(1)}%',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: loadColor,
                            ),
                          ),
                          Text(
                            loadZone,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      angle: 90,
                      positionFactor: 0.7,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveParameters() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIVE PARAMETERS',
            style: GoogleFonts.outfit(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildParameterCard(
                  'Voltage',
                  '${_liveData?.voltage.toStringAsFixed(1) ?? '0'} V',
                  Icons.bolt,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildParameterCard(
                  'Current',
                  '${_liveData?.current.toStringAsFixed(2) ?? '0'} A',
                  Icons.electric_bolt,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildParameterCard(
                  'Power',
                  '${_liveData?.power.toStringAsFixed(2) ?? '0'} kW',
                  Icons.power,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildParameterCard(
                  'Temperature',
                  '${_transformerData?.temperature.toStringAsFixed(1) ?? '0'} C',
                  Icons.thermostat,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParameterCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextHourPrediction() {
    if (_nextHourPrediction == null) return const SizedBox();

    final pred = _nextHourPrediction!;
    final isHighRisk = pred.isHighRisk;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighRisk
              ? Colors.red.withAlpha(100)
              : Colors.green.withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: isHighRisk ? Colors.red : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'NEXT HOUR PREDICTION (LSTM)',
                style: GoogleFonts.outfit(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Predicted Load',
                      style: GoogleFonts.outfit(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${pred.predictedLoad.toStringAsFixed(1)}%',
                      style: GoogleFonts.outfit(
                        color: isHighRisk ? Colors.red : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Est. Price',
                      style: GoogleFonts.outfit(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Rs. ${pred.predictedPrice.toStringAsFixed(2)}/kWh',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isHighRisk ? Colors.red : Colors.green).withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: isHighRisk ? Colors.red : Colors.green,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pred.suggestion,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    final warning = _warning!;

    Color warningColor;
    IconData warningIcon;
    switch (warning.severity) {
      case WarningSeverity.stable:
        warningColor = Colors.green;
        warningIcon = Icons.check_circle;
        break;
      case WarningSeverity.high:
        warningColor = Colors.yellow;
        warningIcon = Icons.warning;
        break;
      case WarningSeverity.overload:
        warningColor = Colors.orange;
        warningIcon = Icons.warning_amber;
        break;
      case WarningSeverity.critical:
        warningColor = Colors.red;
        warningIcon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningColor.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warningColor.withAlpha(100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warningIcon, color: warningColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning.title,
                  style: GoogleFonts.outfit(
                    color: warningColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  warning.action,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicPricing() {
    final price = _transformerData?.dynamicPrice ?? 4.50;
    final tier = _transformerData?.tariffTier ?? 'Base Tariff';

    Color tierColor;
    switch (tier) {
      case 'Base Tariff':
        tierColor = Colors.green;
        break;
      case 'Congested Tariff':
        tierColor = Colors.yellow;
        break;
      case 'Peak-Stress Tariff':
        tierColor = Colors.orange;
        break;
      default:
        tierColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DYNAMIC PRICING',
            style: GoogleFonts.outfit(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Rate',
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Rs. ${price.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            color: tierColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: '/kWh',
                          style: GoogleFonts.outfit(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tierColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tierColor.withAlpha(100)),
                ),
                child: Text(
                  tier,
                  style: GoogleFonts.outfit(
                    color: tierColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
