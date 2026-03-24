import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transformer_data.dart';
import '../services/prediction_service.dart';
import '../services/thingspeak_service.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final ThingSpeakService _thingSpeakService = ThingSpeakService();
  List<HourlyPrediction> _predictions = [];
  List<HourlyPrediction> _bestTimes = [];
  List<HourlyPrediction> _peakHours = [];
  double _currentLoad = 60.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Try to get live data first
    final liveData = await _thingSpeakService.fetchOnce();
    if (liveData != null) {
      _currentLoad = liveData.loadPercent.clamp(20.0, 100.0);
    }

    // Generate predictions
    _predictions = PredictionService.generate24HourPredictions(_currentLoad);
    _bestTimes = PredictionService.getBestTimes(_currentLoad);
    _peakHours = PredictionService.getPeakHours(_currentLoad);

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: Text(
          'Demand Forecast',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Load Banner
                  _buildCurrentLoadBanner(),
                  const SizedBox(height: 20),

                  // 24 Hour Forecast Chart
                  _buildForecastChart(),
                  const SizedBox(height: 20),

                  // Best Times to Use
                  _buildBestTimesCard(),
                  const SizedBox(height: 20),

                  // Peak Hours Warning
                  _buildPeakHoursCard(),
                  const SizedBox(height: 20),

                  // Hourly Breakdown
                  _buildHourlyBreakdown(),
                  const SizedBox(height: 20),

                  // Usage Suggestions
                  _buildUsageSuggestions(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentLoadBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withAlpha(50), Colors.purple.withAlpha(50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withAlpha(100)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.trending_up, color: Colors.blue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Load',
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  '${_currentLoad.toStringAsFixed(1)}%',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'LSTM Model',
                style: GoogleFonts.outfit(
                  color: Colors.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '24h Forecast',
                  style: GoogleFonts.outfit(
                    color: Colors.green,
                    fontSize: 11,
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

  Widget _buildForecastChart() {
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
            '24-HOUR LOAD FORECAST',
            style: GoogleFonts.outfit(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Predicted transformer load using LSTM model',
            style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withAlpha(30),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= _predictions.length) {
                          return const SizedBox();
                        }
                        final hour = _predictions[value.toInt()].hour;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${hour}h',
                            style: GoogleFonts.outfit(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: GoogleFonts.outfit(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 23,
                minY: 0,
                maxY: 130,
                lineBarsData: [
                  // Safe zone line
                  LineChartBarData(
                    spots: List.generate(
                      24,
                      (i) => FlSpot(
                        i.toDouble(),
                        TransformerConstants.safeLoadPct,
                      ),
                    ),
                    isCurved: false,
                    color: Colors.green.withAlpha(100),
                    barWidth: 1,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                  // Critical zone line
                  LineChartBarData(
                    spots: List.generate(
                      24,
                      (i) => FlSpot(
                        i.toDouble(),
                        TransformerConstants.overloadLoadPct,
                      ),
                    ),
                    isCurved: false,
                    color: Colors.red.withAlpha(100),
                    barWidth: 1,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                  // Prediction line
                  LineChartBarData(
                    spots: List.generate(
                      _predictions.length,
                      (i) =>
                          FlSpot(i.toDouble(), _predictions[i].predictedLoad),
                    ),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final load = _predictions[index].predictedLoad;
                        Color dotColor;
                        if (load < TransformerConstants.safeLoadPct) {
                          dotColor = Colors.green;
                        } else if (load <= TransformerConstants.heavyLoadPct) {
                          dotColor = Colors.orange;
                        } else {
                          dotColor = Colors.red;
                        }
                        return FlDotCirclePainter(
                          radius: 4,
                          color: dotColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withAlpha(50),
                          Colors.purple.withAlpha(20),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF222222),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        if (spot.barIndex == 2 &&
                            spot.spotIndex < _predictions.length) {
                          final pred = _predictions[spot.spotIndex];
                          return LineTooltipItem(
                            '${pred.hourLabel}\n${pred.predictedLoad.toStringAsFixed(1)}%\nRs. ${pred.predictedPrice.toStringAsFixed(2)}',
                            GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Safe Zone', Colors.green),
              const SizedBox(width: 20),
              _buildLegendItem('Critical', Colors.red),
              const SizedBox(width: 20),
              _buildLegendItem('Forecast', Colors.blue),
            ],
          ),
        ],
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
          style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildBestTimesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'BEST TIMES FOR HEAVY APPLIANCES',
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
          ..._bestTimes
              .take(4)
              .map(
                (pred) => _buildTimeRow(
                  pred.hourLabel,
                  '${pred.predictedLoad.toStringAsFixed(0)}%',
                  'Rs. ${pred.predictedPrice.toStringAsFixed(2)}',
                  Colors.green,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildPeakHoursCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'AVOID THESE PEAK HOURS',
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
          ..._peakHours
              .take(4)
              .map(
                (pred) => _buildTimeRow(
                  pred.hourLabel,
                  '${pred.predictedLoad.toStringAsFixed(0)}%',
                  'Rs. ${pred.predictedPrice.toStringAsFixed(2)}',
                  pred.isHighRisk ? Colors.red : Colors.orange,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(String time, String load, String price, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              time,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              load,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              price,
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyBreakdown() {
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
            'HOURLY BREAKDOWN',
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
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 130,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF222222),
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final pred = _predictions[group.x.toInt()];
                      return BarTooltipItem(
                        '${pred.hourLabel}\n${pred.predictedLoad.toStringAsFixed(1)}%',
                        GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() % 4 != 0) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${value.toInt()}h',
                            style: GoogleFonts.outfit(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 40,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: GoogleFonts.outfit(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 40,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withAlpha(30),
                      strokeWidth: 1,
                    );
                  },
                ),
                barGroups: List.generate(_predictions.length, (i) {
                  final load = _predictions[i].predictedLoad;
                  Color barColor;
                  if (load < TransformerConstants.safeLoadPct) {
                    barColor = Colors.green;
                  } else if (load <= TransformerConstants.heavyLoadPct) {
                    barColor = Colors.orange;
                  } else {
                    barColor = Colors.red;
                  }
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: load,
                        color: barColor,
                        width: 8,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageSuggestions() {
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
              const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'SMART USAGE SUGGESTIONS',
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
          _buildSuggestionItem(
            Icons.local_laundry_service,
            'Washing Machine',
            _getBestTimeRange(60),
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildSuggestionItem(
            Icons.iron,
            'Iron & Heater',
            _getBestTimeRange(50),
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildSuggestionItem(
            Icons.ev_station,
            'EV Charging',
            _getBestTimeRange(40),
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildSuggestionItem(
            Icons.air,
            'Air Conditioner',
            'Avoid 6 PM - 10 PM (Peak)',
            Colors.cyan,
          ),
        ],
      ),
    );
  }

  String _getBestTimeRange(double threshold) {
    final bestTimes = _predictions
        .where((p) => p.predictedLoad < threshold)
        .toList();
    if (bestTimes.isEmpty) {
      return 'Best during off-peak hours';
    }

    // Find consecutive ranges
    final hours = bestTimes.map((p) => p.hour).toList()..sort();
    if (hours.isEmpty) return 'Best during off-peak hours';

    final startHour = hours.first;
    final endHour = hours.last;

    final startPeriod = startHour < 12 ? 'AM' : 'PM';
    final endPeriod = endHour < 12 ? 'AM' : 'PM';
    final start = startHour % 12 == 0 ? 12 : startHour % 12;
    final end = endHour % 12 == 0 ? 12 : endHour % 12;

    return '$start$startPeriod - $end$endPeriod (Low load period)';
  }

  Widget _buildSuggestionItem(
    IconData icon,
    String appliance,
    String suggestion,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
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
                  appliance,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  suggestion,
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
