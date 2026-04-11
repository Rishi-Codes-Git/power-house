import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../utils/app_theme.dart';
import '../services/mqtt_service.dart';

class SocketControlScreen extends StatefulWidget {
  const SocketControlScreen({super.key});

  @override
  State<SocketControlScreen> createState() => _SocketControlScreenState();
}

class _SocketControlScreenState extends State<SocketControlScreen> {
  final MqttService _mqttService = MqttService();
  StreamSubscription<Map<String, RelaySnapshot>>? _relaySubscription;
  StreamSubscription<bool>? _connectionSubscription;

  // Relay states
  Map<String, RelaySnapshot> _relays = {};
  double _relayVoltage = 0.0;
  bool _isMqttConnected = false;

  @override
  void initState() {
    super.initState();
    _mqttService.registerScreen();
    _listenToRelayData();
  }

  void _listenToRelayData() {
    _relaySubscription = _mqttService.relayStream.listen((relays) {
      if (!mounted) return;
      setState(() {
        _relays = relays;
        _relayVoltage = _mqttService.relayVoltage;
      });
    });

    _connectionSubscription = _mqttService.connectionStream.listen((isConnected) {
      if (!mounted) return;
      setState(() {
        _isMqttConnected = isConnected;
      });
    });
  }

  @override
  void dispose() {
    _relaySubscription?.cancel();
    _connectionSubscription?.cancel();
    _mqttService.disposeScreen();
    super.dispose();
  }

  Future<void> _setRelayMode(int relayNumber, RelayMode mode) async {
    try {
      await _mqttService.setRelayMode(relayNumber, mode);
    } catch (e) {
      print('Error setting relay mode: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Section
              Center(
                child: Text(
                  'SOCKET CONTROL',
                  style: GoogleFonts.outfit(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Connection Status
              _buildConnectionStatus(),
              const SizedBox(height: 20),

              // Relay Voltage Header
              Text(
                'Relay Voltage',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Total Voltage Card
              _buildVoltageCard(),
              const SizedBox(height: 28),

              // Relays Section
              Text(
                'Relay Controls',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Relay 1
              _buildRelayControl(1),
              const SizedBox(height: 16),

              // Relay 2
              _buildRelayControl(2),
              const SizedBox(height: 16),

              // Relay 3
              _buildRelayControl(3),
              const SizedBox(height: 16),

              // Relay 4
              _buildRelayControl(4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isMqttConnected ? Colors.green.withAlpha(100) : Colors.red.withAlpha(100),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isMqttConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isMqttConnected ? Colors.green : Colors.red).withAlpha(150),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isMqttConnected ? 'MQTT Connected' : 'MQTT Disconnected',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _isMqttConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoltageCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withAlpha(80),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Voltage',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_relayVoltage.toStringAsFixed(1)} V',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Icon(
            Icons.bolt,
            size: 48,
            color: AppTheme.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildRelayControl(int relayNumber) {
    final key = 'relay$relayNumber';
    final relay = _relays[key];
    final current = relay?.current ?? 0.0;
    final mode = relay?.inferredMode ?? RelayMode.off;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[800]!,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and current
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Relay $relayNumber',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current: ${current.toStringAsFixed(2)} A',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getModeColor(mode).withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getModeColor(mode).withAlpha(100),
                  ),
                ),
                child: Text(
                  _getModeName(mode),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getModeColor(mode),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Control buttons
          Row(
            children: [
              // GRID button
              Expanded(
                child: _buildModeButton(
                  relayNumber,
                  RelayMode.grid,
                  '⚡ GRID',
                  mode == RelayMode.grid,
                ),
              ),
              const SizedBox(width: 8),

              // SOLAR button
              Expanded(
                child: _buildModeButton(
                  relayNumber,
                  RelayMode.solar,
                  '☀️ SOLAR',
                  mode == RelayMode.solar,
                ),
              ),
              const SizedBox(width: 8),

              // OFF button
              Expanded(
                child: _buildModeButton(
                  relayNumber,
                  RelayMode.off,
                  'OFF',
                  mode == RelayMode.off,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    int relayNumber,
    RelayMode mode,
    String label,
    bool isActive,
  ) {
    final color = _getModeColor(mode);

    return GestureDetector(
      onTap: () => _setRelayMode(relayNumber, mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? color.withAlpha(80)
              : const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? color.withAlpha(200)
                : Colors.grey[700]!,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? color : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }

  Color _getModeColor(RelayMode mode) {
    switch (mode) {
      case RelayMode.grid:
        return const Color(0xFFFF9800); // Orange
      case RelayMode.solar:
        return const Color(0xFFFFD700); // Gold/Yellow
      case RelayMode.off:
        return const Color(0xFF999999); // Grey
    }
  }

  String _getModeName(RelayMode mode) {
    switch (mode) {
      case RelayMode.grid:
        return 'GRID';
      case RelayMode.solar:
        return 'SOLAR';
      case RelayMode.off:
        return 'OFF';
    }
  }
}
