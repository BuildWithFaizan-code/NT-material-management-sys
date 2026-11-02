import 'dart:convert';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import '../stock_transfer/stock_transfer_models.dart' show StockCatalogPagedResult;
import 'issue_manager_models.dart';

class IssueManagerService {
  String get baseUrl => '${ApiConfig.baseUrl}/issuemanager';

  Future<IssueManagerLookups> fetchLookups() async {
    final resp = await ApiClient.instance.get('$baseUrl/lookups');

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return IssueManagerLookups.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to load lookups.');
    }
    throw Exception('Failed to load Issue Manager lookups (HTTP ${resp.statusCode}).');
  }

  Future<String> fetchPreviewCode({
    required DateTime date,
    required String issueMode,
    required String fromDeptName,
  }) async {
    final resp = await ApiClient.instance.get(
      '$baseUrl/preview-code',
      queryParams: {
        'date': date.toIso8601String().substring(0, 10),
        'issueMode': issueMode,
        'fromDeptName': fromDeptName,
      },
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return jsonMap['data'].toString();
      }
    } else if (resp.statusCode == 400) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(jsonMap['message']?.toString() ?? 'Invalid code parameters.');
    }
    return '';
  }

  Future<StockCatalogPagedResult> fetchStockCatalog({
    required DateTime date,
    required int sourceDept,
    required int sourceStore,
    required int sourceDiv,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = <String, String>{
      'date': date.toIso8601String().substring(0, 10),
      'sourceDept': sourceDept.toString(),
      'sourceStore': sourceStore.toString(),
      'sourceDiv': sourceDiv.toString(),
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final resp = await ApiClient.instance.get(
      '$baseUrl/stock-catalog',
      queryParams: queryParams,
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return StockCatalogPagedResult.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to search stock catalog.');
    }
    throw Exception('Failed to load stock catalog (HTTP ${resp.statusCode}).');
  }

  Future<double> checkStock({
    required DateTime date,
    String? currentDocNo,
    required String itemCode,
    String? mrgNo,
    String? grade,
    String? shade,
    required int sourceDept,
    required int sourceStore,
    required int sourceDiv,
    required int uom,
  }) async {
    final resp = await ApiClient.instance.get(
      '$baseUrl/check-stock',
      queryParams: {
        'date': date.toIso8601String().substring(0, 10),
        'currentDocNo': currentDocNo ?? '',
        'itemCode': itemCode,
        'mrgNo': mrgNo ?? '',
        'grade': grade ?? '',
        'shade': shade ?? '',
        'sourceDept': sourceDept.toString(),
        'sourceStore': sourceStore.toString(),
        'sourceDiv': sourceDiv.toString(),
        'uom': uom.toString(),
      },
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return (jsonMap['data'] as num).toDouble();
      }
    }
    return 0.0;
  }

  Future<bool> isDateLocked(DateTime date) async {
    final resp = await ApiClient.instance.get(
      '$baseUrl/is-date-locked',
      queryParams: {'date': date.toIso8601String().substring(0, 10)},
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      return jsonMap['data'] == true;
    }
    return false;
  }

  Future<List<String>> fetchRemarkSuggestions(String query) async {
    final resp = await ApiClient.instance.get(
      '$baseUrl/remark-suggestions',
      queryParams: {'query': query},
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return (jsonMap['data'] as List<dynamic>).map((e) => e.toString()).toList();
      }
    }
    return [];
  }

  Future<IssueManagerPagedList> fetchIssues({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    String? issueMode,
    int page = 1,
    int pageSize = 25,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (fromDate != null) {
      queryParams['fromDate'] = fromDate.toIso8601String().substring(0, 10);
    }
    if (toDate != null) {
      queryParams['toDate'] = toDate.toIso8601String().substring(0, 10);
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (issueMode != null && issueMode.trim().isNotEmpty && issueMode != 'All') {
      queryParams['issueMode'] = issueMode.trim();
    }

    final resp = await ApiClient.instance.get(
      '$baseUrl/records',
      queryParams: queryParams,
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return IssueManagerPagedList.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to load issues.');
    }
    throw Exception('Failed to load issues (HTTP ${resp.statusCode}).');
  }

  Future<IssueManagerDetail> fetchIssueByCode(String code) async {
    final resp = await ApiClient.instance.get(
      '$baseUrl/by-code',
      queryParams: {'code': code},
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return IssueManagerDetail.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Issue not found.');
    }
    throw Exception('Failed to fetch issue details (HTTP ${resp.statusCode}).');
  }

  Future<IssueManagerSaveResult> createIssue(IssueManagerCreateRequest request) async {
    final resp = await ApiClient.instance.post(
      baseUrl,
      body: jsonEncode(request.toJson()),
    );

    final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200) {
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return IssueManagerSaveResult.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to save issue.');
    } else if (resp.statusCode == 400 || resp.statusCode == 403 || resp.statusCode == 500) {
      throw Exception(jsonMap['message']?.toString() ?? 'Server error saving issue.');
    }
    throw Exception('Failed to save issue (HTTP ${resp.statusCode}).');
  }

  Future<IssueManagerSaveResult> updateIssue(String code, IssueManagerCreateRequest request) async {
    final resp = await ApiClient.instance.put(
      '$baseUrl/by-code?code=${Uri.encodeComponent(code)}',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200) {
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return IssueManagerSaveResult.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to update issue.');
    } else if (resp.statusCode == 400 || resp.statusCode == 403 || resp.statusCode == 404 || resp.statusCode == 500) {
      throw Exception(jsonMap['message']?.toString() ?? 'Server error updating issue.');
    }
    throw Exception('Failed to update issue (HTTP ${resp.statusCode}).');
  }

  Future<IssueManagerSaveResult> deleteIssue(String code) async {
    final resp = await ApiClient.instance.delete(
      '$baseUrl/by-code',
      queryParams: {'code': code},
    );

    final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200) {
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return IssueManagerSaveResult.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to delete issue.');
    } else if (resp.statusCode == 400 || resp.statusCode == 403 || resp.statusCode == 404 || resp.statusCode == 500) {
      throw Exception(jsonMap['message']?.toString() ?? 'Server error deleting issue.');
    }
    throw Exception('Failed to delete issue (HTTP ${resp.statusCode}).');
  }
}
