// lib/services/api_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/ai_status.dart';
import '../models/security_status.dart';
import '../models/sensor_status.dart';

/// Result of sending a manual control command to the station.
class ControlResult {
  final bool success;
  final String message;

  const ControlResult({
    required this.success,
    required this.message,
  });
}

/// Single place for every HTTP call to the CatNest Raspberry Pi
/// backend. Both AiStatusScreen and ControlsScreen (and any
/// future screen) should go through this instead of calling
/// `http` directly, so:
///  - the base URL only lives in one place (ApiConfig)
///  - error handling / timeouts are consistent
///  - screens stay focused on UI, not networking details
class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  /// GET /api/ai/status
  /// Returns AiStatus.offline() on any failure so callers never
  /// have to null-check - they just check `.cameraOnline`.
  Future<AiStatus> getAiStatus() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/api/ai/status'))
          .timeout(ApiConfig.statusTimeout);

      if (response.statusCode != 200) {
        return AiStatus.offline();
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      return AiStatus.fromJson(data);
    } catch (_) {
      return AiStatus.offline();
    }
  }

  /// GET /api/sensors/status
  /// Returns SensorStatus.offline() on any failure, same pattern
  /// as getAiStatus() - callers never have to null-check the
  /// whole object, just individual level fields.
  Future<SensorStatus> getSensorStatus() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/api/sensors/status'))
          .timeout(ApiConfig.statusTimeout);

      if (response.statusCode != 200) {
        return SensorStatus.offline();
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      return SensorStatus.fromJson(data);
    } catch (_) {
      return SensorStatus.offline();
    }
  }

  /// GET /api/security/status
  Future<SecurityStatus> getSecurityStatus() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/api/security/status'))
          .timeout(ApiConfig.statusTimeout);

      if (response.statusCode != 200) {
        return SecurityStatus.unknown();
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      return SecurityStatus.fromJson(data);
    } catch (_) {
      return SecurityStatus.unknown();
    }
  }

  /// Builds a cache-busted URL for the live camera frame.
  /// Pass a fresh value (e.g. DateTime.now().millisecondsSinceEpoch)
  /// each time you want to force a reload.
  String frameUrl({required int cacheBuster}) {
    return '${ApiConfig.baseUrl}/api/ai/frame?t=$cacheBuster';
  }

  /// URL for the continuous MJPEG stream. Used with the `mjpeg_stream`
  /// widget instead of polling single frames every second - the Pi
  /// pushes frames continuously over one open connection, so the
  /// video looks smooth instead of "flashing" on every reload.
  String get streamUrl => '${ApiConfig.baseUrl}/api/ai/stream';

  /// POST /api/control  { "command": "..." }
  Future<ControlResult> sendCommand(String command) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/control'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'command': command}),
          )
          .timeout(ApiConfig.controlTimeout);

      Map<String, dynamic> data = {};

      try {
        data = jsonDecode(response.body);
      } catch (_) {
        // Non-JSON body; fall through with an empty map.
      }

      if (response.statusCode == 200 && data['success'] == true) {
        return const ControlResult(
          success: true,
          message: 'Command sent.',
        );
      }

      return ControlResult(
        success: false,
        message: data['message']?.toString() ?? 'Command failed.',
      );
    } catch (_) {
      return const ControlResult(
        success: false,
        message: 'Could not connect to CatNest station.',
      );
    }
  }
}