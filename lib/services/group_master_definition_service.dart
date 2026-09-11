import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class GroupMasterDefinitionItem {
  final String ismMsCode;
  final String ismMCode;
  final String ismSubCode;
  final String ismSubCatCode;
  final String catName;
  final String catShort;
  final String wipName;

  GroupMasterDefinitionItem({
    required this.ismMsCode,
    required this.ismMCode,
    required this.ismSubCode,
    required this.ismSubCatCode,
    this.catName = '',
    this.catShort = '',
    this.wipName = '',
  });

  factory GroupMasterDefinitionItem.fromJson(Map<String, dynamic> json) {
    return GroupMasterDefinitionItem(
      ismMsCode: json['ismMsCode']?.toString() ?? '',
      ismMCode: json['ismMCode']?.toString() ?? '',
      ismSubCode: json['ismSubCode']?.toString() ?? '',
      ismSubCatCode: json['ismSubCatCode']?.toString() ?? '',
      catName: json['catName']?.toString() ?? '',
      catShort: json['catShort']?.toString() ?? '',
      wipName: json['wipName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ismMsCode': ismMsCode,
      'ismMCode': ismMCode,
      'ismSubCode': ismSubCode,
      'ismSubCatCode': ismSubCatCode,
      'catName': catName,
      'catShort': catShort,
      'wipName': wipName,
    };
  }
}

class CategoryLookupItem {
  final String catCode;
  final String catName;

  CategoryLookupItem({required this.catCode, required this.catName});

  factory CategoryLookupItem.fromJson(Map<String, dynamic> json) {
    return CategoryLookupItem(
      catCode: json['catCode']?.toString() ?? '',
      catName: json['catName']?.toString() ?? '',
    );
  }
}

class MainGroupLookupItem {
  final String wipCode;
  final String wipName;

  MainGroupLookupItem({required this.wipCode, required this.wipName});

  factory MainGroupLookupItem.fromJson(Map<String, dynamic> json) {
    return MainGroupLookupItem(
      wipCode: json['wipCode']?.toString() ?? '',
      wipName: json['wipName']?.toString() ?? '',
    );
  }
}

class GroupMasterDefinitionService {
  static String get baseUrl => '${ApiConfig.baseUrl}/GroupMasterDefinition';

  Future<List<GroupMasterDefinitionItem>> getMappedDefinitions({String? mCode}) async {
    try {
      final Uri uri = Uri.parse('$baseUrl/GetMappedDefinitions').replace(
        queryParameters: mCode != null && mCode.isNotEmpty ? {'mCode': mCode} : null,
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List list = body['data'];
          return list.map((e) => GroupMasterDefinitionItem.fromJson(e)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<CategoryLookupItem>> getCategories() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/GetCategories')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List list = body['data'];
          return list.map((e) => CategoryLookupItem.fromJson(e)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<MainGroupLookupItem>> getMainGroups() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/GetMainGroups')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List list = body['data'];
          return list.map((e) => MainGroupLookupItem.fromJson(e)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<String> getMainGroupName(String mCode) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/GetMainGroupName/$mCode')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return body['data'].toString();
        }
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  Future<bool> insertItem(GroupMasterDefinitionItem item) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Insert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(item.toJson()),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateItem(GroupMasterDefinitionItem item) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/Update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(item.toJson()),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteItem(String msCode) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/Delete/$msCode')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
