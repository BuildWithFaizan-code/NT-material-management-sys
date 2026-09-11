import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Non-Stockable Item model (from NONSTKITM)
class NonStockableItem {
  final String iCode;
  final String iName1;
  final double rate;
  final int unitCode;
  final String unitName;
  final String sacCode;
  final int taxCode;
  final String taxName;

  NonStockableItem({
    required this.iCode,
    required this.iName1,
    required this.rate,
    required this.unitCode,
    required this.unitName,
    required this.sacCode,
    required this.taxCode,
    required this.taxName,
  });

  factory NonStockableItem.fromJson(Map<String, dynamic> json) {
    return NonStockableItem(
      iCode: (json['iCode'] ?? json['I_Code'] ?? json['I_CODE'] ?? '') as String,
      iName1: (json['iName1'] ?? json['I_Name1'] ?? json['I_NAME1'] ?? '') as String,
      rate: (json['rate'] ?? json['Rate'] ?? 0.0) is num
          ? (json['rate'] ?? json['Rate'] ?? 0.0).toDouble()
          : double.tryParse((json['rate'] ?? json['Rate'] ?? '0').toString()) ?? 0.0,
      unitCode: (json['unitCode'] ?? json['Unit_Code'] ?? 0) as int,
      unitName: (json['unitName'] ?? json['UNIT_NAME'] ?? '') as String,
      sacCode: (json['sacCode'] ?? json['Sac_Code'] ?? json['SAC_CODE'] ?? '') as String,
      taxCode: (json['taxCode'] ?? json['Tax_Code'] ?? 0) as int,
      taxName: (json['taxName'] ?? json['TAX_NAME'] ?? '') as String,
    );
  }
}

/// Unassigned Item model (from ITEMMST unassigned in NONSTKITM)
class UnassignedItem {
  final String iCode;
  final String iName1;
  final double rate;
  final String unitCode;
  final String sacCode;
  final String taxCode;

  UnassignedItem({
    required this.iCode,
    required this.iName1,
    required this.rate,
    required this.unitCode,
    required this.sacCode,
    required this.taxCode,
  });

  factory UnassignedItem.fromJson(Map<String, dynamic> json) {
    return UnassignedItem(
      iCode: (json['iCode'] ?? json['I_CODE'] ?? '') as String,
      iName1: (json['iName1'] ?? json['I_NAME1'] ?? '') as String,
      rate: (json['rate'] ?? json['I_SRATE'] ?? 0.0) is num
          ? (json['rate'] ?? json['I_SRATE'] ?? 0.0).toDouble()
          : double.tryParse((json['rate'] ?? json['I_SRATE'] ?? '0').toString()) ?? 0.0,
      unitCode: (json['unitCode'] ?? json['I_UOM'] ?? '').toString(),
      sacCode: (json['sacCode'] ?? json['I_HSN'] ?? '').toString(),
      taxCode: (json['taxCode'] ?? json['I_TAXSLAB'] ?? '').toString(),
    );
  }
}

/// Unit Dropdown Option
class UnitOption {
  final int unitCode;
  final String unitName;

  UnitOption({required this.unitCode, required this.unitName});

  factory UnitOption.fromJson(Map<String, dynamic> json) {
    return UnitOption(
      unitCode: (json['unitCode'] ?? json['UNIT_CODE'] ?? 0) as int,
      unitName: (json['unitName'] ?? json['UNIT_NAME'] ?? '') as String,
    );
  }
}

/// Tax Slab Dropdown Option
class TaxSlabOption {
  final int taxCode;
  final String taxName;

  TaxSlabOption({required this.taxCode, required this.taxName});

  factory TaxSlabOption.fromJson(Map<String, dynamic> json) {
    return TaxSlabOption(
      taxCode: (json['taxCode'] ?? json['TAX_CODE'] ?? 0) as int,
      taxName: (json['taxName'] ?? json['TAX_NAME'] ?? '') as String,
    );
  }
}

/// Dropdowns Bundle Model
class NonStockableDropdowns {
  final List<UnitOption> units;
  final List<TaxSlabOption> taxSlabs;

  NonStockableDropdowns({required this.units, required this.taxSlabs});

  factory NonStockableDropdowns.fromJson(Map<String, dynamic> json) {
    var rawUnits = json['units'] as List<dynamic>? ?? [];
    var rawTaxes = json['taxSlabs'] as List<dynamic>? ?? [];

    return NonStockableDropdowns(
      units: rawUnits.map((u) => UnitOption.fromJson(u as Map<String, dynamic>)).toList(),
      taxSlabs: rawTaxes.map((t) => TaxSlabOption.fromJson(t as Map<String, dynamic>)).toList(),
    );
  }
}

/// Save DTO
class SaveNonStockableItemDto {
  final String iCode;
  final String iName1;
  final double rate;
  final int unitCode;
  final String sacCode;
  final int taxCode;

  SaveNonStockableItemDto({
    required this.iCode,
    required this.iName1,
    required this.rate,
    required this.unitCode,
    required this.sacCode,
    required this.taxCode,
  });

  Map<String, dynamic> toJson() => {
        'iCode': iCode,
        'iName1': iName1,
        'rate': rate,
        'unitCode': unitCode,
        'sacCode': sacCode,
        'taxCode': taxCode,
      };
}

/// Singleton Service
class NonStockableItemService {
  NonStockableItemService._internal();
  static final NonStockableItemService _instance = NonStockableItemService._internal();
  factory NonStockableItemService() => _instance;

  String get _baseUrl => '${ApiConfig.baseUrl}/NonStockableItem';
  static const Duration _timeout = Duration(seconds: 10);

  /// Fetch Unit & Tax Slab dropdown options
  Future<NonStockableDropdowns?> getDropdowns() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/GetDropdowns'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return NonStockableDropdowns.fromJson(body['data']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch unassigned items from ITEMMST
  Future<List<UnassignedItem>> getUnassignedItems() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/GetUnassignedItems'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List<dynamic> list = body['data'];
          return list.map((item) => UnassignedItem.fromJson(item)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch all configured non-stockable items
  Future<List<NonStockableItem>> getAll() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/GetAll'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List<dynamic> list = body['data'];
          return list.map((item) => NonStockableItem.fromJson(item)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Save or Update non-stockable item
  Future<bool> save(SaveNonStockableItemDto dto) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/Save'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(dto.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Delete non-stockable item by I_Code
  Future<bool> delete(String code) async {
    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/Delete/$code'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
