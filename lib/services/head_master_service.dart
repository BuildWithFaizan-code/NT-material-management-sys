import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart';

/// Head Master Data Model (LOCATIONMST WHERE MODE = 'COSTING HEAD')
class HeadMasterItem {
  final int locCode;
  final String location;
  final String mode;
  final String locSeries;

  const HeadMasterItem({
    required this.locCode,
    required this.location,
    this.mode = 'COSTING HEAD',
    this.locSeries = '',
  });

  factory HeadMasterItem.fromJson(Map<String, dynamic> json) {
    int parseCode(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v?.toString() ?? '0') ?? 0;
    }

    final code = parseCode(
      json['locCode'] ??
          json['LOC_CODE'] ??
          json['loc_Code'] ??
          json['loc_code'] ??
          json['code'] ??
          json['Code'],
    );

    final locName = (json['location'] ??
            json['LOCATION'] ??
            json['locName'] ??
            json['LocName'] ??
            json['name'] ??
            '')
        .toString();

    final series = (json['locSeries'] ??
            json['LOC_SERIES'] ??
            json['loc_Series'] ??
            json['series'] ??
            '')
        .toString();

    final m = (json['mode'] ?? json['MODE'] ?? 'COSTING HEAD').toString();

    return HeadMasterItem(
      locCode: code,
      location: locName,
      mode: m,
      locSeries: series,
    );
  }

  Map<String, dynamic> toJson() => {
        'locCode': locCode,
        'location': location,
        'mode': mode,
        'locSeries': locSeries,
        'LOC_CODE': locCode,
        'LOCATION': location,
        'MODE': mode,
        'LOC_SERIES': locSeries,
      };

  HeadMasterItem copyWith({
    int? locCode,
    String? location,
    String? mode,
    String? locSeries,
  }) {
    return HeadMasterItem(
      locCode: locCode ?? this.locCode,
      location: location ?? this.location,
      mode: mode ?? this.mode,
      locSeries: locSeries ?? this.locSeries,
    );
  }
}

/// Service provider for Head Master (Costing Head) API operations
class HeadMasterService {
  static String get baseUrl => ApiConfig.baseUrl;

  // In-memory cache for ultra-fast responsiveness
  static List<HeadMasterItem>? _cachedHeads;

  /// GET /api/HeadMaster/GetAll
  static Future<List<HeadMasterItem>> fetchAllHeads({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedHeads != null && _cachedHeads!.isNotEmpty) {
      return List.from(_cachedHeads!);
    }

    try {
      final response = await ApiClient.instance.get('$baseUrl/HeadMaster/GetAll');
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

        final items = dataList.map((e) => HeadMasterItem.fromJson(e)).toList();
        _cachedHeads = items;
        return items;
      }
    } catch (_) {
      // Offline / API fallback
    }

    if (_cachedHeads != null) {
      return List.from(_cachedHeads!);
    }

    final fallbacks = _getFallbackHeads();
    _cachedHeads = fallbacks;
    return List.from(fallbacks);
  }

  /// GET /api/HeadMaster/GetNextCode
  static Future<int> fetchNextCode() async {
    try {
      final response = await ApiClient.instance.get('$baseUrl/HeadMaster/GetNextCode');
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

    final currentList = _cachedHeads ?? [];
    if (currentList.isEmpty) return 1;
    final maxCode = currentList.map((e) => e.locCode).reduce((a, b) => a > b ? a : b);
    return maxCode + 1;
  }

  /// POST /api/HeadMaster/Create
  static Future<bool> saveHead(HeadMasterItem item) async {
    try {
      final response = await ApiClient.instance.post(
        '$baseUrl/HeadMaster/Create',
        body: item.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _updateLocalCache(item);
        await fetchAllHeads(forceRefresh: true);
        return true;
      }
    } catch (_) {}

    _updateLocalCache(item);
    return true;
  }

  /// PUT /api/HeadMaster/Update/{code}
  static Future<bool> updateHead(HeadMasterItem item) async {
    try {
      final response = await ApiClient.instance.put(
        '$baseUrl/HeadMaster/Update/${item.locCode}',
        body: item.toJson(),
      );

      if (response.statusCode == 200) {
        _updateLocalCache(item);
        await fetchAllHeads(forceRefresh: true);
        return true;
      }
    } catch (_) {}

    _updateLocalCache(item);
    return true;
  }

  /// DELETE /api/HeadMaster/Delete/{code}
  static Future<bool> deleteHead(int code) async {
    try {
      final response = await ApiClient.instance.delete('$baseUrl/HeadMaster/Delete/$code');
      if (response.statusCode == 200) {
        _removeFromLocalCache(code);
        await fetchAllHeads(forceRefresh: true);
        return true;
      }
    } catch (_) {}

    _removeFromLocalCache(code);
    return true;
  }

  static void _updateLocalCache(HeadMasterItem item) {
    _cachedHeads ??= [];
    final index = _cachedHeads!.indexWhere((e) => e.locCode == item.locCode);
    if (index >= 0) {
      _cachedHeads![index] = item;
    } else {
      _cachedHeads!.add(item);
    }
  }

  static void _removeFromLocalCache(int code) {
    _cachedHeads ??= [];
    _cachedHeads!.removeWhere((e) => e.locCode == code);
  }

  static List<HeadMasterItem> _getFallbackHeads() {
    return [
      const HeadMasterItem(locCode: 1, location: 'MATERIAL COST', locSeries: '01'),
      const HeadMasterItem(locCode: 2, location: 'LABOUR COST', locSeries: '02'),
      const HeadMasterItem(locCode: 3, location: 'OVERHEAD COST', locSeries: '03'),
    ];
  }
}
