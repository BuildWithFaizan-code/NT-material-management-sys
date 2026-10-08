import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _prodUrl = 'https://nt-material-management-sys-api.onrender.com/api';
  static const String _localUrl = 'http://localhost:5000/api';

  /// Compile-time environment override if provided via `--dart-define=API_BASE_URL=...`
  static const String _envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Automatically connects to local backend during development and Render in production.
  /// Respects compile-time `--dart-define=API_BASE_URL` when provided.
  static String get baseUrl {
    if (_envUrl.isNotEmpty) {
      return _envUrl;
    }
    return kDebugMode ? _localUrl : _prodUrl;
  }

  /// Resilient network timeout for web clients & Render cold-start latency
  static const Duration defaultTimeout = Duration(seconds: 45);
}
