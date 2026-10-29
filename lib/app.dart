import 'package:flutter/material.dart';

import 'screens/ai_status_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/controls_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

class CatNestApp extends StatelessWidget {
  const CatNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CatNest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
      routes: {
        LoginScreen.routeName: (_) => const LoginScreen(),
        DashboardScreen.routeName: (_) => const MainShell(),
        AiStatusScreen.routeName: (_) => const AiStatusScreen(),
        ControlsScreen.routeName: (_) => const ControlsScreen(),
        AlertsScreen.routeName: (_) => const AlertsScreen(),
      },
    );
  }
}
