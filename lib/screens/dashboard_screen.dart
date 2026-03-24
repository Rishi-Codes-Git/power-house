import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import '../models/smart_meter.dart';
import '../utils/app_theme.dart';
import '../services/mqtt_service.dart';
import 'login_screen.dart';
import 'simulation_screen.dart';
import 'prediction_screen.dart';

class DashboardScreen extends StatefulWidget {
  final SmartMeter smartMeter;

  const DashboardScreen({super.key, required this.smartMeter});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final MqttService _mqttService = MqttService();
  StreamSubscription<Map<String, double>>? _metricsSubscription;

  // MQTT metrics with fallback to SmartMeter values
  double? _mqttVoltage;
  double? _mqttCurrent;
  double? _mqttPower;

  @override
  void initState() {
    super.initState();
    _mqttService.registerScreen();
    _connectAndSubscribe();
  }

  Future<void> _connectAndSubscribe() async {
    final connected = await _mqttService.connect();
    if (connected) {
      _metricsSubscription = _mqttService.metricsStream.listen((metrics) {
        setState(() {
          _mqttVoltage = metrics['voltage'];
          _mqttCurrent = metrics['current'];
          _mqttPower = metrics['power'];
        });
      });
    }
  }

  @override
  void dispose() {
    _metricsSubscription?.cancel();
    _mqttService.disposeScreen();
    super.dispose();
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const SimulationScreen();
      case 2:
        return const PredictionScreen();
      default:
        return _buildDashboardContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: _selectedIndex == 0
          ? AppBar(
              backgroundColor: const Color(0xFF111111),
              title: const Text('Power House'),
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  'assets/images/logo.png',
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.electric_bolt, color: Colors.white);
                  },
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => _showLogoutDialog(context),
                ),
              ],
            )
          : null,
      body: _getPage(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        backgroundColor: const Color(0xFF111111),
        indicatorColor: AppTheme.primaryGreen.withAlpha(77),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: Colors.grey),
            selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryGreen),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined, color: Colors.grey),
            selectedIcon: Icon(Icons.tune, color: AppTheme.primaryGreen),
            label: 'Simulate',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined, color: Colors.grey),
            selectedIcon: Icon(Icons.trending_up, color: AppTheme.primaryGreen),
            label: 'Forecast',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meter Info Header
          _buildMeterInfoCard(),
          const SizedBox(height: 16),
          // Real-time Metrics
          _buildSectionTitle('Real-time Metrics'),
          const SizedBox(height: 12),
          _buildRealTimeMetrics(),
          const SizedBox(height: 20),
          // Usage Statistics
          _buildSectionTitle('Usage Statistics'),
          const SizedBox(height: 12),
          _buildUsageStats(),
          const SizedBox(height: 20),
          // Power Chart
          _buildSectionTitle('Today\'s Usage Pattern'),
          const SizedBox(height: 12),
          _buildUsageChart(),
          const SizedBox(height: 20),
          // Solar & Grid Balance
          _buildSectionTitle('Solar-Grid Balance'),
          const SizedBox(height: 12),
          _buildSolarGridBalance(),
          const SizedBox(height: 20),
          // Dynamic Pricing
          _buildSectionTitle('Dynamic Pricing'),
          const SizedBox(height: 12),
          _buildDynamicPricing(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _buildMeterInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meter ID',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      widget.smartMeter.meterId,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                    color: widget.smartMeter.isConnected
                        ? Colors.green[300]
                        : Colors.red[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.smartMeter.isConnected
                            ? Icons.wifi
                            : Icons.wifi_off,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.smartMeter.isConnected ? 'Online' : 'Offline',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMeterInfoItem(
                  'Current Usage',
                  '${widget.smartMeter.currentUsage} kW',
                ),
                _buildMeterInfoItem(
                  'Voltage',
                  '${widget.smartMeter.voltage} V',
                ),
                _buildMeterInfoItem(
                  'Power Factor',
                  widget.smartMeter.powerFactor.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeterInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildRealTimeMetrics() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Voltage',
          '${_mqttVoltage ?? widget.smartMeter.voltage} V',
          Icons.bolt,
          Colors.orange,
        ),
        _buildMetricCard(
          'Current',
          '${(_mqttCurrent ?? widget.smartMeter.current).toStringAsFixed(2)} A',
          Icons.electric_bolt,
          Colors.blue,
        ),
        _buildMetricCard(
          'Power',
          '${(_mqttPower ?? widget.smartMeter.currentUsage).toStringAsFixed(2)} kW',
          Icons.power,
          Colors.purple,
        ),
        _buildMetricCard(
          'Power Factor',
          widget.smartMeter.powerFactor.toString(),
          Icons.speed,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      color: const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withAlpha(20)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageStats() {
    return Card(
      elevation: 0,
      color: const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withAlpha(20)),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildUsageStatItem(
                    'Today',
                    '${widget.smartMeter.todayUsage} kWh',
                    Icons.today,
                    AppTheme.primaryGreen,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.grey.withAlpha(50)),
                Expanded(
                  child: _buildUsageStatItem(
                    'This Month',
                    '${widget.smartMeter.monthlyUsage} kWh',
                    Icons.calendar_month,
                    AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
            Divider(height: 32, color: Colors.grey.withAlpha(50)),
            Row(
              children: [
                Expanded(
                  child: _buildUsageStatItem(
                    'Peak Load',
                    '${widget.smartMeter.peakLoad} kW',
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.grey.withAlpha(50)),
                Expanded(
                  child: _buildUsageStatItem(
                    'Est. Bill',
                    'Rs. ${widget.smartMeter.estimatedBill.toStringAsFixed(2)}',
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageChart() {
    return Card(
      elevation: 0,
      color: const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withAlpha(20)),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 4,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppTheme.darkGreen,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toStringAsFixed(1)} kWh',
                      GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final hour = value.toInt();
                      if (hour % 4 == 0) {
                        return Text(
                          '${hour}h',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(color: Colors.grey.withAlpha(30), strokeWidth: 1);
                },
              ),
              borderData: FlBorderData(show: false),
              barGroups: widget.smartMeter.hourlyData.map((data) {
                return BarChartGroupData(
                  x: data.hour,
                  barRods: [
                    BarChartRodData(
                      toY: data.usage,
                      color: data.usage > 2
                          ? Colors.orange
                          : AppTheme.primaryGreen,
                      width: 8,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSolarGridBalance() {
    final solarPercent =
        (widget.smartMeter.solarGeneration /
            (widget.smartMeter.solarGeneration +
                widget.smartMeter.gridConsumption)) *
        100;

    return Card(
      elevation: 0,
      color: const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withAlpha(20)),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildPowerSourceCard(
                    'Solar Power',
                    '${widget.smartMeter.solarGeneration} kWh',
                    Icons.solar_power,
                    Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPowerSourceCard(
                    'Grid Power',
                    '${widget.smartMeter.gridConsumption} kWh',
                    Icons.electrical_services,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Balance indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Solar Contribution',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${solarPercent.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: solarPercent / 100,
                    minHeight: 12,
                    backgroundColor: Colors.blue.withAlpha(51),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.amber,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLegendItem('Solar', Colors.amber),
                    _buildLegendItem('Grid', Colors.blue),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPowerSourceCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicPricing() {
    return Card(
      elevation: 0,
      color: const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withAlpha(20)),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Rate',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rs. ${widget.smartMeter.currentRate}',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 4),
                          child: Text(
                            '/kWh',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.smartMeter.tariffType,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Time slots
            Row(
              children: [
                Expanded(
                  child: _buildTimeSlot(
                    'Off-Peak',
                    '10PM - 6AM',
                    'Rs. 3.50',
                    AppTheme.accentGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTimeSlot(
                    'Standard',
                    '6AM - 6PM',
                    'Rs. 5.50',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTimeSlot(
                    'Peak',
                    '6PM - 10PM',
                    'Rs. 8.00',
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Best time to use appliances: 10PM - 6AM (Off-Peak)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlot(String name, String time, String rate, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(128)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            time,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.grey,
            ),
          ),
          Text(
            rate,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Text('Logout', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}
