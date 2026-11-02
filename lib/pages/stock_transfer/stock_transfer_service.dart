import 'dart:convert';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import 'stock_transfer_models.dart';

class StockTransferService {
  String get baseUrl => '${ApiConfig.baseUrl}/stocktransfer';

  Future<StockTransferLookups> fetchLookups({int? fromStoreId}) async {
    final queryParams = <String, String>{};
    if (fromStoreId != null) {
      queryParams['fromStoreId'] = fromStoreId.toString();
    }

    final resp = await ApiClient.instance.get(
      '$baseUrl/lookups',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return StockTransferLookups.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to load lookups.');
    }
    throw Exception('Failed to load stock transfer lookups (HTTP ${resp.statusCode}).');
  }

  Future<String> fetchPreviewCode({required DateTime date, required String issueMode}) async {
    final resp = await ApiClient.instance.get(
      '$baseUrl/preview-code',
      queryParams: {
        'date': date.toIso8601String().substring(0, 10),
        'issueMode': issueMode,
      },
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return jsonMap['data'].toString();
      }
    }
    return '';
  }

  Future<List<StockTransferLookupItem>> fetchToStores(int fromStoreId) async {
    final resp = await ApiClient.instance.get(
      '$baseUrl/to-stores',
      queryParams: {'fromStoreId': fromStoreId.toString()},
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return (jsonMap['data'] as List<dynamic>)
            .map((e) => StockTransferLookupItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to load To-Stores.');
    }
    throw Exception('Failed to load To-Stores (HTTP ${resp.statusCode}).');
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

  Future<List<PendingRequisitionItem>> fetchPendingRequisitions({String? search}) async {
    final queryParams = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final resp = await ApiClient.instance.get(
      '$baseUrl/pending-requisitions',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return (jsonMap['data'] as List<dynamic>)
            .map((e) => PendingRequisitionItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to load pending requisitions.');
    }
    throw Exception('Failed to load pending requisitions (HTTP ${resp.statusCode}).');
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
    final queryParams = <String, String>{
      'date': date.toIso8601String().substring(0, 10),
      'itemCode': itemCode,
      'sourceDept': sourceDept.toString(),
      'sourceStore': sourceStore.toString(),
      'sourceDiv': sourceDiv.toString(),
      'uom': uom.toString(),
    };
    if (currentDocNo != null && currentDocNo.isNotEmpty) {
      queryParams['currentDocNo'] = currentDocNo;
    }
    if (mrgNo != null && mrgNo.isNotEmpty) queryParams['mrgNo'] = mrgNo;
    if (grade != null && grade.isNotEmpty) queryParams['grade'] = grade;
    if (shade != null && shade.isNotEmpty) queryParams['shade'] = shade;

    final resp = await ApiClient.instance.get(
      '$baseUrl/check-stock',
      queryParams: queryParams,
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true) {
        return (jsonMap['data'] as num?)?.toDouble() ?? 0.0;
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
      if (jsonMap['success'] == true) {
        return jsonMap['data'] == true;
      }
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

  Future<StockTransferPagedList> fetchTransfers({
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
        return StockTransferPagedList.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to load stock transfers.');
    }
    throw Exception('Failed to load stock transfers (HTTP ${resp.statusCode}).');
  }

  Future<StockTransferDetail> fetchTransferByCode(String code) async {
    final resp = await ApiClient.instance.get(
      '$baseUrl/by-code',
      queryParams: {'code': code},
    );

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        return StockTransferDetail.fromJson(jsonMap['data'] as Map<String, dynamic>);
      }
      throw Exception(jsonMap['message']?.toString() ?? 'Failed to load transfer detail.');
    }
    throw Exception('Failed to load transfer detail (HTTP ${resp.statusCode}).');
  }

  Future<String> createTransfer(StockTransferCreateRequest request) async {
    final resp = await ApiClient.instance.post(
      baseUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200 && jsonMap['success'] == true) {
      final data = jsonMap['data'] as Map<String, dynamic>?;
      return data?['issueCode']?.toString() ?? 'Created';
    }
    throw Exception(jsonMap['message']?.toString() ?? 'Failed to create stock transfer.');
  }

  Future<String> updateTransfer(String issueCode, StockTransferCreateRequest request) async {
    final resp = await ApiClient.instance.put(
      '$baseUrl/by-code?code=${Uri.encodeComponent(issueCode)}',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200 && jsonMap['success'] == true) {
      final data = jsonMap['data'] as Map<String, dynamic>?;
      return data?['issueCode']?.toString() ?? issueCode;
    }
    throw Exception(jsonMap['message']?.toString() ?? 'Failed to update stock transfer.');
  }

  Future<bool> deleteTransfer(String issueCode) async {
    final resp = await ApiClient.instance.delete(
      '$baseUrl/by-code?code=${Uri.encodeComponent(issueCode)}',
    );

    final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200 && jsonMap['success'] == true) {
      return true;
    }
    throw Exception(jsonMap['message']?.toString() ?? 'Failed to delete stock transfer.');
  }
}
