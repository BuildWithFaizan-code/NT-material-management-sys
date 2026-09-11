import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class MainGroupMasterItem {
  final String wipCode;
  final String wipName;
  final String wipMode;

  MainGroupMasterItem({
    required this.wipCode,
    required this.wipName,
    required this.wipMode,
  });

  factory MainGroupMasterItem.fromJson(Map<String, dynamic> json) {
    return MainGroupMasterItem(
      wipCode: (json['wipCode'] ?? '').toString(),
      wipName: (json['wipName'] ?? '').toString(),
      wipMode: (json['wipMode'] ?? 'Regular').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wipCode': wipCode,
      'wipName': wipName,
      'wipMode': wipMode.isEmpty ? 'Regular' : wipMode,
    };
  }
}

class MainGroupMasterService {
  static String get baseUrl => '${ApiConfig.baseUrl}/MainGroupMaster';

  Future<List<MainGroupMasterItem>> getAllItems({String? search}) async {
    final uri = Uri.parse(
      search != null && search.isNotEmpty
          ? '$baseUrl/GetAll?search=${Uri.encodeComponent(search)}'
          : '$baseUrl/GetAll',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final List list = json['data'];
          return list.map((item) => MainGroupMasterItem.fromJson(item)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<String?> fetchNextCode() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/GetNextCode')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return json['data'].toString();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> insertItem(MainGroupMasterItem item) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Insert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(item.toJson()),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> updateItem(MainGroupMasterItem item) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/Update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(item.toJson()),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> deleteItem(String wipCode) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/Delete/$wipCode'),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
    } catch (_) {}
    return false;
  }
}
