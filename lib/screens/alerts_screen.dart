// lib/screens/alerts_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ai_status.dart';
import '../models/security_status.dart';
import '../models/sensor_status.dart';
import '../services/api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  static const String routeName = '/alerts';

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const Color _primary = Color(0xFF2E7D32);

  // Below this %, we warn that a tank is getting low.
  static const double _lowThreshold = 30.0;

  // Below this %, we treat it as urgent (needs refilling now).
  static const double _criticalThreshold = 15.0;

  // NEW: temperature comfort range for the cats. Outside this,
  // we flag a weather-related alert.
  static const double _minComfortableTemp = 5.0;
  static const double _maxComfortableTemp = 35.0;

  final ApiService _api = ApiService.instance;

  Timer? _timer;

  bool _loading = true;
  bool _connected = false;

  AiStatus _aiStatus = AiStatus.offline();
  SensorStatus _sensorStatus = SensorStatus.offline();
  SecurityStatus _securityStatus = SecurityStatus.unknown();

  @override
  void initState() {
    super.initState();

    _loadAlerts();

    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadAlerts(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    final results = await Future.wait([
      _api.getAiStatus(),
      _api.getSensorStatus(),
      _api.getSecurityStatus(),
    ]);

    if (!mounted) return;

    final aiStatus = results[0] as AiStatus;
    final sensorStatus = results[1] as SensorStatus;
    final securityStatus = results[2] as SecurityStatus;

    setState(() {
      // We consider ourselves "connected" if any endpoint gave
      // us real data - camera and sensors can fail independently.
      _connected = aiStatus.cameraOnline ||
          aiStatus.arduinoConnected ||
          sensorStatus.sensorsOnline;

      _aiStatus = aiStatus;
      _sensorStatus = sensorStatus;
      _securityStatus = securityStatus;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });

    await _loadAlerts();
  }

  List<_AlertItem> _buildAlerts() {
    final List<_AlertItem> alerts = [];

    // --------------------------------------------------
    // Raspberry Pi / API connection
    // --------------------------------------------------

    if (!_connected) {
      alerts.add(
        const _AlertItem(
          icon: Icons.cloud_off,
          color: Color(0xFFE53935),
          title: 'Station Offline',
          subtitle: 'Could not connect to the CatNest Raspberry Pi.',
        ),
      );

      return alerts;
    }

    // --------------------------------------------------
    // Camera
    // --------------------------------------------------

    if (!_aiStatus.cameraOnline) {
      alerts.add(
        const _AlertItem(
          icon: Icons.videocam_off,
          color: Color(0xFFE53935),
          title: 'Camera Offline',
          subtitle: 'Camera connection lost.',
        ),
      );
    }

    // --------------------------------------------------
    // Arduino
    // --------------------------------------------------

    if (!_aiStatus.arduinoConnected) {
      alerts.add(
        const _AlertItem(
          icon: Icons.memory,
          color: Color(0xFFE53935),
          title: 'Arduino Offline',
          subtitle: 'Arduino is not connected to the Raspberry Pi.',
        ),
      );
    }

    // --------------------------------------------------
    // Cat detection
    // --------------------------------------------------

    if (_aiStatus.detected) {
      if (_aiStatus.catCount > 1) {
        alerts.add(
          _AlertItem(
            icon: Icons.groups,
            color: _primary,
            title: 'Multiple Cats Detected',
            subtitle: '${_aiStatus.catCount} cats detected. '
                'Confidence: ${_aiStatus.confidence.toStringAsFixed(1)}%.',
          ),
        );
      } else {
        alerts.add(
          _AlertItem(
            icon: Icons.pets,
            color: _primary,
            title: 'Cat Detected',
            subtitle: 'A cat was detected successfully. '
                'Confidence: ${_aiStatus.confidence.toStringAsFixed(1)}%.',
          ),
        );
      }
    }

    // --------------------------------------------------
    // NEW: unauthorized RFID access attempt
    // --------------------------------------------------

    if (_securityStatus.deniedRecent) {
      final seconds = _securityStatus.lastEventSecondsAgo ?? 0;

      alerts.add(
        _AlertItem(
          icon: Icons.lock_person,
          color: const Color(0xFFE53935),
          title: 'Unauthorized Access Attempt',
          subtitle: 'An unrecognized RFID card was scanned '
              '${seconds.toStringAsFixed(0)}s ago. Access was denied.',
        ),
      );
    }

    // --------------------------------------------------
    // NEW: non-cat animal detected near the feeder
    // --------------------------------------------------

    if (_aiStatus.otherAnimalDetected) {
      final label = _aiStatus.otherAnimalLabel ?? 'animal';

      alerts.add(
        _AlertItem(
          icon: Icons.visibility,
          color: Colors.orange,
          title: 'Non-Cat Animal Detected',
          subtitle:
              'A $label was spotted near the feeder. Food access '
              'stays restricted to cats.',
        ),
      );
    }

    // --------------------------------------------------
    // NEW: feeding session running unusually long
    // --------------------------------------------------

    if (_aiStatus.feedingSessionLong) {
      final minutes = (_aiStatus.feedingDurationSeconds / 60).floor();

      alerts.add(
        _AlertItem(
          icon: Icons.hourglass_bottom,
          color: Colors.orange,
          title: 'Feeding Session Running Long',
          subtitle:
              'A feeding session has been open for about $minutes '
              'minute(s). Worth checking the camera feed.',
        ),
      );
    }

    // --------------------------------------------------
    // NEW: extreme temperature
    // --------------------------------------------------

    final temp = _sensorStatus.temperature;

    if (temp != null) {
      if (temp < _minComfortableTemp) {
        alerts.add(
          _AlertItem(
            icon: Icons.severe_cold,
            color: Colors.blue,
            title: 'Temperature Too Cold',
            subtitle: 'Station temperature is ${temp.toStringAsFixed(1)}°C. '
                'Heater should be active - worth checking on the cats.',
          ),
        );
      } else if (temp > _maxComfortableTemp) {
        alerts.add(
          _AlertItem(
            icon: Icons.local_fire_department,
            color: const Color(0xFFE53935),
            title: 'Temperature Too Hot',
            subtitle: 'Station temperature is ${temp.toStringAsFixed(1)}°C. '
                'Make sure the area stays ventilated and shaded.',
          ),
        );
      }
    }

    // --------------------------------------------------
    // Sensor data freshness
    // --------------------------------------------------

    if (!_sensorStatus.sensorsOnline) {
      alerts.add(
        const _AlertItem(
          icon: Icons.sensors_off,
          color: Colors.orange,
          title: 'Sensor Data Unavailable',
          subtitle: 'No recent readings from the station sensors. '
              'Food/water levels below may be out of date.',
        ),
      );
    }

    // --------------------------------------------------
    // Water & food levels (low / critical / sensor error)
    // --------------------------------------------------

    alerts.addAll(
      _levelAlerts(
        label: 'Water Tank 1',
        value: _sensorStatus.water1,
        fillAction: 'Fill Water Tank 1',
      ),
    );

    alerts.addAll(
      _levelAlerts(
        label: 'Water Tank 2',
        value: _sensorStatus.water2,
        fillAction: 'Fill Water Tank 2',
      ),
    );

    alerts.addAll(
      _levelAlerts(
        label: 'Food Tank 1',
        value: _sensorStatus.food1,
        fillAction: 'Refill Food Tank 1',
      ),
    );

    alerts.addAll(
      _levelAlerts(
        label: 'Food Tank 2',
        value: _sensorStatus.food2,
        fillAction: 'Refill Food Tank 2',
      ),
    );

    // --------------------------------------------------
    // NEW: rain detected (informational - the umbrella already
    // deploys automatically, this just lets you know it's active)
    // --------------------------------------------------

    if (_sensorStatus.raining == true) {
      alerts.add(
        const _AlertItem(
          icon: Icons.beach_access,
          color: Colors.blue,
          title: 'Rain Detected',
          subtitle: 'Rain sensor triggered - the umbrella has been '
              'deployed automatically to shield the station.',
        ),
      );
    }

    return alerts;
  }

  /// Builds 0 or 1 alert for a single tank reading:
  ///  - null        -> no alert (no data yet, already covered by
  ///                   the "Sensor Data Unavailable" banner)
  ///  - value < 0    -> sensor error alert
  ///  - < critical   -> urgent "fill now" alert (red)
  ///  - < low        -> "running low" alert (orange)
  ///  - otherwise    -> no alert, level is fine
  List<_AlertItem> _levelAlerts({
    required String label,
    required double? value,
    required String fillAction,
  }) {
    if (value == null) return const [];

    if (value < 0) {
      return [
        _AlertItem(
          icon: Icons.sensors_off,
          color: Colors.orange,
          title: '$label Sensor Error',
          subtitle:
              'Could not read the $label level sensor. Check the wiring.',
        ),
      ];
    }

    if (value < _criticalThreshold) {
      return [
        _AlertItem(
          icon: Icons.error_outline,
          color: const Color(0xFFE53935),
          title: fillAction,
          subtitle: '$label is critically low '
              '(${value.toStringAsFixed(0)}%). Refill as soon as possible.',
        ),
      ];
    }

    if (value < _lowThreshold) {
      return [
        _AlertItem(
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
          title: '$label Running Low',
          subtitle: '$label is at ${value.toStringAsFixed(0)}%. '
              'Consider refilling soon.',
        ),
      ];
    }

    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final alerts = _buildAlerts();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        title: Text(
          'Alerts',
          style: textTheme.titleLarge?.copyWith(
            color: _primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: _primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --------------------------------------------------
                // Connection status
                // --------------------------------------------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _connected
                        ? _primary.withValues(alpha: 0.08)
                        : Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _connected
                          ? _primary.withValues(alpha: 0.18)
                          : Colors.red.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _connected ? Icons.cloud_done : Icons.cloud_off,
                        color: _connected ? _primary : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _connected
                              ? 'Connected to CatNest station'
                              : 'CatNest station unavailable',
                          style: textTheme.bodyMedium?.copyWith(
                            color: _connected ? _primary : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Live notifications from the CatNest station.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                // --------------------------------------------------
                // Loading
                // --------------------------------------------------
                if (_loading && alerts.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(),
                    ),
                  )

                // --------------------------------------------------
                // No alerts
                // --------------------------------------------------
                else if (alerts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 30,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 50,
                          color: _primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Active Alerts',
                          style: textTheme.titleMedium?.copyWith(
                            color: _primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Everything looks good.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  )

                // --------------------------------------------------
                // Alerts
                // --------------------------------------------------
                else
                  ...alerts.map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AlertCard(alert: alert),
                    ),
                  ),

                const SizedBox(height: 16),

                // --------------------------------------------------
                // Refresh button
                // --------------------------------------------------
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _refresh,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      _loading ? 'Refreshing...' : 'Refresh Alerts',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _primary.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Alert Model
// ============================================================

class _AlertItem {
  const _AlertItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

// ============================================================
// Alert Card
// ============================================================

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final _AlertItem alert;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: alert.color.withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: alert.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                alert.icon,
                color: alert.color,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.subtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                      height: 1.35,
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
}
