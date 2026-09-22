import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'http_client_factory.dart';
import 'token_storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// Single shared HTTP client wrapper for the NT-MMS application.
/// Satisfies Phase 2 & Phase 3 requirements:
/// - Automatically injects `Authorization: Bearer <token>`
/// - Adds "X-Client-Platform" header ("web" vs native)
/// - Intercepts 401 responses, performs transparent silent refresh, and retries request
/// - Dispatches session expiration on failure to route user cleanly to login
class ApiClient {
  static final ApiClient instance = ApiClient._internal();

  ApiClient._internal() : _client = getPlatformHttpClient();

  final http.Client _client;
  static const Duration _timeout = ApiConfig.defaultTimeout;

  // Callback registered by AuthService or App to trigger redirection on expired session
  VoidCallback? onSessionExpired;

  // Function reference for silent refresh provided by AuthService to prevent circular DI
  Future<bool> Function()? refreshTokenHandler;

  bool _isRefreshing = false;

  Map<String, String> _buildHeaders(Map<String, String>? customHeaders, String? token) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client-Platform': kIsWeb ? 'web' : 'native',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  /// Sends a GET request
  Future<http.Response> get(String url, {Map<String, String>? headers, Map<String, String>? queryParams}) async {
    var uri = Uri.parse(url);
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    return _sendWithRetry(() async {
      final token = await TokenStorageService.instance.getAccessToken();
      return _client.get(uri, headers: _buildHeaders(headers, token)).timeout(_timeout);
    });
  }

  /// Sends a POST request
  Future<http.Response> post(String url, {Map<String, String>? headers, Object? body}) async {
    final uri = Uri.parse(url);
    return _sendWithRetry(() async {
      final token = await TokenStorageService.instance.getAccessToken();
      return _client
          .post(
            uri,
            headers: _buildHeaders(headers, token),
            body: body is String ? body : (body != null ? jsonEncode(body) : null),
          )
          .timeout(_timeout);
    });
  }

  /// Sends a PUT request
  Future<http.Response> put(String url, {Map<String, String>? headers, Object? body}) async {
    final uri = Uri.parse(url);
    return _sendWithRetry(() async {
      final token = await TokenStorageService.instance.getAccessToken();
      return _client
          .put(
            uri,
            headers: _buildHeaders(headers, token),
            body: body is String ? body : (body != null ? jsonEncode(body) : null),
          )
          .timeout(_timeout);
    });
  }

  /// Sends a PATCH request
  Future<http.Response> patch(String url, {Map<String, String>? headers, Object? body}) async {
    final uri = Uri.parse(url);
    return _sendWithRetry(() async {
      final token = await TokenStorageService.instance.getAccessToken();
      return _client
          .patch(
            uri,
            headers: _buildHeaders(headers, token),
            body: body is String ? body : (body != null ? jsonEncode(body) : null),
          )
          .timeout(_timeout);
    });
  }

  /// Sends a DELETE request
  Future<http.Response> delete(String url, {Map<String, String>? headers, Object? body}) async {
    final uri = Uri.parse(url);
    return _sendWithRetry(() async {
      final token = await TokenStorageService.instance.getAccessToken();
      return _client
          .delete(
            uri,
            headers: _buildHeaders(headers, token),
            body: body is String ? body : (body != null ? jsonEncode(body) : null),
          )
          .timeout(_timeout);
    });
  }

  /// Handles 401 interception, silent refresh token rotation, and single retry
  Future<http.Response> _sendWithRetry(Future<http.Response> Function() requestFn) async {
    try {
      var response = await requestFn();

      if (response.statusCode == 401) {
        // Avoid recursive refreshing
        if (_isRefreshing) {
          _notifySessionExpired();
          return response;
        }

        if (refreshTokenHandler != null) {
          _isRefreshing = true;
          bool refreshed = false;
          try {
            refreshed = await refreshTokenHandler!();
          } catch (_) {
            refreshed = false;
          } finally {
            _isRefreshing = false;
          }

          if (refreshed) {
            // Retry the original request with new access token
            response = await requestFn();
            if (response.statusCode == 401) {
              _notifySessionExpired();
            }
            return response;
          }
        }

        // Refresh failed or unavailable
        _notifySessionExpired();
      }

      return response;
    } on http.ClientException catch (e) {
      throw ApiException('Network connection failed: ${e.message}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error occurred: $e');
    }
  }

  void _notifySessionExpired() {
    onSessionExpired?.call();
  }

  /// Helper to decode JSON response safely and throw ApiException on error
  Map<String, dynamic> decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (response.statusCode >= 400) {
          final msg = decoded['message'] as String? ?? 'Request failed with status ${response.statusCode}';
          throw ApiException(msg, statusCode: response.statusCode, data: decoded['data']);
        }
        return decoded;
      }
      return {'data': decoded};
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Invalid server response format (${response.statusCode})', statusCode: response.statusCode);
    }
  }

  void dispose() {
    _client.close();
  }
}
