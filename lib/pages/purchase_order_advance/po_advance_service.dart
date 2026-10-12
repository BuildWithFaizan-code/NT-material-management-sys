import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import 'po_advance_models.dart';

class PoAdvanceService {
  final String baseUrl;
  final ApiClient _client;

  PoAdvanceService({
    String? baseUrl,
    ApiClient? client,
  })  : baseUrl = baseUrl ?? '${ApiConfig.baseUrl}/po-advance',
        _client = client ?? ApiClient.instance;

  /// Fetch suppliers who have approved purchase orders
  Future<List<PoAdvancePartyLookup>> fetchParties() async {
    final response = await _client.get('$baseUrl/parties');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is List) {
        return data.map((item) => PoAdvancePartyLookup.fromJson(item as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  /// Fetch valid, approved, unreceived PO numbers for selected party
  Future<List<String>> fetchPosForParty(int partyCode) async {
    if (partyCode <= 0) return [];
    final response = await _client.get('$baseUrl/pos?partyCode=$partyCode');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is List) {
        return data.map((e) => e.toString()).toList();
      }
    }
    return [];
  }

  /// Fetch PO date, NETAMT, total prior advances (TOTGIV), and pending balance
  Future<PoAdvanceHeaderDetails?> fetchPoDetails(String poNo, DateTime appDate) async {
    if (poNo.trim().isEmpty) return null;
    final encodedPo = Uri.encodeComponent(poNo.trim());
    final dateStr = appDate.toIso8601String();
    final response = await _client.get('$baseUrl/po-details?poNo=$encodedPo&appDate=$dateStr');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        return PoAdvanceHeaderDetails.fromJson(data);
      }
    }
    return null;
  }

  /// Fetch advance payment records for selected PO No.
  Future<List<PoAdvanceHistoryRecord>> fetchPoAdvanceHistory(String poNo) async {
    if (poNo.trim().isEmpty) return [];
    final encodedPo = Uri.encodeComponent(poNo.trim());
    final response = await _client.get('$baseUrl/history?poNo=$encodedPo');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is List) {
        return data.map((item) => PoAdvanceHistoryRecord.fromJson(item as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  /// Fetch all advance records across all parties/POs for the master Show Record modal
  Future<List<PoAdvanceHistoryRecord>> fetchAllAdvances({String? search, int limit = 500}) async {
    final queryParams = <String>[];
    if (search != null && search.trim().isNotEmpty) {
      queryParams.add('search=${Uri.encodeComponent(search.trim())}');
    }
    if (limit > 0) {
      queryParams.add('limit=$limit');
    }
    final qs = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final response = await _client.get('$baseUrl/all$qs');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is List) {
        return data.map((item) => PoAdvanceHistoryRecord.fromJson(item as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  /// Fetch summary of all advances given to this party across all POs
  Future<List<PoAdvancePartySummary>> fetchPartyAdvanceSummaries(int partyCode) async {
    if (partyCode <= 0) return [];
    final response = await _client.get('$baseUrl/party-advances?partyCode=$partyCode');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is List) {
        return data.map((item) => PoAdvancePartySummary.fromJson(item as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  /// Verify whether the transaction date is locked in LOCKDATAMST
  Future<bool> checkDateLock(DateTime date) async {
    try {
      final response = await _client.get('$baseUrl/check-lock?date=${date.toIso8601String()}');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
        if (data is bool) return data;
      }
    } catch (e) {
      debugPrint('Error checking date lock: $e');
    }
    return false;
  }

  /// Record an advance payment
  Future<int> createAdvance(PoAdvanceCreatePayload payload) async {
    final response = await _client.post(
      baseUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload.toJson()),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is int) return data;
      if (data is num) return data.toInt();
      return 1;
    } else {
      final message = decoded is Map && decoded.containsKey('message')
          ? decoded['message'].toString()
          : 'Failed to record advance payment (HTTP ${response.statusCode})';
      throw Exception(message);
    }
  }

  /// Delete / void an advance record
  Future<bool> deleteAdvance(int poId) async {
    final response = await _client.delete('$baseUrl/$poId');
    if (response.statusCode == 200) {
      return true;
    } else {
      final decoded = jsonDecode(response.body);
      final message = decoded is Map && decoded.containsKey('message')
          ? decoded['message'].toString()
          : 'Failed to delete advance record (HTTP ${response.statusCode})';
      throw Exception(message);
    }
  }
}
