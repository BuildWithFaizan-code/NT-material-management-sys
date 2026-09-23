import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'api_client.dart';
import 'token_storage_service.dart';

class UserInfo {
  final int userId;
  final String username;
  final String email;
  final bool isAdmin;

  const UserInfo({
    required this.userId,
    required this.username,
    required this.email,
    required this.isAdmin,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['userId'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isAdmin: json['isAdmin'] as bool? ?? false,
    );
  }
}

class LoginResult {
  final bool success;
  final String message;
  final bool mustChangePassword;
  final bool requiresMfa;
  final String? mfaChallengeToken;

  const LoginResult({
    required this.success,
    required this.message,
    this.mustChangePassword = false,
    this.requiresMfa = false,
    this.mfaChallengeToken,
  });
}

/// Central authentication state management service for NT-MMS.
/// Follows existing Controller->Service architecture conventions with ApiResponse unwrapping.
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();

  AuthService._internal() {
    // Hook into ApiClient for automatic silent refresh and session expiration routing
    ApiClient.instance.refreshTokenHandler = silentRefresh;
    ApiClient.instance.onSessionExpired = _handleSessionExpired;
  }

  bool _isInitialized = false;
  bool _isLoggedIn = false;
  bool _mustChangePassword = false;
  UserInfo? _currentUser;

  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _isLoggedIn;
  bool get mustChangePassword => _mustChangePassword;
  UserInfo? get currentUser => _currentUser;

  final String _authBaseUrl = '${ApiConfig.baseUrl}/auth';

