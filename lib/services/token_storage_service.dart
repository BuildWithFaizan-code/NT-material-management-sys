import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ITokenStorageService {
  Future<void> saveTokens({required String accessToken, String? refreshToken});
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> clearTokens();
}

/// Token storage implementation satisfying Phase 3 platform-specific security requirements:
/// - Native (Windows/macOS/iOS/Android): Uses flutter_secure_storage backed by DPAPI, Keychain, or Keystore.
/// - Web: Strictly in-memory access token only. Never stores refresh token or access token in localStorage/sessionStorage.
class TokenStorageService implements ITokenStorageService {
  static final TokenStorageService instance = TokenStorageService._internal();

  TokenStorageService._internal() {
    if (!kIsWeb) {
      _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
      );
    }
  }

  FlutterSecureStorage? _secureStorage;
  static const String _keyAccessToken = 'nt_mms_access_token';
  static const String _keyRefreshToken = 'nt_mms_refresh_token';

  // In-memory token storage (used on web and cached in memory across native)
  String? _inMemoryAccessToken;
  String? _inMemoryRefreshToken;

  @override
  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    _inMemoryAccessToken = accessToken;
    if (refreshToken != null) {
      _inMemoryRefreshToken = refreshToken;
    }

    if (!kIsWeb && _secureStorage != null) {
      await _secureStorage!.write(key: _keyAccessToken, value: accessToken);
      if (refreshToken != null) {
        await _secureStorage!.write(key: _keyRefreshToken, value: refreshToken);
      }
    }
  }

  @override
  Future<String?> getAccessToken() async {
    if (_inMemoryAccessToken != null) {
      return _inMemoryAccessToken;
    }

    if (!kIsWeb && _secureStorage != null) {
      _inMemoryAccessToken = await _secureStorage!.read(key: _keyAccessToken);
      return _inMemoryAccessToken;
    }

    return null;
  }

  @override
  Future<String?> getRefreshToken() async {
    if (kIsWeb) {
      // On Web, refresh tokens are strictly HttpOnly cookies handled by the browser
      return null;
    }

    if (_inMemoryRefreshToken != null) {
      return _inMemoryRefreshToken;
    }

    if (_secureStorage != null) {
      _inMemoryRefreshToken = await _secureStorage!.read(key: _keyRefreshToken);
      return _inMemoryRefreshToken;
    }

    return null;
  }

  @override
  Future<void> clearTokens() async {
    _inMemoryAccessToken = null;
    _inMemoryRefreshToken = null;

    if (!kIsWeb && _secureStorage != null) {
      await _secureStorage!.delete(key: _keyAccessToken);
      await _secureStorage!.delete(key: _keyRefreshToken);
    }
  }
}
