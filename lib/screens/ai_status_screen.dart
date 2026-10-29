// lib/screens/ai_status_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import '../models/ai_status.dart';
import '../services/api_service.dart';

class AiStatusScreen extends StatefulWidget {
  const AiStatusScreen({super.key});

  static const String routeName = '/ai-status';

  @override
  State<AiStatusScreen> createState() => _AiStatusScreenState();
}

class _AiStatusScreenState extends State<AiStatusScreen> {
  static const Color _primary = Color(0xFF2E7D32);

  final ApiService _api = ApiService.instance;

  Timer? _timer;

  bool _loading = true;
  AiStatus _status = AiStatus.offline();

  // The MJPEG widget keeps its own connection open, so it needs
  // to be recreated only when the camera flips online<->offline
  // (not on every 1s status poll). This key forces a fresh
  // connection attempt whenever that happens.
  Key _streamKey = UniqueKey();

  @override
  void initState() {
    super.initState();

    _loadStatus();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _loadStatus(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final status = await _api.getAiStatus();

    if (!mounted) return;

    final cameraJustCameBackOnline =
        status.cameraOnline && !_status.cameraOnline;

    setState(() {
      _status = status;
      _loading = false;

      if (cameraJustCameBackOnline) {
        // Force the Mjpeg widget to reconnect rather than sitting
        // on a dead connection from before the camera dropped.
        _streamKey = UniqueKey();
      }
    });
  }

  Future<void> _manualRefresh() async {
    setState(() {
      _loading = true;
      _streamKey = UniqueKey();
    });

    await _loadStatus();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI status refreshed.'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String get _detectionText {
    if (!_status.detected || _status.catCount == 0) {
      return 'No Cat Detected';
    }

    if (_status.catCount == 1) {
      return '1 Cat Detected 🐱';
    }

    return '${_status.catCount} Cats Detected 🐱';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        title: Text(
          'AI Status',
          style: textTheme.titleLarge?.copyWith(
            color: _primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _manualRefresh,
          color: _primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =========================
                // CAMERA STATUS CARD
                // =========================
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Camera Status',
                          style: textTheme.titleMedium?.copyWith(
                            color: _primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _status.cameraOnline
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _status.cameraOnline ? 'Online' : 'Offline',
                              style: textTheme.bodyLarge?.copyWith(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 28, color: Colors.grey.shade300),
                        _InfoRow(
                          label: 'Model',
                          value: _status.model,
                          textTheme: textTheme,
                        ),
                        Divider(height: 28, color: Colors.grey.shade300),
                        _InfoRow(
                          label: 'Cats in Frame',
                          value: '${_status.catCount}',
                          textTheme: textTheme,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // =========================
                // LIVE CAMERA
                // =========================
                Text(
                  'Live Camera',
                  style: textTheme.titleMedium?.copyWith(
                    color: _primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 220,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: _status.cameraOnline
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Mjpeg(
                              key: _streamKey,
                              isLive: true,
                              stream: _api.streamUrl,
                              fit: BoxFit.cover,
                              error: (context, error, stackTrace) {
                                return const _NoImageWidget(
                                  message: 'Camera image unavailable',
                                );
                              },
                              loading: (context) => const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Cats in frame: ${_status.catCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const _NoImageWidget(message: 'Camera Offline'),
                ),

                const SizedBox(height: 28),

                // =========================
                // LATEST DETECTION
                // =========================
                Text(
                  'Latest Detection',
                  style: textTheme.titleMedium?.copyWith(
                    color: _primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _DetailCard(title: 'Detection Result', value: _detectionText),
                const SizedBox(height: 12),
                _DetailCard(
                  title: 'Confidence',
                  value: _status.detected
                      ? '${_status.confidence.toStringAsFixed(1)}%'
                      : '0%',
                ),
                const SizedBox(height: 12),
                _DetailCard(
                  title: 'Detected Object',
                  value: _status.detected && _status.label != null
                      ? _status.label!.toUpperCase()
                      : 'None',
                ),
                const SizedBox(height: 12),
                _DetailCard(
                  title: 'Detection Time',
                  value: _status.lastDetection ?? 'No detection yet',
                ),

                const SizedBox(height: 28),

                // =========================
                // REFRESH BUTTON
                // =========================
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _manualRefresh,
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
                      _loading ? 'Refreshing...' : 'Refresh Status',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _primary.withValues(alpha: 0.5),
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

// =====================================================
// INFO ROW
// =====================================================

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.textTheme,
  });

  final String label;
  final String value;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: textTheme.bodyLarge?.copyWith(
            color: Colors.grey.shade900,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// =====================================================
// DETAIL CARD
// =====================================================

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: textTheme.titleMedium?.copyWith(
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// NO IMAGE
// =====================================================

class _NoImageWidget extends StatelessWidget {
  const _NoImageWidget({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 46,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}