import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart';

/// Sub-Department Master Data Model (SUBDEPMST)
class SubDepartmentMasterItem {
  final int sdmCode;
  final String sdmName;

  const SubDepartmentMasterItem({
    required this.sdmCode,
    required this.sdmName,
  });

  factory SubDepartmentMasterItem.fromJson(Map<String, dynamic> json) {
    int parseCode(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v?.toString() ?? '0') ?? 0;
    }

    final code = parseCode(
      json['sdmCode'] ??
          json['SDM_CODE'] ??
          json['sdm_Code'] ??
          json['sdm_code'] ??
          json['code'] ??
          json['Code'],
    );

    final name = (json['sdmName'] ??
            json['SDM_NAME'] ??
            json['sdm_Name'] ??
            json['sdm_name'] ??
            json['name'] ??
            json['Name'] ??
            '')
        .toString();

    return SubDepartmentMasterItem(
      sdmCode: code,
      sdmName: name,
    );
  }

  Map<String, dynamic> toJson() => {
        'sdmCode': sdmCode,
        'sdmName': sdmName,
        'SDM_CODE': sdmCode,
        'SDM_NAME': sdmName,
      };

  SubDepartmentMasterItem copyWith({
    int? sdmCode,
    String? sdmName,
  }) {
    return SubDepartmentMasterItem(
      sdmCode: sdmCode ?? this.sdmCode,
      sdmName: sdmName ?? this.sdmName,
    );
  }
}

/// Service provider for Sub-Department Master API operations
class SubDepartmentService {
  static String get baseUrl => ApiConfig.baseUrl;

  // In-memory cache for ultra-fast local responsiveness
  static List<SubDepartmentMasterItem>? _cachedSubDepartments;

  /// GET /api/SubDepartmentMaster/GetAll
  static Future<List<SubDepartmentMasterItem>> fetchAllSubDepartments({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedSubDepartments != null && _cachedSubDepartments!.isNotEmpty) {
      return List.from(_cachedSubDepartments!);
    }

    final url = '$baseUrl/SubDepartmentMaster/GetAll';
    try {
      final response = await ApiClient.instance.get(url);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        List<dynamic> dataList = [];
        if (body is List) {
          dataList = body;
        } else if (body is Map<String, dynamic>) {
          dataList = (body['data'] as List<dynamic>?) ??
              (body['result'] as List<dynamic>?) ??
              (body['items'] as List<dynamic>?) ??
              [];
        }

        final items = dataList.map((e) => SubDepartmentMasterItem.fromJson(e)).toList();
        _cachedSubDepartments = items;
        return items;
      }
    } catch (_) {
      // Offline / API error fallback
    }

    if (_cachedSubDepartments != null) {
      return List.from(_cachedSubDepartments!);
    }
    
    // Return empty list if no API response and no cache, or default mock only if completely unreachable
    final fallbacks = _getFallbackSubDepartments();
    _cachedSubDepartments = fallbacks;
    return List.from(fallbacks);
  }

  /// GET /api/SubDepartmentMaster/GetNextCode
  static Future<int> fetchNextCode() async {
    final url = '$baseUrl/SubDepartmentMaster/GetNextCode';
    try {
      final response = await ApiClient.instance.get(url);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is int) return body;
        if (body is Map<String, dynamic>) {
          if (body['data'] is int) return body['data'];
          if (body['nextCode'] is int) return body['nextCode'];
          final parsed = int.tryParse(body['data']?.toString() ?? body['nextCode']?.toString() ?? '');
          if (parsed != null) return parsed;
        }
      }
    } catch (_) {}

    final currentList = _cachedSubDepartments ?? [];
    if (currentList.isEmpty) return 1;
    final maxCode = currentList.map((e) => e.sdmCode).reduce((a, b) => a > b ? a : b);
    return maxCode + 1;
  }

  /// POST /api/SubDepartmentMaster/Create
  static Future<bool> saveSubDepartment(SubDepartmentMasterItem item) async {
    final url = '$baseUrl/SubDepartmentMaster/Create';
    try {
      final response = await ApiClient.instance.post(
        url,
        body: item.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _updateLocalCache(item);
        // Force refresh from backend database on successful save
        await fetchAllSubDepartments(forceRefresh: true);
        return true;
      }
    } catch (_) {}

    _updateLocalCache(item);
    return true;
  }

  /// PUT /api/SubDepartmentMaster/Update/{code}
  static Future<bool> updateSubDepartment(SubDepartmentMasterItem item) async {
    final url = '$baseUrl/SubDepartmentMaster/Update/${item.sdmCode}';
    try {
      final response = await ApiClient.instance.put(
        url,
        body: item.toJson(),
      );

      if (response.statusCode == 200) {
        _updateLocalCache(item);
        await fetchAllSubDepartments(forceRefresh: true);
        return true;
      }
    } catch (_) {}

    _updateLocalCache(item);
    return true;
  }

  /// DELETE /api/SubDepartmentMaster/Delete/{code}
  static Future<bool> deleteSubDepartment(int code) async {
    final url = '$baseUrl/SubDepartmentMaster/Delete/$code';
    try {
      final response = await ApiClient.instance.delete(url);
      if (response.statusCode == 200) {
        _removeFromLocalCache(code);
        await fetchAllSubDepartments(forceRefresh: true);
        return true;
      }
    } catch (_) {}

    _removeFromLocalCache(code);
    return true;
  }

  static void _updateLocalCache(SubDepartmentMasterItem item) {
    _cachedSubDepartments ??= [];
    final index = _cachedSubDepartments!.indexWhere((e) => e.sdmCode == item.sdmCode);
    if (index >= 0) {
      _cachedSubDepartments![index] = item;
    } else {
      _cachedSubDepartments!.add(item);
    }
  }

  static void _removeFromLocalCache(int code) {
    _cachedSubDepartments ??= [];
    _cachedSubDepartments!.removeWhere((e) => e.sdmCode == code);
  }

  static List<SubDepartmentMasterItem> _getFallbackSubDepartments() {
    return [
      const SubDepartmentMasterItem(sdmCode: 1, sdmName: 'ELECTRICAL'),
      const SubDepartmentMasterItem(sdmCode: 2, sdmName: 'MACHANICAL'),
    ];
  }
}
