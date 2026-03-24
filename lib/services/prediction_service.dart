import 'dart:math' as math;
import '../models/transformer_data.dart';

class PredictionService {
  // Generate hourly predictions based on current load and time patterns
  // In a real app, this would call your LSTM model API
  static List<HourlyPrediction> generate24HourPredictions(double currentLoad) {
    final now = DateTime.now();
    final predictions = <HourlyPrediction>[];

    for (int i = 0; i < 24; i++) {
      final hour = (now.hour + i + 1) % 24;
      final predictedLoad = _predictLoadForHour(currentLoad, hour, i);
      final predictedPrice = _calculatePriceForLoad(predictedLoad);
      final suggestion = _getSuggestionForHour(hour, predictedLoad);
      final isHighRisk = predictedLoad > 100;

      predictions.add(
        HourlyPrediction(
          hour: hour,
          predictedLoad: predictedLoad,
          predictedPrice: predictedPrice,
          suggestion: suggestion,
          isHighRisk: isHighRisk,
        ),
      );
    }

    return predictions;
  }

  // Simulate LSTM-like prediction based on time patterns
  static double _predictLoadForHour(
    double currentLoad,
    int hour,
    int hoursAhead,
  ) {
    // Base load pattern (typical daily load curve)
    // Morning peak: 7-9 AM
    // Evening peak: 6-10 PM
    // Low: 1-5 AM

    double basePattern;
    if (hour >= 1 && hour <= 5) {
      // Night low
      basePattern = 45.0 + math.Random().nextDouble() * 10;
    } else if (hour >= 7 && hour <= 9) {
      // Morning peak
      basePattern = 75.0 + math.Random().nextDouble() * 15;
    } else if (hour >= 18 && hour <= 22) {
      // Evening peak - highest
      basePattern = 85.0 + math.Random().nextDouble() * 20;
    } else if (hour >= 12 && hour <= 14) {
      // Afternoon moderate
      basePattern = 65.0 + math.Random().nextDouble() * 10;
    } else {
      // Other hours - moderate
      basePattern = 55.0 + math.Random().nextDouble() * 15;
    }

    // Blend with current load for near-term predictions
    final blendFactor = math.max(0.0, 1.0 - (hoursAhead / 6.0));
    final blendedLoad =
        (basePattern * (1 - blendFactor)) + (currentLoad * blendFactor);

    // Add some randomness
    final noise = (math.Random().nextDouble() - 0.5) * 5;

    return (blendedLoad + noise).clamp(20.0, 120.0);
  }

  static double _calculatePriceForLoad(double load) {
    const baseTariff = 4.50;

    if (load < TransformerConstants.safeLoadPct) {
      return baseTariff;
    } else if (load <= TransformerConstants.heavyLoadPct) {
      return baseTariff * 1.5;
    } else if (load <= TransformerConstants.overloadLoadPct) {
      return baseTariff * 2.2;
    } else {
      return baseTariff * 3.0;
    }
  }

  static String _getSuggestionForHour(int hour, double load) {
    // Time-based suggestions
    if (hour >= 22 || hour <= 6) {
      return 'Best time for heavy appliances (washing, charging)';
    }

    if (load > 100) {
      return 'Avoid heavy appliances - Critical load expected';
    }

    if (load > 95) {
      return 'Reduce non-essential consumption';
    }

    if (load > 80) {
      return 'Consider shifting heavy loads to off-peak hours';
    }

    // Peak hours
    if (hour >= 18 && hour <= 21) {
      return 'Peak pricing - Minimize consumption if possible';
    }

    if (hour >= 7 && hour <= 9) {
      return 'Morning peak - Stagger heavy appliance usage';
    }

    return 'Normal operation - Standard usage OK';
  }

  // Get immediate next hour prediction
  static HourlyPrediction getNextHourPrediction(double currentLoad) {
    final predictions = generate24HourPredictions(currentLoad);
    return predictions.first;
  }

  // Get peak hours in next 24 hours
  static List<HourlyPrediction> getPeakHours(double currentLoad) {
    final predictions = generate24HourPredictions(currentLoad);
    final sorted = List<HourlyPrediction>.from(predictions)
      ..sort((a, b) => b.predictedLoad.compareTo(a.predictedLoad));
    return sorted.take(5).toList();
  }

  // Get best times for heavy appliances
  static List<HourlyPrediction> getBestTimes(double currentLoad) {
    final predictions = generate24HourPredictions(currentLoad);
    final sorted = List<HourlyPrediction>.from(predictions)
      ..sort((a, b) => a.predictedLoad.compareTo(b.predictedLoad));
    return sorted.take(5).toList();
  }

  // Get predictive warning for next hour
  static PredictiveWarning getWarning(double forecastLoad) {
    if (forecastLoad >= 120.0) {
      return PredictiveWarning(
        title: 'CRITICAL OVERLOAD PREDICTED',
        subtitle: 'Immediate Action Required',
        action: 'Shed non-essential load now and prepare feeder isolation.',
        severity: WarningSeverity.critical,
      );
    }

    if (forecastLoad >= 110.0) {
      return PredictiveWarning(
        title: 'Overload Expected',
        subtitle: 'Next Hour Warning',
        action: 'Shift heavy appliance usage and stagger discretionary demand.',
        severity: WarningSeverity.overload,
      );
    }

    if (forecastLoad >= 100.0) {
      return PredictiveWarning(
        title: 'High Usage Expected',
        subtitle: 'Approaching Limits',
        action:
            'Reduce non-critical consumption and avoid simultaneous high-load equipment.',
        severity: WarningSeverity.high,
      );
    }

    return PredictiveWarning(
      title: 'Forecast Stable',
      subtitle: 'Normal Operation',
      action:
          'Maintain current demand pattern. No immediate corrective action required.',
      severity: WarningSeverity.stable,
    );
  }
}

enum WarningSeverity { stable, high, overload, critical }

class PredictiveWarning {
  final String title;
  final String subtitle;
  final String action;
  final WarningSeverity severity;

  PredictiveWarning({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.severity,
  });
}
