import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GroupMasterItem {
  final String catCode;
  final String catName;
  final String catHsn;
  final String catTaxSlab;
  final String palletReq;
  final String sizeReq;
  final String boxReq;
  final String gradeReq;
  final String gsmReq;
  final double catTol;
  final String catShort;
  final String packTypeName;

  GroupMasterItem({
    required this.catCode,
    required this.catName,
    required this.catHsn,
    required this.catTaxSlab,
    required this.palletReq,
    required this.sizeReq,
    required this.boxReq,
    required this.gradeReq,
    required this.gsmReq,
    required this.catTol,
    required this.catShort,
    required this.packTypeName,
  });

  factory GroupMasterItem.fromJson(Map<String, dynamic> json) {
    return GroupMasterItem(
      catCode: (json['catCode'] ?? '').toString(),
      catName: (json['catName'] ?? '').toString(),
      catHsn: (json['catHsn'] ?? '').toString(),
      catTaxSlab: (json['catTaxSlab'] ?? '').toString(),
      palletReq: (json['palletReq'] ?? 'No').toString(),
      sizeReq: (json['sizeReq'] ?? 'No').toString(),
      boxReq: (json['boxReq'] ?? 'No').toString(),
      gradeReq: (json['gradeReq'] ?? 'No').toString(),
      gsmReq: (json['gsmReq'] ?? 'No').toString(),
      catTol: (json['catTol'] is num) ? (json['catTol'] as num).toDouble() : (double.tryParse((json['catTol'] ?? '0').toString()) ?? 0.0),
      catShort: (json['catShort'] ?? '').toString(),
      packTypeName: (json['packTypeName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'catCode': catCode,
      'catName': catName,
      'catHsn': catHsn,
      'catTaxSlab': catTaxSlab,
      'palletReq': palletReq.isEmpty ? 'No' : palletReq,
      'sizeReq': sizeReq.isEmpty ? 'No' : sizeReq,
      'boxReq': boxReq.isEmpty ? 'No' : boxReq,
      'gradeReq': gradeReq.isEmpty ? 'No' : gradeReq,
      'gsmReq': gsmReq.isEmpty ? 'No' : gsmReq,
      'catTol': catTol,
      'catShort': catShort,
      'packTypeName': packTypeName,
    };
  }
}

class TaxSlabItem {
  final String taxCode;
  final String taxName;

  TaxSlabItem({required this.taxCode, required this.taxName});

  factory TaxSlabItem.fromJson(Map<String, dynamic> json) {
    return TaxSlabItem(
      taxCode: (json['taxCode'] ?? '').toString(),
      taxName: (json['taxName'] ?? '').toString(),
    );
  }
}

class GroupMasterService {
  static const String baseUrl = 'http://localhost:5000/api/GroupMaster';

  Future<List<GroupMasterItem>> getAllItems({String? search}) async {
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
          return list.map((item) => GroupMasterItem.fromJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('GroupMasterService.getAllItems error: $e');
    }
    return [];
  }

  Future<String> getNextCode() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/GetNextCode')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return json['data'].toString();
        }
      }
    } catch (e) {
      debugPrint('GroupMasterService.getNextCode error: $e');
    }
    return '1';
  }

  Future<List<TaxSlabItem>> getTaxSlabs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/GetTaxSlabs')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final List list = json['data'];
          return list.map((item) => TaxSlabItem.fromJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('GroupMasterService.getTaxSlabs error: $e');
    }
    return [];
  }

  Future<bool> insertItem(GroupMasterItem item) async {
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
    } catch (e) {
      debugPrint('GroupMasterService.insertItem error: $e');
    }
    return false;
  }

  Future<bool> updateItem(GroupMasterItem item) async {
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
    } catch (e) {
      debugPrint('GroupMasterService.updateItem error: $e');
    }
    return false;
  }

  Future<bool> deleteItem(String code) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/Delete/${Uri.encodeComponent(code)}'),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
    } catch (e) {
      debugPrint('GroupMasterService.deleteItem error: $e');
    }
    return false;
  }
}
