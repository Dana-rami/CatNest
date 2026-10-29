// lib/screens/controls_screen.dart
import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ControlsScreen extends StatefulWidget {
  const ControlsScreen({super.key});

  static const String routeName = '/controls';

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  static const Color _primary = Color(0xFF2E7D32);

  final ApiService _api = ApiService.instance;

  bool _sending = false;

  Future<void> _sendCommand(String command, String successMessage) async {
    if (_sending) return;

    setState(() {
      _sending = true;
    });

    final result = await _api.sendCommand(command);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success ? successMessage : result.message),
        backgroundColor: result.success ? _primary : Colors.red,
      ),
    );

    setState(() {
      _sending = false;
    });
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
          'Controls',
          style: textTheme.titleLarge?.copyWith(
            color: _primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use the buttons below to control the CatNest station.',
                style: textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              _ControlButton(
                icon: Icons.pets,
                title: 'Feed & Water One Cat',
                loading: _sending,
                onPressed: () {
                  _sendCommand(
                    'CAT1',
                    'Feed and water command sent for one cat.',
                  );
                },
              ),
              const SizedBox(height: 14),
              _ControlButton(
                icon: Icons.groups,
                title: 'Feed & Water Multiple Cats',
                loading: _sending,
                onPressed: () {
                  _sendCommand(
                    'CAT2',
                    'Feed and water command sent for multiple cats.',
                  );
                },
              ),
              const SizedBox(height: 14),
              _ControlButton(
                icon: Icons.directions_walk,
                title: 'Cat Left',
                loading: _sending,
                onPressed: () {
                  _sendCommand('LEFT', 'Left door command sent.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.title,
    required this.onPressed,
    required this.loading,
  });

  final IconData icon;
  final String title;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 24),
        label: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _ControlsScreenState._primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              _ControlsScreenState._primary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}