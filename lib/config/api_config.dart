import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _prodUrl = 'https://nt-material-management-sys-api.onrender.com/api';
  static const String _localUrl = 'http://localhost:5000/api';

  /// Deployment toggle: set to true to force connection to Render deployment API
  static const bool useProduction = true;

  /// Automatically connects to Render in production or when useProduction is true.
  static String get baseUrl => useProduction ? _prodUrl : (kDebugMode ? _localUrl : _prodUrl);

  /// Resilient network timeout for web clients & Render cold-start latency (30 seconds)
  static const Duration defaultTimeout = Duration(seconds: 30);
}
