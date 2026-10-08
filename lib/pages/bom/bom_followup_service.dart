import 'dart:convert';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import 'bom_followup_models.dart';

/// BOM Follow Up / Bill of Material Close Service
/// Interfaces directly with the live MMSERP Backend API.
/// Zero mock data: all records and dropdown filter options are fetched and updated in real-time.
class BomFollowupService {
  final String baseUrl;
  final ApiClient _client;

  BomFollowupService({
    String? baseUrl,
    ApiClient? client,
  })  : baseUrl = baseUrl ?? '${ApiConfig.baseUrl}/bomfollowup',
        _client = client ?? ApiClient.instance;

  /// Phase 1 / Query 1: Fetch active departments from LABOURMST
  /// SQL: SELECT LAB_NAME, LAB_CODE FROM LABOURMST WHERE (LAB_STATUS='' OR LAB_STATUS IS NULL OR LAB_STATUS='YES') ORDER BY LAB_NAME
  Future<List<BomFollowupDepartment>> fetchDepartments() async {
    final response = await _client.get('$baseUrl/departments');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = (decoded is Map ? decoded['data'] : decoded) as List? ?? [];
      return list.map((e) => BomFollowupDepartment.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(
      'Failed to load departments (status: ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  /// Phase 1 / Query 2: Fetch active divisions from KHATAMST
  /// SQL: SELECT KH_NAME, KH_CODE FROM KHATAMST WHERE (KH_DISPLAY IS NULL OR KH_DISPLAY=0) ORDER BY KH_NAME
  Future<List<BomFollowupDivision>> fetchDivisions() async {
    final response = await _client.get('$baseUrl/divisions');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = (decoded is Map ? decoded['data'] : decoded) as List? ?? [];
      return list.map((e) => BomFollowupDivision.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(
      'Failed to load divisions (status: ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  /// Phase 1 / Query 3: Fetch distinct BOM order types from BOMMST
  /// SQL: SELECT DISTINCT BOM_TYPE FROM BOMMST WHERE [PURPOSE]='COSTING' ORDER BY BOM_TYPE
  Future<List<BomFollowupOrderType>> fetchOrderTypes() async {
    final response = await _client.get('$baseUrl/order-types');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = (decoded is Map ? decoded['data'] : decoded) as List? ?? [];
      return list.map((e) => BomFollowupOrderType.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(
      'Failed to load order types (status: ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  /// Phase 2 / Query 4: Main grid data query with 6-table LEFT JOIN from BOMMST
  /// Resolves foreign keys to human-readable names and filters by date, department, division, order type.
  Future<List<BomFollowupRecord>> fetchRecords({
    DateTime? asOnDate,
    int? departmentCode,
    int? divisionCode,
    String? orderType,
  }) async {
    final queryParams = <String, String>{};
    if (asOnDate != null) {
      queryParams['asOnDate'] = asOnDate.toIso8601String();
    }
    if (departmentCode != null && departmentCode > 0) {
      queryParams['departmentCode'] = departmentCode.toString();
    }
    if (divisionCode != null && divisionCode > 0) {
      queryParams['divisionCode'] = divisionCode.toString();
    }
    if (orderType != null && orderType.isNotEmpty && orderType != 'ALL') {
      queryParams['orderType'] = orderType;
    }

    final response = await _client.get('$baseUrl/records', queryParams: queryParams);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = (decoded is Map ? decoded['data'] : decoded) as List? ?? [];
      return list.map((e) => BomFollowupRecord.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(
      'Failed to fetch open BOM records (status: ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  /// Phase 3 / Query 5: Pre-save Lock Verification (LOCKDATAMST)
  /// SQL: SELECT * FROM LOCKDATAMST WHERE @AsOnDate = LDM_STDT
  Future<bool> checkDateLock(DateTime date) async {
    final response = await _client.get(
      '$baseUrl/check-lock',
      queryParams: {'date': date.toIso8601String()},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return (decoded is Map ? decoded['data'] : decoded) == true;
    }
    throw ApiException(
      'Failed to check date lock status (status: ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  /// Convenience alias for checkDateLock
  Future<bool> checkLockDate(DateTime date) => checkDateLock(date);

  /// Phase 3 / Query 6 & 7: Batch close selected BOMs
  /// Atomically validates date lock, inserts 9-column DAYBOOK audit record,
  /// and updates BOMMST.Status to 'CLOSE' and BOM_ClDate to current timestamp.
  Future<BomFollowupCloseResult> closeBomRecords({
    required List<String> bomIds,
    required DateTime asOnDate,
    String username = 'ADMIN',
    String companyName = 'NEW TECH INFOSOL',
  }) async {
    if (bomIds.isEmpty) {
      return const BomFollowupCloseResult(
        success: false,
        closedCount: 0,
        message: 'No BOM records selected to close.',
      );
    }

    final response = await _client.post(
      '$baseUrl/close',
      body: {
        'bomIds': bomIds,
        'asOnDate': asOnDate.toIso8601String(),
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
      if (data is Map<String, dynamic>) {
        return BomFollowupCloseResult.fromJson(data);
      }
      return BomFollowupCloseResult(
        success: true,
        closedCount: bomIds.length,
        message: 'Successfully closed ${bomIds.length} BOM record(s).',
      );
    }

    String errorMsg = 'Failed to close BOM records (status: ${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        errorMsg = decoded['message'].toString();
      }
    } catch (_) {}

    return BomFollowupCloseResult(
      success: false,
      closedCount: 0,
      message: errorMsg,
    );
  }

  /// Convenience wrapper returning boolean success
  Future<bool> closeBomBatch(List<String> bomIds, DateTime asOnDate) async {
    final result = await closeBomRecords(bomIds: bomIds, asOnDate: asOnDate);
    return result.success;
  }
}
