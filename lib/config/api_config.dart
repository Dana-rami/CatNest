// lib/config/api_config.dart

/// Central place for the CatNest station's network address.
///
/// If the Raspberry Pi's IP changes (common on DHCP networks),
/// this is the ONLY place you need to update it.
///
/// TIP: give the Pi a static/reserved IP on your router so this
/// stops changing between demos.
class ApiConfig {
  ApiConfig._();

  // Change this to your Raspberry Pi's IP address
  static const String baseUrl = 'http://YOUR_PI_IP:5000';

  // Timeouts are centralized too, so both screens behave consistently.
  static const Duration statusTimeout = Duration(seconds: 5);
  static const Duration controlTimeout = Duration(seconds: 5);
}