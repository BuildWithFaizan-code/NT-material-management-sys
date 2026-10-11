import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _localUrl = 'http://localhost:5000/api';
  static const String _prodUrl = 'https://nt-material-management-sys-api.onrender.com/api';

  /// Compile-time environment override if provided via `--dart-define=API_BASE_URL=...`
  static const String _envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Base API URL for development. Connects directly to local backend at http://localhost:5000/api.
  static String get baseUrl {
    if (_envUrl.isNotEmpty) {
      return _envUrl;
    }
    return _localUrl;
  }

  /// Network timeout for local requests
  static const Duration defaultTimeout = Duration(seconds: 15);
}
