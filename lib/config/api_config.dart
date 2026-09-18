class ApiConfig {
  static const String baseUrl = 'https://nt-material-management-sys-api.onrender.com/api';

  /// Resilient network timeout for web clients & Render cold-start latency
  static const Duration defaultTimeout = Duration(seconds: 15);
}
