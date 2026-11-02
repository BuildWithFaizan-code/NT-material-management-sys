import 'dart:convert';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import 'material_return_models.dart';

class MaterialReturnService {
  String get baseUrl => '${ApiConfig.baseUrl}/MaterialReturn';

  Future<MaterialReturnLookups> fetchLookups() async {
    final resp = await ApiClient.instance.get('$baseUrl/lookups');

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return MaterialReturnLookups.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to load lookups.');
    }
    throw Exception('Failed to load Material Return lookups (HTTP ${resp.statusCode}).');
  }

  Future<String> fetchPreviewCode({
    required DateTime date,
    required String returnMode,
    required String fromDeptName,
  }) async {
    final resp = await ApiClient.instance.get(
      '$baseUrl/preview-code',
      queryParams: {
        'date': date.toIso8601String().substring(0, 10),
        'returnMode': returnMode,
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

  Future<MaterialReturnStockCatalogPagedResult> fetchStockCatalog({
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
        return MaterialReturnStockCatalogPagedResult.fromJson(
          jsonMap['data'] as Map<String, dynamic>,
        );
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to load stock catalog.');
    }
    throw Exception('Failed to load stock catalog (HTTP ${resp.statusCode}).');
  }

  Future<double> checkStock({
    required String itemCode,
    required DateTime date,
    required int sourceDept,
    required int sourceStore,
    required int sourceDiv,
  }) async {
    final resp = await ApiClient.instance.get(
      '$baseUrl/check-stock',
      queryParams: {
        'itemCode': itemCode,
        'date': date.toIso8601String().substring(0, 10),
        'sourceDept': sourceDept.toString(),
        'sourceStore': sourceStore.toString(),
        'sourceDiv': sourceDiv.toString(),
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
    try {
      final resp = await ApiClient.instance.get(
        '$baseUrl/is-date-locked',
        queryParams: {'date': date.toIso8601String().substring(0, 10)},
      );
      if (resp.statusCode == 200) {
        final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
        return jsonMap['data'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<List<String>> fetchRemarkSuggestions(String query) async {
    try {
      final resp = await ApiClient.instance.get(
        '$baseUrl/remark-suggestions',
        queryParams: {'q': query},
      );
      if (resp.statusCode == 200) {
        final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
        if (jsonMap['success'] == true && jsonMap['data'] != null) {
          return (jsonMap['data'] as List<dynamic>).map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<MaterialReturnPagedList> fetchRecords({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? returnMode,
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
      queryParams['fromDate'] = fromDate.toIso8601String().substring(0, 10);
    }
    if (toDate != null) {
      queryParams['toDate'] = toDate.toIso8601String().substring(0, 10);
    }
    if (returnMode != null && returnMode != 'All' && returnMode.isNotEmpty) {
      queryParams['returnMode'] = returnMode;
    }

    final resp = await ApiClient.instance.get(
      '$baseUrl/records',
      queryParams: queryParams,
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return MaterialReturnPagedList.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to load return records.');
    }
    throw Exception('Failed to load return records (HTTP ${resp.statusCode}).');
  }

  Future<MaterialReturnDetail> fetchByCode(String code) async {
    final resp = await ApiClient.instance.get(
      '$baseUrl/by-code',
      queryParams: {'code': code},
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return MaterialReturnDetail.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to load details.');
    }
    throw Exception('Failed to load return details (HTTP ${resp.statusCode}).');
  }

  Future<MaterialReturnSaveResult> createReturn(MaterialReturnCreateRequest request) async {
    final bodyJson = jsonEncode(request.toJson());
    final resp = await ApiClient.instance.post(
      baseUrl,
      headers: {'Content-Type': 'application/json'},
      body: bodyJson,
    );

    final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200 && jsonMap['success'] == true) {
      final data = jsonMap['data'] as Map<String, dynamic>?;
      return MaterialReturnSaveResult(
        success: true,
        docNo: data?['docNo']?.toString() ?? '',
        message: data?['message']?.toString() ?? 'Return created successfully.',
      );
    }

    final errorMsg = jsonMap['message']?.toString() ??
        'Failed to save return entry (HTTP ${resp.statusCode}).';
    return MaterialReturnSaveResult(
      success: false,
      docNo: '',
      message: errorMsg,
    );
  }

  Future<MaterialReturnSaveResult> updateReturn(
    String code,
    MaterialReturnCreateRequest request,
  ) async {
    final bodyJson = jsonEncode(request.toJson());
    final uri = '$baseUrl/by-code?code=${Uri.encodeComponent(code)}';
    final resp = await ApiClient.instance.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: bodyJson,
    );

    final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200 && jsonMap['success'] == true) {
      final data = jsonMap['data'] as Map<String, dynamic>?;
      return MaterialReturnSaveResult(
        success: true,
        docNo: data?['docNo']?.toString() ?? code,
        message: data?['message']?.toString() ?? 'Return updated successfully.',
      );
    }

    final errorMsg = jsonMap['message']?.toString() ??
        'Failed to update return entry (HTTP ${resp.statusCode}).';
    return MaterialReturnSaveResult(
      success: false,
      docNo: code,
      message: errorMsg,
    );
  }

  Future<bool> deleteReturn(String code) async {
    final resp = await ApiClient.instance.delete(
      '$baseUrl/by-code',
      queryParams: {'code': code},
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true) {
        return true;
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to delete return entry.');
    }
    final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
    throw Exception(jsonMap['message']?.toString() ?? 'HTTP ${resp.statusCode} on delete.');
  }
}
