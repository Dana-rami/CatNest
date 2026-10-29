// lib/screens/dashboard_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ai_status.dart';
import '../models/sensor_status.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const String routeName = '/dashboard';

  static const Color _primary = Color(0xFF2E7D32);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _primary = DashboardScreen._primary;

  // Same thresholds used on the Alerts screen, kept in sync so a
  // card that's red here matches a red alert there.
  static const double _lowThreshold = 30.0;
  static const double _criticalThreshold = 15.0;
  static const double _minComfortableTemp = 5.0;
  static const double _maxComfortableTemp = 35.0;

  final ApiService _api = ApiService.instance;

  Timer? _timer;

  bool _loading = true;
  bool _refreshPulse = false;
  AiStatus _aiStatus = AiStatus.offline();
  SensorStatus _sensorStatus = SensorStatus.offline();
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();

    _loadAll();

    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadAll(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    // Fetch both endpoints in parallel - they're independent.
    final results = await Future.wait([
      _api.getAiStatus(),
      _api.getSensorStatus(),
    ]);

    if (!mounted) return;

    setState(() {
      _aiStatus = results[0] as AiStatus;
      _sensorStatus = results[1] as SensorStatus;
      _loading = false;
      _lastUpdated = DateTime.now();

      // Brief visual pulse each time a poll completes, so it's
      // obvious on screen that a refresh just happened (not just
      // a static screenshot).
      _refreshPulse = !_refreshPulse;
    });
  }

  // The station is considered online if either the Arduino or the
  // camera is reachable - either one alone means the Pi is up and
  // talking to at least part of the hardware.
  bool get _stationOnline =>
      _aiStatus.arduinoConnected || _aiStatus.cameraOnline;

  String get _lastUpdatedText {
    if (_lastUpdated == null) return 'Never updated';

    final seconds = DateTime.now().difference(_lastUpdated!).inSeconds;

    if (seconds < 2) return 'Updated just now';
    if (seconds < 60) return 'Updated ${seconds}s ago';

    final minutes = (seconds / 60).floor();
    return 'Updated ${minutes}m ago';
  }

  // ----------------------------------------------------------
  // Severity coloring - shared logic so a card's color always
  // matches what would show up as an Alert for the same reading.
  // ----------------------------------------------------------

  Color _levelColor(double? value) {
    if (value == null) return Colors.grey.shade400;
    if (value < 0) return Colors.orange;
    if (value < _criticalThreshold) return const Color(0xFFE53935);
    if (value < _lowThreshold) return Colors.orange;
    return _primary;
  }

  Color _tempColor(double? value) {
    if (value == null) return Colors.grey.shade400;
    if (value < _minComfortableTemp) return Colors.blue;
    if (value > _maxComfortableTemp) return const Color(0xFFE53935);
    return _primary;
  }

  String _formatPercent(double? value) {
    if (value == null) return '—';
    if (value < 0) return 'Error';
    return '${value.toStringAsFixed(0)}%';
  }

  String _formatTemp(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(1)}°C';
  }

  String _formatHumidity(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          color: _primary,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const horizontalPadding = 20.0;
              const verticalPadding = 24.0;

              final crossAxisCount = constraints.maxWidth >= 700 ? 3 : 2;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CatNest Dashboard',
                          style: textTheme.headlineSmall?.copyWith(
                            color: _primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_loading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --------------------------------------------
                    // Station status + live "last updated" pill.
                    // This is the visible proof the screen isn't
                    // static: the dot glows and the text ticks
                    // forward every poll (every 3s).
                    // --------------------------------------------
                    Row(
                      children: [
                        _StatusDot(online: _stationOnline),
                        const SizedBox(width: 8),
                        Text(
                          _stationOnline ? 'Online' : 'Offline',
                          style: textTheme.titleSmall?.copyWith(
                            color: _stationOnline ? _primary : Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('•', style: TextStyle(color: Colors.grey.shade400)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Row(
                              key: ValueKey(_refreshPulse),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sync,
                                  size: 13,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _lastUpdatedText,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (!_sensorStatus.sensorsOnline) ...[
                      const SizedBox(height: 10),
                      const _WarningBanner(
                        text: 'Sensor data is stale or unavailable. '
                            'Levels below may be out of date.',
                      ),
                    ],

                    const SizedBox(height: 24),

                    GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: [
                        _MetricCard(
                          title: 'Food Level',
                          value: _formatPercent(_sensorStatus.averageFoodLevel),
                          icon: Icons.restaurant,
                          color: _levelColor(_sensorStatus.averageFoodLevel),
                        ),
                        _MetricCard(
                          title: 'Water Level',
                          value: _formatPercent(_sensorStatus.averageWaterLevel),
                          icon: Icons.water_drop,
                          color: _levelColor(_sensorStatus.averageWaterLevel),
                        ),
                        _MetricCard(
                          title: 'Temperature',
                          value: _formatTemp(_sensorStatus.temperature),
                          icon: Icons.thermostat,
                          color: _tempColor(_sensorStatus.temperature),
                        ),
                        // Replaces the old fake "Battery" card - there's
                        // no battery/voltage sensor on the station, so a
                        // battery % would have been fabricated. Humidity
                        // comes from the same DHT22 already used for
                        // climate control, so it's real, live data.
                        _MetricCard(
                          title: 'Humidity',
                          value: _formatHumidity(_sensorStatus.humidity),
                          icon: Icons.water,
                          color: _primary,
                        ),
                        _MetricCard(
                          title: "Today's Feedings",
                          value: '${_sensorStatus.feedingsToday}',
                          icon: Icons.pets,
                          color: _primary,
                        ),
                        _LastDetectionCard(
                          lastDetection: _aiStatus.lastDetection,
                          color: _primary,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Live status dot - glows around itself so it visibly reads as
// "live" rather than a flat static icon.
// ============================================================

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? DashboardScreen._primary : Colors.red;

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Warning banner
// ============================================================

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Metric card - color now reflects severity (red/orange/green),
// not a fixed primary green for every reading. Value text uses
// FittedBox so it can never overflow the card, no matter how
// long the formatted string turns out to be.
// ============================================================

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Last Detection card - a dedicated layout (not the generic
// _MetricCard) because "YYYY-MM-DD HH:MM:SS" needs to be split
// across two lines with different sizes so it never overflows a
// fixed-height grid cell (this was the exact bug in the
// screenshot: "BOTTOM OVERFLOWED BY 7.0 PIXELS").
// ============================================================

class _LastDetectionCard extends StatelessWidget {
  const _LastDetectionCard({
    required this.lastDetection,
    required this.color,
  });

  final String? lastDetection;
  final Color color;

  /// Splits "2026-08-24 09:07:32" into ("2026-08-24", "09:07:32").
  /// Falls back gracefully if the format doesn't match.
  static (String, String?) _splitDateTime(String raw) {
    final parts = raw.trim().split(' ');

    if (parts.length >= 2) {
      return (parts[0], parts.sublist(1).join(' '));
    }

    return (raw, null);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final raw = lastDetection;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.camera_alt, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              'Last Detection',
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            if (raw == null)
              Text(
                'No detection yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Builder(
                builder: (context) {
                  final (datePart, timePart) = _splitDateTime(raw);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        datePart,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (timePart != null)
                        Text(
                          timePart,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: color.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}