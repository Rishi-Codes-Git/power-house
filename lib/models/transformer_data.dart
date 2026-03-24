import 'dart:math' as math;

// Constants matching the Streamlit app
class TransformerConstants {
  static const double ratedKVA = 150.0;
  static const double ratedCurrentA = 209.0;
  static const double safeCurrentA = 170.0;
  static const double heavyCurrentA = 198.0;
  static const double safeLoadPct = 80.0;
  static const double heavyLoadPct = 95.0;
  static const double overloadLoadPct = 100.0;
  static const double pfMin = 0.75;
  static const double pfMax = 0.95;
  static const double pfDefault = 0.90;
  static const double lvLLNominalV = 415.0;
  static const double lvLLMinV = 373.0;
  static const double lvLLMaxV = 456.0;
  static const double tempNormalMinC = 50.0;
  static const double tempNormalMaxC = 75.0;
  static const double tempWarningC = 85.0;
  static const double tempCriticalC = 100.0;
  static const double tempInsulationC = 120.0;
}

enum LoadState { safe, heavy, nearRated, overload }

enum TemperatureState { normal, elevated, warning, critical, insulationLimit }

enum HealthStatus { healthy, stressed, warning, critical, emergency }

enum TransformerStatus { normal, tripped, lockout }

class TransformerData {
  final double voltage;
  final double current;
  final double power;
  final double temperature;
  final double loadPercent;
  final double powerFactor;
  final DateTime timestamp;
  final bool isLive;

  TransformerData({
    required this.voltage,
    required this.current,
    required this.power,
    required this.temperature,
    required this.loadPercent,
    this.powerFactor = TransformerConstants.pfDefault,
    DateTime? timestamp,
    this.isLive = false,
  }) : timestamp = timestamp ?? DateTime.now();

  // Calculate apparent power in kVA
  double get apparentPowerKVA => (voltage * current) / 1000.0;

  // Calculate current from power and voltage
  static double deriveCurrentFromPower(double voltageV, double powerKW) {
    if (voltageV <= 0 || powerKW <= 0) return 0.0;
    return (powerKW * 1000.0) / voltageV;
  }

  // Convert load percentage to kVA
  static double loadPctToKVA(double loadPct) {
    return (loadPct / 100.0) * TransformerConstants.ratedKVA;
  }

  // Convert kVA to load percentage
  static double kvaToLoadPct(double kva) {
    return (kva / TransformerConstants.ratedKVA) * 100.0;
  }

  // Convert load percentage to current
  static double loadPctToCurrentA(
    double loadPct, [
    double voltageLLV = TransformerConstants.lvLLNominalV,
  ]) {
    final kva = loadPctToKVA(loadPct);
    return (kva * 1000.0) / (math.sqrt(3) * voltageLLV);
  }

  // Estimate core temperature based on load and ambient
  static double estimateCoreTemperature(double loadPct, double ambientTempC) {
    final loadPU = (loadPct / 100.0).clamp(0.0, 1.35);
    final riseC = 22.0 + 40.0 * math.pow(loadPU, 1.7);
    final overloadRiseC = math.max(loadPct - 100.0, 0.0) * 0.35;
    final coreTemp = ambientTempC + riseC + overloadRiseC;
    return coreTemp.clamp(30.0, 125.0);
  }

  // Classify load state
  LoadState get loadState {
    if (loadPercent < TransformerConstants.safeLoadPct &&
        current < TransformerConstants.safeCurrentA) {
      return LoadState.safe;
    }
    if (loadPercent <= TransformerConstants.heavyLoadPct &&
        current <= TransformerConstants.heavyCurrentA) {
      return LoadState.heavy;
    }
    if (loadPercent <= TransformerConstants.overloadLoadPct &&
        current <= TransformerConstants.ratedCurrentA) {
      return LoadState.nearRated;
    }
    return LoadState.overload;
  }

  // Classify temperature state
  TemperatureState get temperatureState {
    if (temperature <= TransformerConstants.tempNormalMaxC) {
      return TemperatureState.normal;
    }
    if (temperature <= TransformerConstants.tempWarningC) {
      return TemperatureState.elevated;
    }
    if (temperature <= TransformerConstants.tempCriticalC) {
      return TemperatureState.warning;
    }
    if (temperature <= TransformerConstants.tempInsulationC) {
      return TemperatureState.critical;
    }
    return TemperatureState.insulationLimit;
  }

