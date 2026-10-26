import 'dart:convert';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import 'indent_approval_models.dart';

class IndentApprovalService {
  final String? _customBaseUrl;
  String get baseUrl => _customBaseUrl ?? '${ApiConfig.baseUrl}/indentapproval';

  final ApiClient _client;

  IndentApprovalService({
    String? baseUrl,
    ApiClient? client,
  })  : _customBaseUrl = baseUrl,
        _client = client ?? ApiClient.instance;

  Future<IndentApprovalLookups> fetchLookups() async {
    final url = '$baseUrl/lookups';
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        return IndentApprovalLookups.fromJson(data);
      }
    }
    throw ApiException('Failed to load indent approval lookups (status: ${response.statusCode})');
  }

  Future<List<IndentApprovalRecord>> fetchRecords({
    DateTime? asOnDate,
    DateTime? fromDate,
    DateTime? toDate,
    String? statusFilter,
    String? indCode,
    int? deptCode,
    String? itemCode,
  }) async {
    final queryParams = <String, String>{};

    if (asOnDate != null) {
      queryParams['asOnDate'] = asOnDate.toIso8601String();
    }
    if (fromDate != null) {
      queryParams['fromDate'] = fromDate.toIso8601String();
    }
    if (toDate != null) {
      queryParams['toDate'] = toDate.toIso8601String();
    }
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
      queryParams['statusFilter'] = statusFilter;
    } else if (statusFilter == 'ALL') {
      queryParams['statusFilter'] = 'ALL';
    }
    if (indCode != null && indCode.isNotEmpty && indCode != 'ALL') {
      queryParams['indCode'] = indCode;
    }
    if (deptCode != null && deptCode > 0) {
      queryParams['deptCode'] = deptCode.toString();
    }
    if (itemCode != null && itemCode.isNotEmpty && itemCode != 'ALL') {
      queryParams['itemCode'] = itemCode;
    }

    final response = await _client.get('$baseUrl/records', queryParams: queryParams);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is List) {
        return data.map((e) => IndentApprovalRecord.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    throw ApiException('Failed to load indent approval records (status: ${response.statusCode})');
  }

  Future<bool> checkDateLock(DateTime date) async {
    final response = await _client.get('$baseUrl/check-lock', queryParams: {'date': date.toIso8601String()});
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is bool) return data;
    }
    return false;
  }

  Future<IndentApprovalActionResult> processApprovalBatch(IndentApprovalActionPayload payload) async {
    final response = await _client.post(
      '$baseUrl/process',
      body: payload.toJson(),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        return IndentApprovalActionResult.fromJson(data);
      }
      return IndentApprovalActionResult(
        success: true,
        message: decoded['message']?.toString() ?? 'Batch processed successfully.',
        affectedCount: payload.items.length,
      );
    }

    String errorMessage = 'Approval processing failed (status: ${response.statusCode})';
    if (decoded is Map && decoded['message'] != null) {
      errorMessage = decoded['message'].toString();
    }
    throw ApiException(errorMessage, statusCode: response.statusCode);
  }
}