  /// Initializes session state at app startup.
  /// On Web: silently queries /api/auth/refresh-web to check for valid HttpOnly cookie.
  /// On Native: checks secure storage for stored access and refresh tokens.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kIsWeb) {
        // On web, access token is lost on page refresh; attempt silent re-acquisition via HttpOnly cookie
        final success = await silentRefresh();
        if (success) {
          _isLoggedIn = true;
        }
      } else {
        final token = await TokenStorageService.instance.getAccessToken();
        if (token != null && token.isNotEmpty) {
          _isLoggedIn = true;
        }
      }
    } catch (_) {
      _isLoggedIn = false;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Authenticates user with username & password.
  Future<LoginResult> login(String username, String password, {String? deviceInfo}) async {
    try {
      final response = await ApiClient.instance.post(
        '$_authBaseUrl/login',
        body: {
          'username': username.trim(),
          'password': password,
          'deviceInfo': deviceInfo ?? (kIsWeb ? 'Web Browser' : defaultTargetPlatform.name),
        },
      );

      final body = ApiClient.instance.decodeResponse(response);
      final success = body['success'] as bool? ?? false;
      final message = body['message'] as String? ?? '';
      final data = body['data'] as Map<String, dynamic>?;

      if (!success || data == null) {
        return LoginResult(success: false, message: message.isNotEmpty ? message : 'Invalid credentials.');
      }

      // Check if MFA is required
      final requiresMfa = data['requiresMfa'] as bool? ?? false;
      if (requiresMfa) {
        return LoginResult(
          success: true,
          message: message,
          requiresMfa: true,
          mfaChallengeToken: data['mfaChallengeToken'] as String?,
        );
      }

      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      final mustChange = data['mustChangePassword'] as bool? ?? false;

      if (accessToken != null) {
        await TokenStorageService.instance.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        if (data['user'] != null) {
          _currentUser = UserInfo.fromJson(data['user'] as Map<String, dynamic>);
        }

        _mustChangePassword = mustChange;
        _isLoggedIn = true;
        notifyListeners();

        return LoginResult(
          success: true,
          message: message,
          mustChangePassword: mustChange,
        );
      }

      return LoginResult(success: false, message: 'Missing token in authentication response.');
    } on ApiException catch (e) {
      return LoginResult(success: false, message: e.message);
    } catch (e) {
      return LoginResult(success: false, message: 'Authentication error: $e');
    }
  }

  /// Second-step verification for MFA challenge during login.
  Future<LoginResult> verifyMfaLogin(String challengeToken, String code, {String? deviceInfo}) async {
    try {
      final response = await ApiClient.instance.post(
        '$_authBaseUrl/mfa/login',
        body: {
          'challengeToken': challengeToken,
          'code': code.trim(),
          'deviceInfo': deviceInfo ?? (kIsWeb ? 'Web Browser' : defaultTargetPlatform.name),
        },
      );

      final body = ApiClient.instance.decodeResponse(response);
      final success = body['success'] as bool? ?? false;
      final message = body['message'] as String? ?? '';
      final data = body['data'] as Map<String, dynamic>?;

      if (!success || data == null) {
        return LoginResult(success: false, message: message.isNotEmpty ? message : 'Invalid MFA code.');
      }

      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      final mustChange = data['mustChangePassword'] as bool? ?? false;

      if (accessToken != null) {
        await TokenStorageService.instance.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        if (data['user'] != null) {
          _currentUser = UserInfo.fromJson(data['user'] as Map<String, dynamic>);
        }

        _mustChangePassword = mustChange;
        _isLoggedIn = true;
        notifyListeners();

        return LoginResult(
          success: true,
          message: message,
          mustChangePassword: mustChange,
        );
      }

      return LoginResult(success: false, message: 'Missing token in MFA response.');
    } on ApiException catch (e) {
      return LoginResult(success: false, message: e.message);
    } catch (e) {
      return LoginResult(success: false, message: 'MFA verification failed: $e');
    }
  }

  /// Performs transparent Refresh Token Rotation (RTR).
  /// - Web: Calls /api/auth/refresh-web with HttpOnly cookie.
  /// - Native: Calls /api/auth/refresh with body refresh token from secure storage.
  Future<bool> silentRefresh() async {
    try {
      if (kIsWeb) {
        final response = await ApiClient.instance.post('$_authBaseUrl/refresh-web');
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final data = body['data'] as Map<String, dynamic>?;
          final newAccessToken = data?['accessToken'] as String?;
          if (newAccessToken != null) {
            await TokenStorageService.instance.saveTokens(accessToken: newAccessToken);
            if (data?['user'] != null) {
              _currentUser = UserInfo.fromJson(data!['user'] as Map<String, dynamic>);
            }
            return true;
          }
        }
      } else {
        final currentRefreshToken = await TokenStorageService.instance.getRefreshToken();
        if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
          return false;
        }

        final response = await ApiClient.instance.post(
          '$_authBaseUrl/refresh',
          body: {'refreshToken': currentRefreshToken},
        );

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final data = body['data'] as Map<String, dynamic>?;
          final newAccessToken = data?['accessToken'] as String?;
          final newRefreshToken = data?['refreshToken'] as String?;

          if (newAccessToken != null) {
            await TokenStorageService.instance.saveTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
            );
            if (data?['user'] != null) {
              _currentUser = UserInfo.fromJson(data!['user'] as Map<String, dynamic>);
            }
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Logs out the user and clears all local and session tokens.
  Future<void> logout() async {
    try {
      final refreshToken = await TokenStorageService.instance.getRefreshToken();
      await ApiClient.instance.post(
        '$_authBaseUrl/logout',
        body: {'refreshToken': refreshToken},
      );
    } catch (_) {
      // Best effort logout on server
    } finally {
      await TokenStorageService.instance.clearTokens();
      _isLoggedIn = false;
      _currentUser = null;
      _mustChangePassword = false;
      notifyListeners();
    }
  }

  /// Changes the user's password.
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await ApiClient.instance.post(
        '$_authBaseUrl/change-password',
        body: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );

      final body = ApiClient.instance.decodeResponse(response);
      final success = body['success'] as bool? ?? false;
      if (success) {
        _mustChangePassword = false;
        notifyListeners();
      }
      return success;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to change password: $e');
    }
  }

  /// Requests MFA enrollment secret and QR code URI.
  Future<Map<String, String>> setupMfa() async {
    final response = await ApiClient.instance.post('$_authBaseUrl/mfa/setup');
    final body = ApiClient.instance.decodeResponse(response);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return {
      'secretKey': data['secretKey'] as String? ?? '',
      'otpAuthUri': data['otpAuthUri'] as String? ?? '',
    };
  }

  /// Confirms MFA activation with user-provided 6-digit code.
  Future<bool> verifyAndEnableMfa(String secretKey, String code) async {
    final response = await ApiClient.instance.post(
      '$_authBaseUrl/mfa/verify',
      body: {
        'secretKey': secretKey,
        'code': code.trim(),
      },
    );
    final body = ApiClient.instance.decodeResponse(response);
    return body['success'] as bool? ?? false;
  }

  void _handleSessionExpired() {
    TokenStorageService.instance.clearTokens();
    _isLoggedIn = false;
    _currentUser = null;
    notifyListeners();
  }
}
