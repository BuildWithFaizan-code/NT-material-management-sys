import 'dart:convert';
import 'package:http/http.dart' as http;

class MakersMasterItem {
  final int makerCode;
  String makerName;
  String prefixSeries;

  MakersMasterItem({
    required this.makerCode,
    required this.makerName,
    required this.prefixSeries,
  });

  factory MakersMasterItem.fromJson(Map<String, dynamic> json) {
    return MakersMasterItem(
      makerCode: (json['makerCode'] ?? json['loc_Code'] ?? json['loc_code'] as num?)?.toInt() ?? 0,
      makerName: (json['makerName'] ?? json['location'] ?? '').toString(),
      prefixSeries: (json['prefixSeries'] ?? json['loc_Series'] ?? json['loc_series'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'makerCode': makerCode,
      'makerName': makerName,
      'prefixSeries': prefixSeries,
    };
  }
}

class MakersMasterService {
  static const String _baseUrl = 'http://localhost:5000/api/MakersMaster';

  // Persistent in-memory fallback store for offline dev resilience
  static final List<MakersMasterItem> _inMemoryMakers = [
    MakersMasterItem(makerCode: 1, makerName: 'RUDRA FABRICS', prefixSeries: '01'),
    MakersMasterItem(makerCode: 2, makerName: 'TEX TECH INDUSTRIES', prefixSeries: '02'),
    MakersMasterItem(makerCode: 3, makerName: 'SHREE MAHALAXMI MILLS', prefixSeries: '03'),
    MakersMasterItem(makerCode: 4, makerName: 'VARDHMAN TEXTILES', prefixSeries: '04'),
    MakersMasterItem(makerCode: 5, makerName: 'APEX KNITTING WORKS', prefixSeries: '05'),
    MakersMasterItem(makerCode: 6, makerName: 'GLOBAL APPAREL MAKERS', prefixSeries: '06'),
  ];

  Future<List<MakersMasterItem>> getMakers() async {
    try {
      final uri = Uri.parse('$_baseUrl/GetAll');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List list = body['data'];
          final apiList = list.map((i) => MakersMasterItem.fromJson(i)).toList();
          _inMemoryMakers.clear();
          _inMemoryMakers.addAll(apiList);
          return List.from(_inMemoryMakers);
        }
      }
    } catch (_) {}

    return List.from(_inMemoryMakers);
  }

  Future<int> getNextMakerCode() async {
    try {
      final uri = Uri.parse('$_baseUrl/GetNextCode');
      final response = await http.get(uri).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as num).toInt();
        }
      }
    } catch (_) {}

    return _inMemoryMakers.isNotEmpty
        ? _inMemoryMakers.map((m) => m.makerCode).reduce((a, b) => a > b ? a : b) + 1
        : 1;
  }

  Future<bool> insertMaker(MakersMasterItem item) async {
    try {
      final uri = Uri.parse('$_baseUrl/Insert');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(item.toJson()),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        json.decode(response.body);
      }
    } catch (_) {}

    _inMemoryMakers.removeWhere((m) => m.makerCode == item.makerCode);
    _inMemoryMakers.add(item);
    return true;
  }

  Future<bool> updateMaker(MakersMasterItem item) async {
    try {
      final uri = Uri.parse('$_baseUrl/Update');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(item.toJson()),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        json.decode(response.body);
      }
    } catch (_) {}

    final idx = _inMemoryMakers.indexWhere((m) => m.makerCode == item.makerCode);
    if (idx != -1) {
      _inMemoryMakers[idx] = item;
    } else {
      _inMemoryMakers.add(item);
    }
    return true;
  }

  Future<bool> deleteMaker(int makerCode) async {
    try {
      final uri = Uri.parse('$_baseUrl/Delete/$makerCode');
      final response = await http.delete(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        json.decode(response.body);
      }
    } catch (_) {}

    _inMemoryMakers.removeWhere((m) => m.makerCode == makerCode);
    return true;
  }
}
