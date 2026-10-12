import 'dart:convert';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import 'purchase_order_models.dart';

class PurchaseOrderService {
  final String baseUrl;
  final ApiClient _client;

  PurchaseOrderService({
    String? baseUrl,
    ApiClient? client,
  })  : baseUrl = baseUrl ?? '${ApiConfig.baseUrl}/purchaseorder',
        _client = client ?? ApiClient.instance;

  Future<PagedData<PurchaseOrderHeader>> fetchPurchaseOrders({
    DateTime? fromDate,
    DateTime? toDate,
    int? strCode,
    int? pCode,
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
    if (strCode != null && strCode > 0) queryParams['strCode'] = strCode.toString();
    if (pCode != null && pCode > 0) queryParams['pCode'] = pCode.toString();
    if (search != null && search.trim().isNotEmpty) queryParams['searchQuery'] = search.trim();

    final response = await _client.get(baseUrl, queryParams: queryParams);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        final itemsRaw = (data['items'] as List?) ?? [];
        final items = itemsRaw.map((e) => PurchaseOrderHeader.fromJson(e as Map<String, dynamic>)).toList();
        return PagedData<PurchaseOrderHeader>(
          items: items,
          totalCount: (data['totalCount'] ?? items.length) as int,
          page: (data['page'] ?? page) as int,
          pageSize: (data['pageSize'] ?? pageSize) as int,
        );
      }
    }
    throw ApiException(
      'Failed to fetch purchase orders (status: ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<PurchaseOrderHeader?> fetchPurchaseOrderByNo(String poNo) async {
    final cleanPo = poNo.trim();
    if (cleanPo.isEmpty) return null;
    final response = await _client.get('$baseUrl/by-no', queryParams: {'poNo': cleanPo});
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        return PurchaseOrderHeader.fromJson(data);
      }
    } else if (response.statusCode == 404) {
      return null;
    }
    throw ApiException(
      'Failed to fetch Purchase Order details for $poNo',
      statusCode: response.statusCode,
    );
  }

  Future<PurchaseOrderLookupsData> fetchLookups() async {
    final response = await _client.get('$baseUrl/lookups');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        return PurchaseOrderLookupsData.fromJson(data);
      }
    }
    throw ApiException(
      'Failed to fetch purchase order lookups',
      statusCode: response.statusCode,
    );
  }

  Future<PagedData<SupplierLookupItem>> fetchSuppliersLookup({
    String search = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = {
      'search': search.trim(),
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    final response = await _client.get('$baseUrl/suppliers', queryParams: queryParams);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        final itemsRaw = (data['items'] as List?) ?? [];
        final items = itemsRaw.map((e) => SupplierLookupItem.fromJson(e as Map<String, dynamic>)).toList();
        return PagedData<SupplierLookupItem>(
          items: items,
          totalCount: (data['totalCount'] ?? items.length) as int,
          page: (data['page'] ?? page) as int,
          pageSize: (data['pageSize'] ?? pageSize) as int,
        );
      }
    }
    throw ApiException('Failed to fetch suppliers', statusCode: response.statusCode);
  }

  Future<PagedData<ItemLookupItem>> fetchItemsLookup({
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
        final items = itemsRaw.map((e) => ItemLookupItem.fromJson(e as Map<String, dynamic>)).toList();
        return PagedData<ItemLookupItem>(
          items: items,
          totalCount: (data['totalCount'] ?? items.length) as int,
          page: (data['page'] ?? page) as int,
          pageSize: (data['pageSize'] ?? pageSize) as int,
        );
      }
    }
    throw ApiException('Failed to fetch catalog items', statusCode: response.statusCode);
  }

  Future<List<ItemMergeLookupItem>> fetchItemMerges(String itemCode) async {
    if (itemCode.trim().isEmpty) return [];
    final response = await _client.get('$baseUrl/item-merges/${Uri.encodeComponent(itemCode.trim())}');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = (decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded) as List? ?? [];
      return list.map((e) => ItemMergeLookupItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<String>> fetchShades() async {
    final response = await _client.get('$baseUrl/shades');
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
      queryParams: {'date': date.toIso8601String()},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return (decoded is Map ? decoded['data'] : decoded) == true;
    }
    return false;
  }

  Future<String> savePurchaseOrder(Map<String, dynamic> payload) async {
    final response = await _client.post(baseUrl, body: payload);
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded['success'] == true) {
      return (decoded['data'] ?? '').toString();
    }
    final msg = decoded is Map && decoded['message'] != null
        ? decoded['message'].toString()
        : 'Failed to save Purchase Order (Status: ${response.statusCode})';
    throw ApiException(msg, statusCode: response.statusCode);
  }

  Future<bool> deletePurchaseOrder(String poNo) async {
    final response = await _client.delete('$baseUrl/${Uri.encodeComponent(poNo.trim())}');
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded['success'] == true) {
      return true;
    }
    final msg = decoded is Map && decoded['message'] != null
        ? decoded['message'].toString()
        : 'Failed to delete Purchase Order (Status: ${response.statusCode})';
    throw ApiException(msg, statusCode: response.statusCode);
  }
}
