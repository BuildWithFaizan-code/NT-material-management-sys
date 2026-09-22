import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _prodUrl = 'https://nt-material-management-sys-api.onrender.com/api';
  static const String _localUrl = 'http://localhost:5000/api';

  /// Automatically connects to local backend during development and Render in production.
  static String get baseUrl => kDebugMode ? _localUrl : _prodUrl;

  /// Resilient network timeout for web clients & Render cold-start latency
  static const Duration defaultTimeout = Duration(seconds: 15);
}
