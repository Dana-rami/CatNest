// lib/models/ai_status.dart

/// Typed representation of the JSON returned by
/// GET /api/ai/status
///
/// Keeping this as a model (instead of passing raw Maps around
/// like the original screen did) means:
///  - one place to fix parsing if the backend JSON shape changes
///  - no risk of typos in string keys scattered across screens
///  - the UI code gets compile-time safety (e.g. catCount is
///    guaranteed to be an int, not "maybe int, maybe String")
class AiStatus {
  final bool cameraOnline;
  final bool arduinoConnected;
  final String model;
  final bool detected;
  final String? label;
  final double confidence;
  final int catCount;
  final String? lastDetection;

  // NEW: a non-cat animal from our watch-list (dog, bird, etc.)
  final bool otherAnimalDetected;
  final String? otherAnimalLabel;

  // NEW: current feeding session info.
  final bool feedingInProgress;
  final double feedingDurationSeconds;
  final bool feedingSessionLong;

  const AiStatus({
    required this.cameraOnline,
    required this.arduinoConnected,
    required this.model,
    required this.detected,
    required this.label,
    required this.confidence,
    required this.catCount,
    required this.lastDetection,
    required this.otherAnimalDetected,
    required this.otherAnimalLabel,
    required this.feedingInProgress,
    required this.feedingDurationSeconds,
    required this.feedingSessionLong,
  });

  /// A safe "everything offline" default, used when the Pi is
  /// unreachable so the UI always has something to render.
  factory AiStatus.offline() => const AiStatus(
        cameraOnline: false,
        arduinoConnected: false,
        model: 'YOLOv8',
        detected: false,
        label: null,
        confidence: 0.0,
        catCount: 0,
        lastDetection: null,
        otherAnimalDetected: false,
        otherAnimalLabel: null,
        feedingInProgress: false,
        feedingDurationSeconds: 0.0,
        feedingSessionLong: false,
      );

  factory AiStatus.fromJson(Map<String, dynamic> json) {
    return AiStatus(
      cameraOnline: json['camera_online'] == true,
      arduinoConnected: json['arduino_connected'] == true,
      model: json['model']?.toString() ?? 'YOLOv8',
      detected: json['detected'] == true,
      label: json['label']?.toString(),
      // Handles the value arriving as int, double, or numeric String.
      confidence: _toDouble(json['confidence']),
      catCount: _toInt(json['cat_count']),
      lastDetection: json['last_detection']?.toString(),
      otherAnimalDetected: json['other_animal_detected'] == true,
      otherAnimalLabel: json['other_animal_label']?.toString(),
      feedingInProgress: json['feeding_in_progress'] == true,
      feedingDurationSeconds: _toDouble(json['feeding_duration_seconds']),
      feedingSessionLong: json['feeding_session_long'] == true,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}