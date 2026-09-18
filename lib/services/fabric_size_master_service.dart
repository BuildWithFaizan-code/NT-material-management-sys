import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class FabricSizeItem {
  final int sizeCode;
  String sizeName;

  FabricSizeItem({
    required this.sizeCode,
    required this.sizeName,
  });

  factory FabricSizeItem.fromJson(Map<String, dynamic> json) {
    return FabricSizeItem(
      sizeCode: (json['sizeCode'] ?? json['sizE_CODE'] as num?)?.toInt() ?? 0,
      sizeName: (json['sizeName'] ?? json['sizE_NAME'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sizeCode': sizeCode,
      'sizeName': sizeName,
    };
  }
}

class FabricSizeMasterService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/FabricSizeMaster';

  static final List<FabricSizeItem> _inMemorySizes = [
    FabricSizeItem(sizeCode: 1, sizeName: 'SMALL'),
    FabricSizeItem(sizeCode: 2, sizeName: 'MEDIUM'),
    FabricSizeItem(sizeCode: 3, sizeName: 'LARGE'),
    FabricSizeItem(sizeCode: 4, sizeName: 'EXTRA LARGE (XL)'),
    FabricSizeItem(sizeCode: 5, sizeName: 'DOUBLE XL (XXL)'),
    FabricSizeItem(sizeCode: 6, sizeName: 'TRIPLE XL (3XL)'),
    FabricSizeItem(sizeCode: 7, sizeName: 'FREE SIZE'),
  ];

  Future<List<FabricSizeItem>> getFabricSizes() async {
    try {
      final uri = Uri.parse('$_baseUrl/GetAll');
      final response = await http.get(uri).timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List list = body['data'];
          final apiList = list.map((i) => FabricSizeItem.fromJson(i)).toList();
          _inMemorySizes.clear();
          _inMemorySizes.addAll(apiList);
          return List.from(_inMemorySizes);
        }
      }
    } catch (_) {}

    return List.from(_inMemorySizes);
  }

  Future<int> getNextSizeCode() async {
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

    return _inMemorySizes.isNotEmpty
        ? _inMemorySizes.map((m) => m.sizeCode).reduce((a, b) => a > b ? a : b) + 1
        : 1;
  }

  Future<bool> insertFabricSize(FabricSizeItem item) async {
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

    _inMemorySizes.removeWhere((m) => m.sizeCode == item.sizeCode);
    _inMemorySizes.add(item);
    return true;
  }

  Future<bool> updateFabricSize(FabricSizeItem item) async {
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

    final idx = _inMemorySizes.indexWhere((m) => m.sizeCode == item.sizeCode);
    if (idx != -1) {
      _inMemorySizes[idx] = item;
    } else {
      _inMemorySizes.add(item);
    }
    return true;
  }

  Future<bool> deleteFabricSize(int sizeCode) async {
    try {
      final uri = Uri.parse('$_baseUrl/Delete/$sizeCode');
      final response = await http.delete(uri).timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        json.decode(response.body);
      }
    } catch (_) {}

    _inMemorySizes.removeWhere((m) => m.sizeCode == sizeCode);
    return true;
  }
}
