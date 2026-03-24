import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'dart:async';
import '../models/transformer_data.dart';
import '../services/mqtt_service.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  final MqttService _mqttService = MqttService();

  // Simulation parameters
  double _loadPercent = 60.0;
  double _voltage = 415.0;
  double _ambientTemp = 32.0;
  double _powerFactor = 0.90;

  // Cached simulation data for accurate health updates
  TransformerData? _cachedSimulatedData;

  // Relay states
  bool _relay1On = false; // Transformer
  bool _relay2On = false; // Solar

  bool _isConnecting = false;
  bool _isMqttConnected = false;

  // Auto relay switching state
  Timer? _healthCheckTimer;
  DateTime? _healthBelowFiftyStart;
  DateTime? _healthBelowEightyStart;
  bool _autoRelayEnabled = true;

  // Timer countdown display
  int _countdownSeconds = 0;
  String _countdownReason = '';

  @override
  void initState() {
    super.initState();
    _mqttService.registerScreen();
    _connectMqtt();
    _startHealthMonitor();
  }

  Future<void> _connectMqtt() async {
    setState(() => _isConnecting = true);
    try {
      final connected = await _mqttService.connect();
      setState(() {
        _isMqttConnected = connected;
        _isConnecting = false;
      });
      if (connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected to MQTT Relay Control')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${_mqttService.lastStatus}'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isMqttConnected = false;
        _isConnecting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _startHealthMonitor() {
    _healthCheckTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _checkHealthAndAutoSwitch(),
    );
  }

  void _checkHealthAndAutoSwitch() {
    if (!_autoRelayEnabled || !_isMqttConnected) {
      setState(() {
        _countdownSeconds = 0;
        _countdownReason = '';
      });
      return;
    }

    final health = _simulatedData.health;
    final healthScore = health.healthScore;
    final now = DateTime.now();

    // Track when health dropped below thresholds
    if (healthScore < 50) {
      _healthBelowFiftyStart ??= now;
      _healthBelowEightyStart ??= now;
    } else if (healthScore < 80) {
      _healthBelowFiftyStart = null;
      _healthBelowEightyStart ??= now;
    } else {
      _healthBelowFiftyStart = null;
      _healthBelowEightyStart = null;
    }

    // Check if we should auto-switch to solar
    bool shouldSwitchToSolar = false;
    String reason = '';

    // Health < 50% for 2 seconds
    if (_healthBelowFiftyStart != null) {
      final duration = now.difference(_healthBelowFiftyStart!);
      final remaining = 2 - duration.inSeconds;
      if (duration.inSeconds >= 2) {
        shouldSwitchToSolar = true;
        reason = 'Health below 50% for 2+ seconds';
      } else if (!_relay2On) {
        setState(() {
          _countdownSeconds = remaining > 0 ? remaining : 0;
          _countdownReason = 'Health < 50%';
        });
      }
    }

    // Health < 80% for 5 seconds
    if (!shouldSwitchToSolar && _healthBelowEightyStart != null) {
      final duration = now.difference(_healthBelowEightyStart!);
      final remaining = 5 - duration.inSeconds;
      if (duration.inSeconds >= 5) {
        shouldSwitchToSolar = true;
        reason = 'Health below 80% for 5+ seconds';
      } else if (!_relay2On && _healthBelowFiftyStart == null) {
        setState(() {
          _countdownSeconds = remaining > 0 ? remaining : 0;
          _countdownReason = 'Health < 80%';
        });
      }
    }

    // Clear countdown if health is good
    if (_healthBelowFiftyStart == null && _healthBelowEightyStart == null) {
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds = 0;
          _countdownReason = '';
        });
      }
    }

    // Execute auto-switch if needed and not already on solar
    if (shouldSwitchToSolar && !_relay2On) {
      _autoSwitchToSolar(reason);
    }
  }

  Future<void> _autoSwitchToSolar(String reason) async {
    final success = await _mqttService.solarOn();
    if (success) {
      setState(() {
        _relay1On = false;
        _relay2On = true;
        _countdownSeconds = 0;
        _countdownReason = '';
      });

      // Reset tracking
      _healthBelowFiftyStart = null;
      _healthBelowEightyStart = null;

      // Show notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.solar_power, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AUTO-SWITCHED TO SOLAR\n$reason',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.amber[700],
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _mqttService.disposeScreen();
    super.dispose();
  }

  // Calculate derived values based on simulation inputs
  TransformerData get _simulatedData {
    // Recalculate if cache is invalid
    if (_cachedSimulatedData == null) {
      _cachedSimulatedData = _calculateSimulatedData();
    }
    return _cachedSimulatedData!;
  }

  TransformerData _calculateSimulatedData() {
    final currentA = TransformerData.loadPctToCurrentA(_loadPercent, _voltage);
    final kva = TransformerData.loadPctToKVA(_loadPercent);
    final powerKW = kva * _powerFactor;
    final temperature = TransformerData.estimateCoreTemperature(
      _loadPercent,
      _ambientTemp,
    );

    return TransformerData(
      voltage: _voltage,
      current: currentA,
      power: powerKW,
      temperature: temperature,
      loadPercent: _loadPercent,
      powerFactor: _powerFactor,
    );
  }

  void _invalidateCache() {
    _cachedSimulatedData = null;
  }

  Future<void> _toggleTransformer() async {
    if (!_isMqttConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MQTT not connected. Please connect first.'),
        ),
      );
      return;
    }

    try {
      if (_relay1On) {
        // Turn off transformer
        final success = await _mqttService.allOff();
        if (success) {
          setState(() {
            _relay1On = false;
            _relay2On = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transformer turned OFF'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${_mqttService.lastStatus}')),
          );
        }
      } else {
        // Turn on transformer
        final success = await _mqttService.transformerOn();
        if (success) {
          setState(() {
            _relay1On = true;
            _relay2On = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transformer turned ON'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${_mqttService.lastStatus}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleSolar() async {
    if (!_isMqttConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MQTT not connected. Please connect first.'),
        ),
      );
      return;
    }

    try {
      if (_relay2On) {
        // Turn off solar
        final success = await _mqttService.allOff();
        if (success) {
          setState(() {
            _relay1On = false;
            _relay2On = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solar Panel turned OFF'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${_mqttService.lastStatus}')),
          );
        }
      } else {
        // Turn on solar
        final success = await _mqttService.solarOn();
        if (success) {
          setState(() {
            _relay1On = false;
            _relay2On = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solar Panel turned ON'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${_mqttService.lastStatus}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: Text(
          'Simulation',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isMqttConnected
                  ? Colors.green.withAlpha(50)
                  : Colors.red.withAlpha(50),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isMqttConnected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnecting
                      ? 'Connecting...'
                      : _isMqttConnected
                      ? 'MQTT'
                      : 'Offline',
                  style: GoogleFonts.outfit(
                    color: _isMqttConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Health Status (top)
            _buildHealthPreview(),
            const SizedBox(height: 20),

            // Simulation Parameters
            _buildSimulationControls(),
            const SizedBox(height: 20),

            // Simulated Output
            _buildSimulatedOutput(),
            const SizedBox(height: 20),

            // Relay Control (bottom)
            _buildRelayControlPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildRelayControlPanel() {
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
          Row(
            children: [
              Icon(Icons.settings_remote, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'RELAY CONTROL',
                style: GoogleFonts.outfit(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isMqttConnected
                      ? Colors.green.withAlpha(50)
                      : Colors.red.withAlpha(50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isMqttConnected ? 'Connected' : 'Disconnected',
                  style: GoogleFonts.outfit(
                    color: _isMqttConnected ? Colors.green : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Control transformer and solar panel switching',
                style: GoogleFonts.outfit(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              if (!_isMqttConnected)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isConnecting ? null : _connectMqtt,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _isConnecting ? 'Connecting...' : 'Reconnect',
                        style: GoogleFonts.outfit(
                          color: Colors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Relay Status Indicators
          Row(
            children: [
              Expanded(
                child: _buildRelayIndicator(
                  'Relay 1',
                  'Transformer',
                  _relay1On,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRelayIndicator(
                  'Relay 2',
                  'Solar Panel',
                  _relay2On,
                  Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Control Buttons
          Row(
            children: [
              Expanded(
                child: _buildControlButton(
                  'Transformer',
                  _relay1On ? 'ON' : 'OFF',
                  Icons.power,
                  _relay1On ? Colors.green : Colors.grey,
                  _toggleTransformer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildControlButton(
                  'Solar Panel',
                  _relay2On ? 'ON' : 'OFF',
                  Icons.solar_power,
                  _relay2On ? Colors.amber : Colors.grey,
                  _toggleSolar,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Current Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _relay1On
                      ? Icons.electrical_services
                      : _relay2On
                      ? Icons.wb_sunny
                      : Icons.power_off,
                  color: _relay1On
                      ? Colors.blue
                      : _relay2On
                      ? Colors.amber
                      : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _relay1On
                        ? 'Power Source: Grid Transformer (GPIO 26)'
                        : _relay2On
                        ? 'Power Source: Solar Panel (GPIO 27)'
                        : 'Power Source: Disconnected',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (!_isMqttConnected)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withAlpha(50)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MQTT not connected. Tap "Reconnect" to establish connection.',
                      style: GoogleFonts.outfit(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Auto Relay Switching Toggle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _autoRelayEnabled
                    ? Colors.green.withAlpha(50)
                    : Colors.grey.withAlpha(50),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_mode,
                  color: _autoRelayEnabled ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto Solar Switching',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Auto-switch to solar when health is critical',
                        style: GoogleFonts.outfit(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _autoRelayEnabled,
                  onChanged: (value) {
                    setState(() => _autoRelayEnabled = value);
                    if (!value) {
                      // Reset tracking when disabled
                      _healthBelowFiftyStart = null;
                      _healthBelowEightyStart = null;
                    }
                  },
                  activeTrackColor: Colors.green.withAlpha(100),
                  activeThumbColor: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelayIndicator(
    String relay,
    String label,
    bool isOn,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOn ? color.withAlpha(30) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOn ? color.withAlpha(100) : Colors.grey.withAlpha(50),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOn ? color : Colors.grey.withAlpha(100),
              boxShadow: isOn
                  ? [
                      BoxShadow(
                        color: color.withAlpha(128),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                isOn ? Icons.power : Icons.power_off,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            relay,
            style: GoogleFonts.outfit(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isOn ? 'ACTIVE' : 'INACTIVE',
            style: GoogleFonts.outfit(
              color: isOn ? color : Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    String label,
    String status,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isMqttConnected ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _isMqttConnected
                ? color.withAlpha(30)
                : Colors.grey.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isMqttConnected
                  ? color.withAlpha(100)
                  : Colors.grey.withAlpha(50),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: _isMqttConnected ? color : Colors.grey.withAlpha(100),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: _isMqttConnected ? Colors.white : Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _isMqttConnected
                      ? color.withAlpha(50)
                      : Colors.grey.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.outfit(
                    color: _isMqttConnected ? color : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimulationControls() {
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
          Row(
            children: [
              Icon(Icons.tune, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                'SIMULATION PARAMETERS',
                style: GoogleFonts.outfit(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Adjust parameters to simulate transformer behavior',
            style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Load Percentage Slider
          _buildSlider(
            'Transformer Load',
            _loadPercent,
            0,
            130,
            '${_loadPercent.toInt()}%',
            (value) => setState(() {
              _loadPercent = value;
              _invalidateCache();
            }),
            _getLoadColor(_loadPercent),
          ),
          const SizedBox(height: 20),

          // Voltage Slider
          _buildSlider(
            'Line Voltage (L-L)',
            _voltage,
            360,
            470,
            '${_voltage.toInt()} V',
            (value) => setState(() {
              _voltage = value;
              _invalidateCache();
            }),
            Colors.amber,
          ),
          const SizedBox(height: 20),

          // Ambient Temperature Slider
          _buildSlider(
            'Ambient Temperature',
            _ambientTemp,
            20,
            50,
            '${_ambientTemp.toInt()} C',
            (value) => setState(() {
              _ambientTemp = value;
              _invalidateCache();
            }),
            Colors.orange,
          ),
          const SizedBox(height: 20),

          // Power Factor Slider
          _buildSlider(
            'Power Factor',
            _powerFactor,
            0.75,
            0.95,
            _powerFactor.toStringAsFixed(2),
            (value) => setState(() {
              _powerFactor = value;
              _invalidateCache();
            }),
            Colors.cyan,
          ),
        ],
      ),
    );
  }

  Color _getLoadColor(double load) {
    if (load < TransformerConstants.safeLoadPct) return Colors.green;
    if (load <= TransformerConstants.heavyLoadPct) return Colors.orange;
    if (load <= TransformerConstants.overloadLoadPct) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    String displayValue,
    ValueChanged<double> onChanged,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayValue,
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: Colors.grey.withAlpha(50),
            thumbColor: Colors.white,
            overlayColor: color.withAlpha(50),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildSimulatedOutput() {
    final data = _simulatedData;

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
            'SIMULATED OUTPUT',
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
                child: _buildOutputCard(
                  'Current',
                  '${data.current.toStringAsFixed(1)} A',
                  Icons.electric_bolt,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutputCard(
                  'Power',
                  '${data.power.toStringAsFixed(1)} kW',
                  Icons.power,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOutputCard(
                  'Core Temp',
                  '${data.temperature.toStringAsFixed(1)} C',
                  Icons.thermostat,
                  _getTempColor(data.temperature),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutputCard(
                  'Price',
                  'Rs. ${data.dynamicPrice.toStringAsFixed(2)}',
                  Icons.attach_money,
                  _getPriceColor(data.dynamicPrice),
                ),
              ),
            ],
          ),
          // Auto-switch countdown timer
          if (_countdownSeconds > 0 && _autoRelayEnabled && !_relay2On)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildCountdownTimer(),
            ),
        ],
      ),
    );
  }

  Widget _buildCountdownTimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withAlpha(30),
            Colors.orange.withAlpha(30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withAlpha(100), width: 2),
      ),
      child: Row(
        children: [
          // Animated timer icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withAlpha(50),
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Center(
              child: Text(
                '$_countdownSeconds',
                style: GoogleFonts.outfit(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer, color: Colors.amber, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'AUTO-SWITCH COUNTDOWN',
                      style: GoogleFonts.outfit(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$_countdownReason - switching to Solar in $_countdownSeconds sec',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _countdownReason == 'Health < 50%'
                        ? (2 - _countdownSeconds) / 2
                        : (5 - _countdownSeconds) / 5,
                    minHeight: 6,
                    backgroundColor: Colors.grey.withAlpha(50),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTempColor(double temp) {
    if (temp <= TransformerConstants.tempNormalMaxC) return Colors.green;
    if (temp <= TransformerConstants.tempWarningC) return Colors.orange;
    return Colors.red;
  }

  Color _getPriceColor(double price) {
    if (price <= 5.0) return Colors.green;
    if (price <= 8.0) return Colors.orange;
    return Colors.red;
  }

  Widget _buildOutputCard(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthPreview() {
    final health = _simulatedData.health;

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
        border: Border.all(color: healthColor.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(
            'SIMULATED HEALTH STATUS',
            style: GoogleFonts.outfit(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          CircularPercentIndicator(
            radius: 60,
            lineWidth: 10,
            percent: (health.healthScore / 100).clamp(0.0, 1.0),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${health.healthScore.toInt()}%',
                  style: GoogleFonts.outfit(
                    color: healthColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  health.statusText,
                  style: GoogleFonts.outfit(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            progressColor: healthColor,
            backgroundColor: Colors.grey.withAlpha(50),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 500,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHealthChip(
                'Load',
                health.loadStateText,
                health.loadState.index <= 1,
              ),
              _buildHealthChip(
                'Temp',
                health.temperatureStateText,
                health.temperatureState.index <= 1,
              ),
              _buildHealthChip(
                'Voltage',
                health.voltageNormal ? 'OK' : 'Bad',
                health.voltageNormal,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: healthColor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: healthColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getHealthAdvice(health),
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

  Widget _buildHealthChip(String label, String value, bool isGood) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isGood ? Colors.green : Colors.orange).withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: isGood ? Colors.green : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getHealthAdvice(TransformerHealth health) {
    switch (health.status) {
      case HealthStatus.healthy:
        return 'Transformer operating within safe parameters. All systems normal.';
      case HealthStatus.stressed:
        return 'Transformer is under moderate stress. Consider reducing load if possible.';
      case HealthStatus.warning:
        return 'Warning: High load or temperature detected. Take action to prevent damage.';
      case HealthStatus.critical:
        return 'Critical: Immediate action required! Reduce load or risk equipment damage.';
      case HealthStatus.emergency:
        return 'EMERGENCY: Shutdown may be imminent! Take immediate corrective action.';
    }
  }
}