  // Calculate overall health
  TransformerHealth get health {
    final loadSeverity = loadState.index;
    final tempSeverity = temperatureState.index;
    final voltageNormal =
        voltage >= TransformerConstants.lvLLMinV &&
        voltage <= TransformerConstants.lvLLMaxV;
    final voltageSeverity = voltageNormal ? 0 : 3;

    final overallSeverity = [
      loadSeverity,
      tempSeverity,
      voltageSeverity,
    ].reduce(math.max);

    final status = HealthStatus.values[overallSeverity.clamp(0, 4)];
    final healthScores = {0: 96.0, 1: 82.0, 2: 66.0, 3: 44.0, 4: 18.0};

    final overloadIndex = math.max(
      loadPercent / TransformerConstants.overloadLoadPct,
      current / TransformerConstants.ratedCurrentA,
    );
    final overloadRiskPct = (((overloadIndex - 0.80) / 0.20) * 100.0).clamp(
      0.0,
      100.0,
    );

    return TransformerHealth(
      status: status,
      healthScore: healthScores[overallSeverity] ?? 50.0,
      overloadRiskPercent: overloadRiskPct,
      loadState: loadState,
      temperatureState: temperatureState,
      voltageNormal: voltageNormal,
    );
  }

  // Calculate dynamic price
  double get dynamicPrice {
    const baseTariff = 4.50;
    final loadMultiplier = math.max(
      1.0,
      loadPercent / TransformerConstants.safeLoadPct,
    );
    final currentMultiplier = math.max(
      1.0,
      math.pow(current / TransformerConstants.safeCurrentA, 2),
    );
    final tempMultiplier = math.max(
      1.0,
      temperature / TransformerConstants.tempNormalMaxC,
    );

    var effectiveMultiplier = [
      loadMultiplier,
      currentMultiplier,
      tempMultiplier,
    ].reduce(math.max);

    if (loadPercent > TransformerConstants.overloadLoadPct ||
        current > TransformerConstants.ratedCurrentA ||
        temperature > TransformerConstants.tempCriticalC) {
      effectiveMultiplier = math.max(
        effectiveMultiplier,
        math.max(
          loadPercent / TransformerConstants.overloadLoadPct,
          math.max(
            current / TransformerConstants.ratedCurrentA,
            temperature / TransformerConstants.tempCriticalC,
          ),
        ),
      );
    }

    return baseTariff * effectiveMultiplier;
  }

  // Get tariff tier
  String get tariffTier {
    if (loadPercent < TransformerConstants.safeLoadPct &&
        current < TransformerConstants.safeCurrentA &&
        temperature <= TransformerConstants.tempNormalMaxC) {
      return 'Base Tariff';
    }
    if (loadPercent <= TransformerConstants.heavyLoadPct &&
        current <= TransformerConstants.heavyCurrentA &&
        temperature <= TransformerConstants.tempWarningC) {
      return 'Congested Tariff';
    }
    if (loadPercent <= TransformerConstants.overloadLoadPct &&
        current <= TransformerConstants.ratedCurrentA &&
        temperature <= TransformerConstants.tempCriticalC) {
      return 'Peak-Stress Tariff';
    }
    if (temperature <= TransformerConstants.tempInsulationC) {
      return 'Critical Tariff';
    }
    return 'Emergency Tariff';
  }
}

class TransformerHealth {
  final HealthStatus status;
  final double healthScore;
  final double overloadRiskPercent;
  final LoadState loadState;
  final TemperatureState temperatureState;
  final bool voltageNormal;

  TransformerHealth({
    required this.status,
    required this.healthScore,
    required this.overloadRiskPercent,
    required this.loadState,
    required this.temperatureState,
    required this.voltageNormal,
  });

  String get statusText {
    switch (status) {
      case HealthStatus.healthy:
        return 'Healthy';
      case HealthStatus.stressed:
        return 'Stressed';
      case HealthStatus.warning:
        return 'Warning';
      case HealthStatus.critical:
        return 'Critical';
      case HealthStatus.emergency:
        return 'Emergency';
    }
  }

  String get loadStateText {
    switch (loadState) {
      case LoadState.safe:
        return 'Safe';
      case LoadState.heavy:
        return 'Heavy';
      case LoadState.nearRated:
        return 'Near Rated';
      case LoadState.overload:
        return 'Overload';
    }
  }

  String get temperatureStateText {
    switch (temperatureState) {
      case TemperatureState.normal:
        return 'Normal';
      case TemperatureState.elevated:
        return 'Elevated';
      case TemperatureState.warning:
        return 'Warning';
      case TemperatureState.critical:
        return 'Critical';
      case TemperatureState.insulationLimit:
        return 'Insulation Limit';
    }
  }
}

class HourlyPrediction {
  final int hour;
  final double predictedLoad;
  final double predictedPrice;
  final String suggestion;
  final bool isHighRisk;

  HourlyPrediction({
    required this.hour,
    required this.predictedLoad,
    required this.predictedPrice,
    required this.suggestion,
    required this.isHighRisk,
  });

  String get hourLabel {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final ampm = hour < 12 ? 'AM' : 'PM';
    return '$h:00 $ampm';
  }
}
