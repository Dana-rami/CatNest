// lib/models/sensor_status.dart

/// Typed representation of GET /api/sensors/status.
///
/// Any level field can be `null` if the Arduino hasn't sent a
/// STATUS line yet, and negative (-1) if that specific sensor
/// failed to read on the Arduino side. `hasError` on each getter
/// below distinguishes "no data yet" from "sensor is broken".
class SensorStatus {
  final bool sensorsOnline;
  final double? water1;
  final double? water2;
  final double? food1;
  final double? food2;
  final double? temperature;
  final double? humidity;
  final int feedingsToday;
  // NEW: true = currently raining (umbrella deployed), false =
  // dry, null = no data received yet.
  final bool? raining;

  const SensorStatus({
    required this.sensorsOnline,
    required this.water1,
    required this.water2,
    required this.food1,
    required this.food2,
    required this.temperature,
    required this.humidity,
    required this.feedingsToday,
    required this.raining,
  });

  factory SensorStatus.offline() => const SensorStatus(
        sensorsOnline: false,
        water1: null,
        water2: null,
        food1: null,
        food2: null,
        temperature: null,
        humidity: null,
        feedingsToday: 0,
        raining: null,
      );

  factory SensorStatus.fromJson(Map<String, dynamic> json) {
    return SensorStatus(
      sensorsOnline: json['sensors_online'] == true,
      water1: _toDouble(json['water1']),
      water2: _toDouble(json['water2']),
      food1: _toDouble(json['food1']),
      food2: _toDouble(json['food2']),
      temperature: _toDouble(json['temp']),
      humidity: _toDouble(json['humidity']),
      feedingsToday: _toInt(json['feedings_today']),
      raining: json['raining'] as bool?,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  /// Average of the two water tanks, ignoring any tank that's
  /// currently erroring (-1) or missing.
  double? get averageWaterLevel => _average([water1, water2]);

  /// Average of the two food tanks, same error-ignoring rule.
  double? get averageFoodLevel => _average([food1, food2]);

  static double? _average(List<double?> values) {
    final valid = values.where((v) => v != null && v >= 0).toList();

    if (valid.isEmpty) return null;

    return valid.fold<double>(0, (sum, v) => sum + v!) / valid.length;
  }
}