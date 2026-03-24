class SmartMeter {
  final String meterId;
  final String customerName;
  final double currentUsage; // kWh
  final double voltage; // Volts
  final double current; // Amperes
  final double powerFactor;
  final double frequency; // Hz
  final double todayUsage; // kWh
  final double monthlyUsage; // kWh
  final double estimatedBill; // Currency
  final double solarGeneration; // kWh
  final double gridConsumption; // kWh
  final double peakLoad; // kW
  final String tariffType;
  final double currentRate; // per kWh
  final bool isConnected;
  final DateTime lastUpdated;
  final List<HourlyUsage> hourlyData;

  SmartMeter({
    required this.meterId,
    required this.customerName,
    required this.currentUsage,
    required this.voltage,
    required this.current,
    required this.powerFactor,
    required this.frequency,
    required this.todayUsage,
    required this.monthlyUsage,
    required this.estimatedBill,
    required this.solarGeneration,
    required this.gridConsumption,
    required this.peakLoad,
    required this.tariffType,
    required this.currentRate,
    required this.isConnected,
    required this.lastUpdated,
    required this.hourlyData,
  });

  // Demo data factory
  factory SmartMeter.demo(String meterId) {
    return SmartMeter(
      meterId: meterId,
      customerName: 'Demo Customer',
      currentUsage: 2.45,
      voltage: 230.5,
      current: 10.65,
      powerFactor: 0.92,
      frequency: 50.02,
      todayUsage: 18.75,
      monthlyUsage: 485.32,
      estimatedBill: 2426.60,
      solarGeneration: 12.5,
      gridConsumption: 6.25,
      peakLoad: 4.8,
      tariffType: 'Time of Use',
      currentRate: 5.50,
      isConnected: true,
      lastUpdated: DateTime.now(),
      hourlyData: List.generate(24, (index) {
        return HourlyUsage(
          hour: index,
          usage: 0.5 + (index % 6) * 0.3 + (index > 17 && index < 22 ? 1.5 : 0),
        );
      }),
    );
  }

  factory SmartMeter.fromFirestore(Map<String, dynamic> data) {
    return SmartMeter(
      meterId: data['meterId'] ?? '',
      customerName: data['customerName'] ?? '',
      currentUsage: (data['currentUsage'] ?? 0).toDouble(),
      voltage: (data['voltage'] ?? 0).toDouble(),
      current: (data['current'] ?? 0).toDouble(),
      powerFactor: (data['powerFactor'] ?? 0).toDouble(),
      frequency: (data['frequency'] ?? 0).toDouble(),
      todayUsage: (data['todayUsage'] ?? 0).toDouble(),
      monthlyUsage: (data['monthlyUsage'] ?? 0).toDouble(),
      estimatedBill: (data['estimatedBill'] ?? 0).toDouble(),
      solarGeneration: (data['solarGeneration'] ?? 0).toDouble(),
      gridConsumption: (data['gridConsumption'] ?? 0).toDouble(),
      peakLoad: (data['peakLoad'] ?? 0).toDouble(),
      tariffType: data['tariffType'] ?? '',
      currentRate: (data['currentRate'] ?? 0).toDouble(),
      isConnected: data['isConnected'] ?? false,
      lastUpdated: DateTime.parse(
        data['lastUpdated'] ?? DateTime.now().toIso8601String(),
      ),
      hourlyData:
          (data['hourlyData'] as List<dynamic>?)
              ?.map((e) => HourlyUsage.fromMap(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'meterId': meterId,
      'customerName': customerName,
      'currentUsage': currentUsage,
      'voltage': voltage,
      'current': current,
      'powerFactor': powerFactor,
      'frequency': frequency,
      'todayUsage': todayUsage,
      'monthlyUsage': monthlyUsage,
      'estimatedBill': estimatedBill,
      'solarGeneration': solarGeneration,
      'gridConsumption': gridConsumption,
      'peakLoad': peakLoad,
      'tariffType': tariffType,
      'currentRate': currentRate,
      'isConnected': isConnected,
      'lastUpdated': lastUpdated.toIso8601String(),
      'hourlyData': hourlyData.map((e) => e.toMap()).toList(),
    };
  }
}

class HourlyUsage {
  final int hour;
  final double usage;

  HourlyUsage({required this.hour, required this.usage});

  factory HourlyUsage.fromMap(Map<String, dynamic> map) {
    return HourlyUsage(
      hour: map['hour'] ?? 0,
      usage: (map['usage'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'hour': hour, 'usage': usage};
  }
}
