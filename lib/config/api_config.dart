class ApiConfig {
  static const String localUrl = 'http://localhost:5000/api';
  static const String prodUrl = 'https://nt-material-management-sys-api.onrender.com/api';

  /// Compile-time environment override if provided via `--dart-define=API_BASE_URL=...`
  static const String _envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Base API URL. Defaults to local development URL (http://localhost:5000/api) per user instruction.
  /// Overridden only when explicit --dart-define=API_BASE_URL=... is provided.
  static String get baseUrl {
    if (_envUrl.isNotEmpty) {
      return _envUrl;
    }
    return localUrl;
  }

  /// Network timeout for requests
  static const Duration defaultTimeout = Duration(seconds: 15);
}
