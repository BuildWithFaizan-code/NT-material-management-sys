import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../pages/project_master_page.dart';

class ProjectService {
  final String baseUrl;
  final http.Client _client;
  static const _timeout = Duration(seconds: 8);

  ProjectService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? 'http://localhost:5000/api/projectmaster',
        _client = client ?? http.Client();

  /// GET /api/projectmaster
  /// Fetches all Project Master records from database
  Future<List<ProjectMaster>> fetchProjects() async {
    final uri = Uri.parse(baseUrl);
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        return data
            .map((e) => ProjectMaster.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to fetch projects (HTTP ${response.statusCode})');
    } on SocketException {
      throw Exception('Server connection failed. Verify backend API is running.');
    } on http.ClientException {
      throw Exception('Client HTTP exception connecting to backend API.');
    }
  }

  /// GET /api/projectmaster/next-code
  /// Fetches auto-incremented next PRJ_CODE from database
  Future<int> fetchNextCode() async {
    final uri = Uri.parse('$baseUrl/next-code');
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final nextCode = body['data'];
        if (nextCode is int) return nextCode;
        if (nextCode != null) return int.tryParse(nextCode.toString()) ?? 101;
      }
      return 101;
    } catch (_) {
      return 101; // fallback default
    }
  }

  /// POST /api/projectmaster
  /// Inserts a new Project Master record into PROJECTMST table
  Future<bool> createProject(int code, String name) async {
    final uri = Uri.parse(baseUrl);
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'prjCode': code,
              'prjName': name,
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Failed to create project: $e');
    }
  }

  /// PUT /api/projectmaster
  /// Updates an existing Project Master record in PROJECTMST table
  Future<bool> updateProject(int code, String name) async {
    final uri = Uri.parse(baseUrl);
    try {
      final response = await _client
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'prjCode': code,
              'prjName': name,
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to update project: $e');
    }
  }

  /// DELETE /api/projectmaster/{code}
  /// Deletes a Project Master record by PRJ_CODE from PROJECTMST table
  Future<bool> deleteProject(int code) async {
    final uri = Uri.parse('$baseUrl/$code');
    try {
      final response = await _client.delete(uri).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to delete project: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
