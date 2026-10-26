import 'dart:convert';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import 'indent_models.dart';

class IndentService {
  final String baseUrl;
  final ApiClient _client;

  IndentService({
    String? baseUrl,
    ApiClient? client,
  })  : baseUrl = baseUrl ?? '${ApiConfig.baseUrl}/indent',
        _client = client ?? ApiClient.instance;

  Future<IndentPagedResult<IndentHeader>> fetchIndents({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    int page = 1,
    int pageSize = 25,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (fromDate != null) {
      queryParams['fromDate'] = fromDate.toIso8601String();
    }
    if (toDate != null) {
      queryParams['toDate'] = toDate.toIso8601String();
    }

    final response = await _client.get(baseUrl, queryParams: queryParams);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        final itemsRaw = (data['items'] as List?) ?? [];
        final items = itemsRaw.map((e) => IndentHeader.fromJson(e as Map<String, dynamic>)).toList();
        return IndentPagedResult<IndentHeader>(
          items: items,
          totalCount: (data['totalCount'] ?? items.length) as int,
          page: (data['page'] ?? page) as int,
          pageSize: (data['pageSize'] ?? pageSize) as int,
        );
      }
    }
    throw ApiException(
      'Failed to fetch indents (status: ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<IndentLookups> fetchLookups() async {
    final url = '$baseUrl/lookups';
    final response = await _client.get(url);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        return IndentLookups.fromJson(data);
      }
    }
    throw ApiException(
      'Failed to fetch indent lookups (status: ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<List<IndentCostCenterLookup>> fetchCostCenters(int storeCode) async {
    final url = '$baseUrl/cost-centers';
    final response = await _client.get(url, queryParams: {'storeCode': storeCode.toString()});
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is List) {
        return data.map((e) => IndentCostCenterLookup.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  Future<IndentPagedResult<IndentItemLookup>> searchItems({
    String? search,
    int page = 1,
    int pageSize = 25,
  }) async {
    final url = '$baseUrl/items';
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final response = await _client.get(url, queryParams: queryParams);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        final itemsRaw = (data['items'] as List?) ?? [];
        final items = itemsRaw.map((e) => IndentItemLookup.fromJson(e as Map<String, dynamic>)).toList();
        return IndentPagedResult<IndentItemLookup>(
          items: items,
          totalCount: (data['totalCount'] ?? items.length) as int,
          page: (data['page'] ?? page) as int,
          pageSize: (data['pageSize'] ?? pageSize) as int,
        );
      }
    }
    throw ApiException(
      'Failed to search items (status: ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<List<String>> fetchRemarkSuggestions(String query) async {
    final url = '$baseUrl/remarks';
    final response = await _client.get(url, queryParams: {'query': query.trim()});
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is List) {
        return data.map((e) => e.toString()).toList();
      }
    }
    return [];
  }

  Future<bool> checkDateLock(DateTime date) async {
    final url = '$baseUrl/check-lock';
    final response = await _client.get(url, queryParams: {'date': date.toIso8601String()});
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is bool) return data;
    }
    return false;
  }

  Future<IndentHeader?> fetchIndentByCode(String code) async {
    final url = '$baseUrl/by-code';
    final response = await _client.get(url, queryParams: {'code': code.trim()});
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        return IndentHeader.fromJson(data);
      }
    }
    return null;
  }

  Future<String> saveIndent(IndentSavePayload payload) async {
    final response = await _client.post(
      baseUrl,
      body: jsonEncode(payload.toJson()),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      return data?.toString() ?? 'Saved successfully';
    }

    String message = 'Failed to save indent (status: ${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }
    } catch (_) {}

    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<String> updateIndent(String indCode, IndentSavePayload payload) async {
    final encodedCode = Uri.encodeComponent(indCode.trim());
    final url = '$baseUrl/$encodedCode';
    final response = await _client.put(
      url,
      body: jsonEncode(payload.toJson()),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      return data?.toString() ?? indCode;
    }

    String message = 'Failed to update indent (status: ${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }
    } catch (_) {}

    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<bool> deleteIndent(String indCode) async {
    final encodedCode = Uri.encodeComponent(indCode.trim());
    final url = '$baseUrl/$encodedCode';
    final response = await _client.delete(url);

    if (response.statusCode == 200) {
      return true;
    }

    String message = 'Failed to delete indent (status: ${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }
    } catch (_) {}

    throw ApiException(message, statusCode: response.statusCode);
  }
}
