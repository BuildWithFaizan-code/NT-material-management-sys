import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../pages/store_master_page.dart';
import 'api_client.dart';

class StoreService {
  final String baseUrl;
  final ApiClient _client;

  StoreService({
    String? baseUrl,
    ApiClient? client,
  })  : baseUrl = baseUrl ?? '${ApiConfig.baseUrl}/storemaster',
        _client = client ?? ApiClient.instance;

  /// GET /api/storemaster
  /// Fetches all Store Master records joined with Location descriptions from STOREMST table
  Future<List<StoreMaster>> fetchStores() async {
    try {
      final response = await _client.get(baseUrl);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        return data
            .map((e) => StoreMaster.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to fetch store records (HTTP ${response.statusCode})');
    } on http.ClientException {
      throw Exception('Client HTTP exception connecting to backend API.');
    } catch (_) {
      throw Exception('Server connection failed. Verify backend API is running.');
    }
  }

  /// GET /api/storemaster/locations
  /// Fetches location lookup items for form dropdown selection
  Future<List<LocationLookupDto>> fetchLocationsLookup() async {
    try {
      final response = await _client.get('$baseUrl/locations');
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
    try {
      final response = await _client.get('$baseUrl/next-code');
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
    try {
      final response = await _client.post(
        baseUrl,
        body: {
          'strCode': code,
          'strName': name,
          'locCode': locCode,
          'strSeries': series ?? '',
          'strFixChar': fixChar ?? '',
        },
      );

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
    } catch (e) {
      rethrow;
    }
  }

  /// PUT /api/storemaster/{code}
  /// Updates an existing Store Master record in STOREMST table
  Future<bool> updateStore(int code, String name, int locCode, {String? series, String? fixChar}) async {
    try {
      final response = await _client.put(
        '$baseUrl/$code',
        body: {
          'strCode': code,
          'strName': name,
          'locCode': locCode,
          'strSeries': series ?? '',
          'strFixChar': fixChar ?? '',
        },
      );

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
    } catch (e) {
      rethrow;
    }
  }

  /// DELETE /api/storemaster/{code}
  /// Deletes a store record by STR_CODE
  Future<bool> deleteStore(int code) async {
    try {
      final response = await _client.delete('$baseUrl/$code');
      if (response.statusCode == 200) return true;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = body['message'] as String? ?? 'HTTP ${response.statusCode}';
        throw Exception(msg);
      } catch (_) {
        throw Exception('Failed to delete store record (HTTP ${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }
}
