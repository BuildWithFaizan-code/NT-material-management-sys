import 'dart:convert';
import '../config/api_config.dart';
import '../pages/location_master_page.dart';
import 'api_client.dart';

class LocationService {
  final String baseUrl;
  final ApiClient _client;

  LocationService({
    String? baseUrl,
    ApiClient? client,
  })  : baseUrl = baseUrl ?? '${ApiConfig.baseUrl}/locationmaster',
        _client = client ?? ApiClient.instance;

  /// GET /api/locationmaster
  /// Fetches all Location Master records from LocationMst table
  Future<List<LocationMaster>> fetchLocations() async {
    try {
      final response = await _client.get(baseUrl);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        return data
            .map((e) => LocationMaster.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to fetch location records (HTTP ${response.statusCode})');
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (_) {
      throw Exception('Server connection failed. Verify backend API is running.');
    }
  }

  /// GET /api/locationmaster/next-code
  /// Fetches auto-incremented next Loc_Code from LocationMst table
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

  /// POST /api/locationmaster
  /// Inserts a new Location Master record into LocationMst table
  Future<bool> createLocation(int code, String name, String prefix, {String? series}) async {
    try {
      final response = await _client.post(
        baseUrl,
        body: {
          'locCode': code,
          'locName': name,
          'locPrefix': prefix,
          'locSeries': series ?? '',
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Failed to create location record: $e');
    }
  }

  /// PUT /api/locationmaster/{code}
  /// Updates an existing Location Master record in LocationMst table
  Future<bool> updateLocation(int code, String name, String prefix, {String? series}) async {
    try {
      final response = await _client.put(
        '$baseUrl/$code',
        body: {
          'locCode': code,
          'locName': name,
          'locPrefix': prefix,
          'locSeries': series ?? '',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to update location record: $e');
    }
  }

  /// DELETE /api/locationmaster/{code}
  /// Deletes a Location Master record by Loc_Code from LocationMst table
  Future<bool> deleteLocation(int code) async {
    try {
      final response = await _client.delete('$baseUrl/$code');
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to delete location record: $e');
    }
  }

  void dispose() {
    // Shared ApiClient manages its own lifecycle
  }
}
