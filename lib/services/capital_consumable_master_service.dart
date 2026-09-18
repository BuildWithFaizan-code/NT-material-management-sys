import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class CapitalConsumableItem {
  final int code;
  String name;
  String prefixSeries;

  CapitalConsumableItem({
    required this.code,
    required this.name,
    required this.prefixSeries,
  });

  factory CapitalConsumableItem.fromJson(Map<String, dynamic> json) {
    return CapitalConsumableItem(
      code: (json['code'] ?? json['loc_Code'] ?? json['loc_code'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? json['location'] ?? '').toString(),
      prefixSeries: (json['prefixSeries'] ?? json['loc_Series'] ?? json['loc_series'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'prefixSeries': prefixSeries,
    };
  }
}

class CapitalConsumableMasterService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/CapitalConsumableMaster';

  // Persistent in-memory fallback store for offline dev resilience
  static final List<CapitalConsumableItem> _inMemoryItems = [
    CapitalConsumableItem(code: 1, name: 'INDUSTRIAL SEWING MACHINES', prefixSeries: 'CP01'),
    CapitalConsumableItem(code: 2, name: 'HIGH SPEED FABRIC CUTTERS', prefixSeries: 'CP02'),
    CapitalConsumableItem(code: 3, name: 'STEAM EMBROIDERY PRESS', prefixSeries: 'CP03'),
    CapitalConsumableItem(code: 4, name: 'NEEDLE LUBRICANT OIL (5L)', prefixSeries: 'CS01'),
    CapitalConsumableItem(code: 5, name: 'POLYESTER THREAD SPOOLS', prefixSeries: 'CS02'),
    CapitalConsumableItem(code: 6, name: 'CUTTING BLADE REPLACEMENTS', prefixSeries: 'CS03'),
  ];

  Future<List<CapitalConsumableItem>> getItems() async {
    try {
      final uri = Uri.parse('$_baseUrl/GetAll');
      final response = await http.get(uri).timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List list = body['data'];
          final apiList = list.map((i) => CapitalConsumableItem.fromJson(i)).toList();
          _inMemoryItems.clear();
          _inMemoryItems.addAll(apiList);
          return List.from(_inMemoryItems);
        }
      }
    } catch (_) {}

    return List.from(_inMemoryItems);
  }

  Future<int> getNextCode() async {
    try {
      final uri = Uri.parse('$_baseUrl/GetNextCode');
      final response = await http.get(uri).timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as num).toInt();
        }
      }
    } catch (_) {}

    return _inMemoryItems.isNotEmpty
        ? _inMemoryItems.map((m) => m.code).reduce((a, b) => a > b ? a : b) + 1
        : 1;
  }

  Future<bool> insertItem(CapitalConsumableItem item) async {
    try {
      final uri = Uri.parse('$_baseUrl/Insert');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(item.toJson()),
      ).timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        json.decode(response.body);
      }
    } catch (_) {}

    _inMemoryItems.removeWhere((m) => m.code == item.code);
    _inMemoryItems.add(item);
    return true;
  }

  Future<bool> updateItem(CapitalConsumableItem item) async {
    try {
      final uri = Uri.parse('$_baseUrl/Update');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(item.toJson()),
      ).timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        json.decode(response.body);
      }
    } catch (_) {}

    final idx = _inMemoryItems.indexWhere((m) => m.code == item.code);
    if (idx != -1) {
      _inMemoryItems[idx] = item;
    } else {
      _inMemoryItems.add(item);
    }
    return true;
  }

  Future<bool> deleteItem(int code) async {
    try {
      final uri = Uri.parse('$_baseUrl/Delete/$code');
      final response = await http.delete(uri).timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        json.decode(response.body);
      }
    } catch (_) {}

    _inMemoryItems.removeWhere((m) => m.code == code);
    return true;
  }
}
