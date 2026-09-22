import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart';

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
    try {
      final response = await ApiClient.instance.get(
        '$baseUrl/GetAll',
        queryParams: search != null && search.isNotEmpty ? {'search': search} : null,
      );
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
      final response = await ApiClient.instance.get('$baseUrl/GetNextCode');
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
      final response = await ApiClient.instance.post(
        '$baseUrl/Insert',
        body: item.toJson(),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> updateItem(MainGroupMasterItem item) async {
    try {
      final response = await ApiClient.instance.put(
        '$baseUrl/Update',
        body: item.toJson(),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> deleteItem(String wipCode) async {
    try {
      final response = await ApiClient.instance.delete(
        '$baseUrl/Delete/$wipCode',
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
    } catch (_) {}
    return false;
  }
}
