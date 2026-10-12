import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import 'po_approval_models.dart';

class PoApprovalService {
  final String baseUrl;
  final ApiClient _client;

  PoApprovalService({
    String? baseUrl,
    ApiClient? client,
  })  : baseUrl = baseUrl ?? '${ApiConfig.baseUrl}/poapproval',
        _client = client ?? ApiClient.instance;

  /// Fetch lookups for departments, plants, and suppliers
  Future<PoApprovalLookupsData> fetchLookups() async {
    final response = await _client.get('$baseUrl/lookups');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        return PoApprovalLookupsData.fromJson(data);
      }
    }
    return const PoApprovalLookupsData();
  }

  /// Fetch PO line records with view mode and filtering
  Future<List<PoApprovalRecord>> fetchRecords({
    String viewMode = 'PENDING',
    int? deptCode,
    int? plantCode,
    int? partyCode,
    String? poNo,
    String? itemSearch,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final queryParams = <String, String>{
      'viewMode': viewMode,
    };
    if (deptCode != null && deptCode > 0) {
      queryParams['deptCode'] = deptCode.toString();
    }
    if (plantCode != null && plantCode > 0) {
      queryParams['plantCode'] = plantCode.toString();
    }
    if (partyCode != null && partyCode > 0) {
      queryParams['partyCode'] = partyCode.toString();
    }
    if (poNo != null && poNo.trim().isNotEmpty) {
      queryParams['poNo'] = poNo.trim();
    }
    if (itemSearch != null && itemSearch.trim().isNotEmpty) {
      queryParams['itemSearch'] = itemSearch.trim();
    }
    if (fromDate != null) {
      queryParams['fromDate'] = fromDate.toIso8601String();
    }
    if (toDate != null) {
      queryParams['toDate'] = toDate.toIso8601String();
    }

    final response = await _client.get('$baseUrl/records', queryParams: queryParams);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = (decoded is Map ? decoded['data'] : decoded) as List? ?? [];
      return list.map((item) => PoApprovalRecord.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw ApiException(
      'Failed to fetch PO approval records (status: ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  /// Check date lock in LOCKDATAMST
  Future<bool> checkLockDate(DateTime date) async {
    try {
      final response = await _client.get(
        '$baseUrl/check-lock',
        queryParams: {'date': date.toIso8601String()},
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return (decoded is Map ? decoded['data'] : decoded) as bool? ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking date lock: $e');
      return false;
    }
  }

  /// Process status action (Approve, Reject, Hold, Close, UnClose)
  Future<int> processStatusAction({
    required String actionType,
    required DateTime approvalDate,
    String? remark,
    required List<PoApprovalActionItemPayload> items,
  }) async {
    final payload = {
      'actionType': actionType,
      'approvalDate': approvalDate.toIso8601String(),
      'remark': remark ?? '',
      'items': items.map((i) => i.toJson()).toList(),
    };

    final response = await _client.post(
      '$baseUrl/process',
      body: payload,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final count = decoded is Map ? decoded['data'] : decoded;
      return (count as num?)?.toInt() ?? items.length;
    } else {
      String errMsg = 'Failed to process PO action (status: ${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('message')) {
          errMsg = decoded['message'].toString();
        }
      } catch (_) {}
      throw ApiException(errMsg, statusCode: response.statusCode);
    }
  }
}
