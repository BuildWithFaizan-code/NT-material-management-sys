import 'dart:convert';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import 'sales_order_models.dart';

class SalesOrderService {
  final String baseUrl;
  final ApiClient _client;

  SalesOrderService({
    String? baseUrl,
    ApiClient? client,
  })  : baseUrl = baseUrl ?? '${ApiConfig.baseUrl}/salesorder',
        _client = client ?? ApiClient.instance;

  Future<PagedData<SalesOrderHeader>> fetchSalesOrders({
    DateTime? fromDate,
    DateTime? toDate,
    int? costCd,
    int? pCode,
    int? spCd,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (fromDate != null) queryParams['fromDate'] = fromDate.toIso8601String();
    if (toDate != null) queryParams['toDate'] = toDate.toIso8601String();
    if (costCd != null && costCd > 0) queryParams['costCd'] = costCd.toString();
    if (pCode != null && pCode > 0) queryParams['pCode'] = pCode.toString();
    if (spCd != null && spCd > 0) queryParams['spCd'] = spCd.toString();
    if (search != null && search.trim().isNotEmpty) queryParams['searchQuery'] = search.trim();

    final response = await _client.get(baseUrl, queryParams: queryParams);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        final itemsRaw = (data['items'] as List?) ?? [];
        final items = itemsRaw.map((e) => SalesOrderHeader.fromJson(e as Map<String, dynamic>)).toList();
        return PagedData<SalesOrderHeader>(
          items: items,
          totalCount: (data['totalCount'] ?? items.length) as int,
          page: (data['page'] ?? page) as int,
          pageSize: (data['pageSize'] ?? pageSize) as int,
        );
      }
    }
    throw ApiException(
      'Failed to fetch sales orders (status: ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<SalesOrderHeader?> fetchSalesOrderByNo(String soNo) async {
    final cleanSo = soNo.trim();
    if (cleanSo.isEmpty) return null;
    final response = await _client.get('$baseUrl/by-no', queryParams: {'soNo': cleanSo});
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        return SalesOrderHeader.fromJson(data);
      }
    } else if (response.statusCode == 404) {
      return null;
    }
    throw ApiException(
      'Failed to fetch Sales Order details for $soNo',
      statusCode: response.statusCode,
    );
  }

  Future<SalesOrderLookups> fetchLookups() async {
    final response = await _client.get('$baseUrl/lookups');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        return SalesOrderLookups.fromJson(data);
      }
    }
    throw ApiException(
      'Failed to fetch sales order lookups',
      statusCode: response.statusCode,
    );
  }

  Future<PagedData<CustomerLookup>> fetchCustomersLookup({
    String search = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = {
      'search': search.trim(),
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    final response = await _client.get('$baseUrl/customers', queryParams: queryParams);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        final itemsRaw = (data['items'] as List?) ?? [];
        final items = itemsRaw.map((e) => CustomerLookup.fromJson(e as Map<String, dynamic>)).toList();
        return PagedData<CustomerLookup>(
          items: items,
          totalCount: (data['totalCount'] ?? items.length) as int,
          page: (data['page'] ?? page) as int,
          pageSize: (data['pageSize'] ?? pageSize) as int,
        );
      }
    }
    throw ApiException('Failed to fetch customers', statusCode: response.statusCode);
  }

  Future<PagedData<SalesOrderItemLookup>> fetchItemsLookup({
    String search = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = {
      'search': search.trim(),
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    final response = await _client.get('$baseUrl/items', queryParams: queryParams);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        final itemsRaw = (data['items'] as List?) ?? [];
        final items = itemsRaw.map((e) => SalesOrderItemLookup.fromJson(e as Map<String, dynamic>)).toList();
        return PagedData<SalesOrderItemLookup>(
          items: items,
          totalCount: (data['totalCount'] ?? items.length) as int,
          page: (data['page'] ?? page) as int,
          pageSize: (data['pageSize'] ?? pageSize) as int,
        );
      }
    }
    throw ApiException('Failed to fetch catalog items', statusCode: response.statusCode);
  }

  Future<List<String>> fetchRemarksLookup(String query) async {
    final response = await _client.get('$baseUrl/remarks', queryParams: {'query': query.trim()});
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = (decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded) as List? ?? [];
      return list.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<bool> checkDateLock(DateTime date) async {
    final response = await _client.get(
      '$baseUrl/check-lock',
      queryParams: {'date': date.toIso8601String().split('T').first},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return (decoded['data'] == true);
    }
    return false;
  }

  Future<String> saveSalesOrder(Map<String, dynamic> payload) async {
    final response = await _client.post(baseUrl, body: payload);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['data']?.toString() ?? 'SUCCESS';
    }
    final decoded = jsonDecode(response.body);
    final msg = decoded['message']?.toString() ?? 'Failed to save sales order';
    throw ApiException(msg, statusCode: response.statusCode);
  }

  Future<bool> deleteSalesOrder(String soNo) async {
    final cleanSo = soNo.trim();
    final response = await _client.delete('$baseUrl/by-no', queryParams: {'soNo': cleanSo});
    if (response.statusCode == 200) {
      return true;
    }
    final decoded = jsonDecode(response.body);
    final msg = decoded['message']?.toString() ?? 'Failed to delete sales order';
    throw ApiException(msg, statusCode: response.statusCode);
  }
}
