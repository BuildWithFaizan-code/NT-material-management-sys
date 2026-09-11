import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../pages/location_master_page.dart';

class LocationService {
  final String baseUrl;
  final http.Client _client;
  static const _timeout = Duration(seconds: 8);

  LocationService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? 'http://localhost:5000/api/locationmaster',
        _client = client ?? http.Client();

  /// GET /api/locationmaster
  /// Fetches all Location Master records from LocationMst table
  Future<List<LocationMaster>> fetchLocations() async {
    final uri = Uri.parse(baseUrl);
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        return data
            .map((e) => LocationMaster.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to fetch location records (HTTP ${response.statusCode})');
    } on SocketException {
      throw Exception('Server connection failed. Verify backend API is running.');
    } on http.ClientException {
      throw Exception('Client HTTP exception connecting to backend API.');
    }
  }

  /// GET /api/locationmaster/next-code
  /// Fetches auto-incremented next Loc_Code from LocationMst table
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

  /// POST /api/locationmaster
  /// Inserts a new Location Master record into LocationMst table
  Future<bool> createLocation(int code, String name, String prefix, {String? series}) async {
    final uri = Uri.parse(baseUrl);
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'locCode': code,
              'locName': name,
              'locPrefix': prefix,
              'locSeries': series ?? '',
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Failed to create location record: $e');
    }
  }

  /// PUT /api/locationmaster/{code}
  /// Updates an existing Location Master record in LocationMst table
  Future<bool> updateLocation(int code, String name, String prefix, {String? series}) async {
    final uri = Uri.parse('$baseUrl/$code');
    try {
      final response = await _client
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'locCode': code,
              'locName': name,
              'locPrefix': prefix,
              'locSeries': series ?? '',
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to update location record: $e');
    }
  }

  /// DELETE /api/locationmaster/{code}
  /// Deletes a Location Master record by Loc_Code from LocationMst table
  Future<bool> deleteLocation(int code) async {
    final uri = Uri.parse('$baseUrl/$code');
    try {
      final response = await _client.delete(uri).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to delete location record: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
