import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../pages/store_master_page.dart';

class StoreService {
  final String baseUrl;
  final http.Client _client;
  static const _timeout = Duration(seconds: 8);

  StoreService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? '${ApiConfig.baseUrl}/storemaster',
        _client = client ?? http.Client();

  /// GET /api/storemaster
  /// Fetches all Store Master records joined with Location descriptions from STOREMST table
  Future<List<StoreMaster>> fetchStores() async {
    final uri = Uri.parse(baseUrl);
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        return data
            .map((e) => StoreMaster.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to fetch store records (HTTP ${response.statusCode})');
    } on SocketException {
      throw Exception('Server connection failed. Verify backend API is running.');
    } on http.ClientException {
      throw Exception('Client HTTP exception connecting to backend API.');
    }
  }

  /// GET /api/storemaster/locations
  /// Fetches location lookup items for form dropdown selection
  Future<List<LocationLookupDto>> fetchLocationsLookup() async {
    final uri = Uri.parse('$baseUrl/locations');
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        return data
            .map((e) => LocationLookupDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/storemaster/next-code
  /// Fetches auto-incremented next STR_CODE from STOREMST table
  Future<int> fetchNextCode() async {
    final uri = Uri.parse('$baseUrl/next-code');
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final nextCode = body['data'];
        if (nextCode is int) return nextCode;
        if (nextCode != null) return int.tryParse(nextCode.toString()) ?? 1;
      }
      return 1;
    } catch (_) {
      return 1;
    }
  }

  /// POST /api/storemaster
  /// Inserts a new Store Master record into STOREMST table
  Future<bool> createStore(int code, String name, int locCode, {String? series, String? fixChar}) async {
    final uri = Uri.parse(baseUrl);
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'strCode': code,
              'strName': name,
              'locCode': locCode,
              'strSeries': series ?? '',
              'strFixChar': fixChar ?? '',
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = body['message'] as String? ?? 'HTTP ${response.statusCode}';
        throw Exception(msg);
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) rethrow;
        throw Exception('Failed to create store record (HTTP ${response.statusCode})');
      }
    } on SocketException {
      throw Exception('Server connection failed. Verify backend API is running.');
    } catch (e) {
      rethrow;
    }
  }

  /// PUT /api/storemaster/{code}
  /// Updates an existing Store Master record in STOREMST table
  Future<bool> updateStore(int code, String name, int locCode, {String? series, String? fixChar}) async {
    final uri = Uri.parse('$baseUrl/$code');
    try {
      final response = await _client
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'strCode': code,
              'strName': name,
              'locCode': locCode,
              'strSeries': series ?? '',
              'strFixChar': fixChar ?? '',
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return true;
      }

      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = body['message'] as String? ?? 'HTTP ${response.statusCode}';
        throw Exception(msg);
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) rethrow;
        throw Exception('Failed to update store record (HTTP ${response.statusCode})');
      }
    } on SocketException {
      throw Exception('Server connection failed. Verify backend API is running.');
    } catch (e) {
      rethrow;
    }
  }

  /// DELETE /api/storemaster/{code}
  /// Deletes a store record by STR_CODE
  Future<bool> deleteStore(int code) async {
    final uri = Uri.parse('$baseUrl/$code');
    try {
      final response = await _client.delete(uri).timeout(_timeout);
      if (response.statusCode == 200) return true;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = body['message'] as String? ?? 'HTTP ${response.statusCode}';
        throw Exception(msg);
      } catch (_) {
        throw Exception('Failed to delete store record (HTTP ${response.statusCode})');
      }
    } on SocketException {
      throw Exception('Server connection failed. Verify backend API is running.');
    } catch (e) {
      rethrow;
    }
  }
}
