import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../pages/project_master_page.dart';
import 'api_client.dart';

class ProjectService {
  final String baseUrl;
  final ApiClient _client;

  ProjectService({
    String? baseUrl,
    ApiClient? client,
  })  : baseUrl = baseUrl ?? '${ApiConfig.baseUrl}/projectmaster',
        _client = client ?? ApiClient.instance;

  /// GET /api/projectmaster
  /// Fetches all Project Master records from database
  Future<List<ProjectMaster>> fetchProjects() async {
    try {
      final response = await _client.get(baseUrl);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        return data
            .map((e) => ProjectMaster.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to fetch projects (HTTP ${response.statusCode})');
    } on http.ClientException {
      throw Exception('Client HTTP exception connecting to backend API.');
    } catch (_) {
      throw Exception('Server connection failed. Verify backend API is running.');
    }
  }

  /// GET /api/projectmaster/next-code
  /// Fetches auto-incremented next PRJ_CODE from database
  Future<int> fetchNextCode() async {
    try {
      final response = await _client.get('$baseUrl/next-code');
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
    try {
      final response = await _client.post(
        baseUrl,
        body: {
          'prjCode': code,
          'prjName': name,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Failed to create project: $e');
    }
  }

  /// PUT /api/projectmaster
  /// Updates an existing Project Master record in PROJECTMST table
  Future<bool> updateProject(int code, String name) async {
    try {
      final response = await _client.put(
        baseUrl,
        body: {
          'prjCode': code,
          'prjName': name,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to update project: $e');
    }
  }

  /// DELETE /api/projectmaster/{code}
  /// Deletes a Project Master record by PRJ_CODE from PROJECTMST table
  Future<bool> deleteProject(int code) async {
    try {
      final response = await _client.delete('$baseUrl/$code');
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to delete project: $e');
    }
  }

  void dispose() {}
}
