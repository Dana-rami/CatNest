// lib/models/security_status.dart

/// Typed representation of GET /api/security/status.
class SecurityStatus {
  final String? lastEvent; // "granted" | "denied" | null
  final double? lastEventSecondsAgo;
  final bool deniedRecent;

  const SecurityStatus({
    required this.lastEvent,
    required this.lastEventSecondsAgo,
    required this.deniedRecent,
  });

  factory SecurityStatus.unknown() => const SecurityStatus(
        lastEvent: null,
        lastEventSecondsAgo: null,
        deniedRecent: false,
      );

  factory SecurityStatus.fromJson(Map<String, dynamic> json) {
    return SecurityStatus(
      lastEvent: json['last_event']?.toString(),
      lastEventSecondsAgo: _toDouble(json['last_event_seconds_ago']),
      deniedRecent: json['denied_recent'] == true,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}