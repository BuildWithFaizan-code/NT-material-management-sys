import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String localUrl = 'http://localhost:5000/api';
  static const String prodUrl = 'https://nt-material-management-sys-api.onrender.com/api';

  /// Compile-time environment override if provided via `--dart-define=API_BASE_URL=...`
  static const String _envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Base API URL. In production/release builds, connects to Render API; in dev, connects to localhost.
  /// Overridden when explicit --dart-define=API_BASE_URL=... is provided.
  static String get baseUrl {
    if (_envUrl.isNotEmpty) {
      return _envUrl;
    }
    return kReleaseMode ? prodUrl : localUrl;
  }

  /// Network timeout for requests
  static const Duration defaultTimeout = Duration(seconds: 30);
}
