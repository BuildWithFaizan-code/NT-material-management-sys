import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart';

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
      final response = await ApiClient.instance.get(
        '$baseUrl/GetMappedDefinitions',
        queryParams: mCode != null && mCode.isNotEmpty ? {'mCode': mCode} : null,
      );
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
      final response = await ApiClient.instance.get('$baseUrl/GetCategories');
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
      final response = await ApiClient.instance.get('$baseUrl/GetMainGroups');
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
      final response = await ApiClient.instance.get('$baseUrl/GetMainGroupName/$mCode');
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
      final response = await ApiClient.instance.post(
        '$baseUrl/Insert',
        body: item.toJson(),
      );
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
      final response = await ApiClient.instance.put(
        '$baseUrl/Update',
        body: item.toJson(),
      );
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
      final response = await ApiClient.instance.delete('$baseUrl/Delete/$msCode');
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
