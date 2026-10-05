import 'package:flutter/foundation.dart';

/// BOM operational modes corresponding to database prefixes.
enum BomMode {
  regular('REGULAR', 'BMCC', 'R'),
  job('JOB', 'BMCJ', 'J');

  final String label;
  final String prefix;
  final String skuCross;

  const BomMode(this.label, this.prefix, this.skuCross);
}

/// Store/Plant lookup entity (from STOREMST)
class BomStoreLookup {
  final int strCode;
  final String strName;

  const BomStoreLookup({
    required this.strCode,
    required this.strName,
  });

  factory BomStoreLookup.fromJson(Map<String, dynamic> json) {
    return BomStoreLookup(
      strCode: (json['STR_CODE'] ?? json['strCode'] ?? 0) is int
          ? (json['STR_CODE'] ?? json['strCode'] ?? 0)
          : (int.tryParse((json['STR_CODE'] ?? json['strCode'] ?? '0').toString()) ?? 0),
      strName: (json['STR_NAME'] ?? json['strName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'strCode': strCode,
        'strName': strName,
      };
}

/// Department/Labour lookup entity (from LABOURMST)
class BomDepartmentLookup {
  final int labCode;
  final String labName;

  const BomDepartmentLookup({
    required this.labCode,
    required this.labName,
  });

  factory BomDepartmentLookup.fromJson(Map<String, dynamic> json) {
    return BomDepartmentLookup(
      labCode: (json['LAB_CODE'] ?? json['labCode'] ?? 0) is int
          ? (json['LAB_CODE'] ?? json['labCode'] ?? 0)
          : (int.tryParse((json['LAB_CODE'] ?? json['labCode'] ?? '0').toString()) ?? 0),
      labName: (json['LAB_NAME'] ?? json['labName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'labCode': labCode,
        'labName': labName,
      };
}

/// Unit of Measure lookup entity (from UNITMST)
class BomUnitLookup {
  final int unitCode;
  final String unitName;

  const BomUnitLookup({
    required this.unitCode,
    required this.unitName,
  });

  factory BomUnitLookup.fromJson(Map<String, dynamic> json) {
    return BomUnitLookup(
      unitCode: (json['UNIT_CODE'] ?? json['unitCode'] ?? 0) is int
          ? (json['UNIT_CODE'] ?? json['unitCode'] ?? 0)
          : (int.tryParse((json['UNIT_CODE'] ?? json['unitCode'] ?? '0').toString()) ?? 0),
      unitName: (json['UNIT_NAME'] ?? json['unitName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'unitCode': unitCode,
        'unitName': unitName,
      };
}

/// Finished Good item entity (from ITEMMST + SKUMST where WIP_NAME='FINISH')
@immutable
class FinishedGoodItem {
  final String iCode;
  final String itName;
  final String unitName;
  final int unitCode;
  final String status; // 'OPEN' or 'BLOCKED'
  final String skuCross; // 'J' or 'R'
  final int catCode;

  const FinishedGoodItem({
    required this.iCode,
    required this.itName,
    required this.unitName,
    required this.unitCode,
    this.status = 'OPEN',
    this.skuCross = 'J',
    this.catCode = 0,
  });

  factory FinishedGoodItem.fromJson(Map<String, dynamic> json) {
    return FinishedGoodItem(
      iCode: (json['I_CODE'] ?? json['iCode'] ?? '').toString(),
      itName: (json['IT_NAME'] ?? json['I_NAME1'] ?? json['itName'] ?? '').toString(),
      unitName: (json['UNIT_NAME'] ?? json['unitName'] ?? '').toString(),
      unitCode: (json['UNIT_CODE'] ?? json['unitCode'] ?? 0) is int
          ? (json['UNIT_CODE'] ?? json['unitCode'] ?? 0)
          : (int.tryParse((json['UNIT_CODE'] ?? json['unitCode'] ?? '0').toString()) ?? 0),
      status: (json['STATUS'] ?? json['status'] ?? 'OPEN').toString().toUpperCase(),
      skuCross: (json['SKU_CROSS'] ?? json['skuCross'] ?? 'J').toString().toUpperCase(),
      catCode: (json['CAT_CODE'] ?? json['catCode'] ?? 0) is int
          ? (json['CAT_CODE'] ?? json['catCode'] ?? 0)
          : (int.tryParse((json['CAT_CODE'] ?? json['catCode'] ?? '0').toString()) ?? 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'iCode': iCode,
        'itName': itName,
        'unitName': unitName,
        'unitCode': unitCode,
        'status': status,
        'skuCross': skuCross,
        'catCode': catCode,
      };
}

/// BOM Header entity mapping to BOMMst table
@immutable
class BomHeaderData {
  final String bomId;
  final String bomCode;
  final int depCode;
  final String depName;
  final int strCode;
  final String strName;
  final String iCode;
  final String description;
  final double qty;
  final int unitCode;
  final String unitName;
  final String purpose;
  final String status;
  final String bomType;
  final DateTime bomDate;
  final String bomPo;
  final String bomLoc;
  final String bomUsrName;
  final String bomEMode;
  final DateTime bomEDate;

  const BomHeaderData({
    required this.bomId,
    this.bomCode = '',
    required this.depCode,
    this.depName = '',
    required this.strCode,
    this.strName = '',
    required this.iCode,
    required this.description,
    required this.qty,
    required this.unitCode,
    this.unitName = '',
    this.purpose = 'Costing',
    this.status = 'OPEN',
    required this.bomType,
    required this.bomDate,
    this.bomPo = '',
    this.bomLoc = 'LWHL26_SQL',
    this.bomUsrName = 'ADMIN',
    this.bomEMode = 'New',
    required this.bomEDate,
  });

  factory BomHeaderData.fromJson(Map<String, dynamic> json) {
    return BomHeaderData(
      bomId: (json['BOMID'] ?? json['bomId'] ?? '').toString(),
      bomCode: (json['BOMCode'] ?? json['bomCode'] ?? '').toString(),
      depCode: (json['BOM_DEPCODE'] ?? json['depCode'] ?? 0) is int
          ? (json['BOM_DEPCODE'] ?? json['depCode'] ?? 0)
          : (int.tryParse((json['BOM_DEPCODE'] ?? json['depCode'] ?? '0').toString()) ?? 0),
      depName: (json['DEP_NAME'] ?? json['depName'] ?? '').toString(),
      strCode: (json['BOM_STRCODE'] ?? json['strCode'] ?? 0) is int
          ? (json['BOM_STRCODE'] ?? json['strCode'] ?? 0)
          : (int.tryParse((json['BOM_STRCODE'] ?? json['strCode'] ?? '0').toString()) ?? 0),
      strName: (json['STR_NAME'] ?? json['strName'] ?? '').toString(),
      iCode: (json['I_Code'] ?? json['iCode'] ?? '').toString(),
      description: (json['DESCRIPTION'] ?? json['description'] ?? '').toString(),
      qty: (json['Qty'] ?? json['qty'] ?? 1.0) is num
          ? (json['Qty'] ?? json['qty'] ?? 1.0).toDouble()
          : (double.tryParse((json['Qty'] ?? json['qty'] ?? '1').toString()) ?? 1.0),
      unitCode: (json['Unit_Code'] ?? json['unitCode'] ?? 0) is int
          ? (json['Unit_Code'] ?? json['unitCode'] ?? 0)
          : (int.tryParse((json['Unit_Code'] ?? json['unitCode'] ?? '0').toString()) ?? 0),
      unitName: (json['UNIT_NAME'] ?? json['unitName'] ?? '').toString(),
      purpose: (json['Purpose'] ?? json['purpose'] ?? 'Costing').toString(),
      status: (json['Status'] ?? json['status'] ?? 'OPEN').toString().toUpperCase(),
      bomType: (json['Bom_Type'] ?? json['bomType'] ?? 'JOB').toString(),
      bomDate: (json['Bom_Date'] ?? json['bomDate']) != null
          ? DateTime.tryParse((json['Bom_Date'] ?? json['bomDate']).toString()) ?? DateTime.now()
          : DateTime.now(),
      bomPo: (json['Bom_PO'] ?? json['bomPo'] ?? '').toString(),
      bomLoc: (json['BOM_LOC'] ?? json['bomLoc'] ?? 'LWHL26_SQL').toString(),
      bomUsrName: (json['BOM_UsrName'] ?? json['bomUsrName'] ?? 'ADMIN').toString(),
      bomEMode: (json['BOM_EMode'] ?? json['bomEMode'] ?? 'New').toString(),
      bomEDate: (json['BOM_EDate'] ?? json['bomEDate']) != null
          ? DateTime.tryParse((json['BOM_EDate'] ?? json['bomEDate']).toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'bomId': bomId,
        'bomCode': bomCode,
        'depCode': depCode,
        'depName': depName,
        'strCode': strCode,
        'strName': strName,
        'iCode': iCode,
        'description': description,
        'qty': qty,
        'unitCode': unitCode,
        'unitName': unitName,
        'purpose': purpose,
        'status': status,
        'bomType': bomType,
        'bomDate': bomDate.toIso8601String(),
        'bomPo': bomPo,
        'bomLoc': bomLoc,
        'bomUsrName': bomUsrName,
        'bomEMode': bomEMode,
        'bomEDate': bomEDate.toIso8601String(),
      };
}

/// Component item entity (from ITEMMST + SUBITEMMST for BOM Sub-Items)
@immutable
class ComponentLookupItem {
  final String iCode;
  final String itName;
  final int unitCode;
  final String unitName;
  final int catCode;
  final String materialType;
  final int secUcode;
  final String secUnit;
  final String sku;
  final String printCode;
  final double convQty;

  const ComponentLookupItem({
    required this.iCode,
    required this.itName,
    required this.unitCode,
    required this.unitName,
    this.catCode = 0,
    this.materialType = '',
    this.secUcode = 0,
    this.secUnit = '',
    this.sku = '',
    this.printCode = '',
    this.convQty = 1.0,
  });

  factory ComponentLookupItem.fromJson(Map<String, dynamic> json) {
    return ComponentLookupItem(
      iCode: (json['I_CODE'] ?? json['iCode'] ?? '').toString(),
      itName: (json['IT_NAME'] ?? json['I_NAME1'] ?? json['itName'] ?? '').toString(),
      unitCode: (json['UNIT_CODE'] ?? json['unitCode'] ?? 0) is int
          ? (json['UNIT_CODE'] ?? json['unitCode'] ?? 0)
          : (int.tryParse((json['UNIT_CODE'] ?? json['unitCode'] ?? '0').toString()) ?? 0),
      unitName: (json['UNIT_NAME'] ?? json['unitName'] ?? '').toString(),
      catCode: (json['CAT_CODE'] ?? json['catCode'] ?? 0) is int
          ? (json['CAT_CODE'] ?? json['catCode'] ?? 0)
          : (int.tryParse((json['CAT_CODE'] ?? json['catCode'] ?? '0').toString()) ?? 0),
      materialType: (json['MATERIAL_TYPE'] ?? json['WIP_NAME'] ?? json['materialType'] ?? '').toString(),
      secUcode: (json['SEC_UCODE'] ?? json['secUcode'] ?? 0) is int
          ? (json['SEC_UCODE'] ?? json['secUcode'] ?? 0)
          : (int.tryParse((json['SEC_UCODE'] ?? json['secUcode'] ?? '0').toString()) ?? 0),
      secUnit: (json['SEC_UNIT'] ?? json['secUnit'] ?? '').toString(),
      sku: (json['SKU'] ?? json['sku'] ?? '').toString(),
      printCode: (json['PRINT_CODE'] ?? json['I_DISPNM'] ?? json['printCode'] ?? '').toString(),
      convQty: (json['CONV_QTY'] ?? json['SIM_CONVQTY'] ?? json['convQty'] ?? 1.0) is num
          ? (json['CONV_QTY'] ?? json['SIM_CONVQTY'] ?? json['convQty'] ?? 1.0).toDouble()
          : (double.tryParse((json['CONV_QTY'] ?? json['SIM_CONVQTY'] ?? json['convQty'] ?? '1').toString()) ?? 1.0),
    );
  }

  Map<String, dynamic> toJson() => {
        'iCode': iCode,
        'itName': itName,
        'unitCode': unitCode,
        'unitName': unitName,
        'catCode': catCode,
        'materialType': materialType,
        'secUcode': secUcode,
        'secUnit': secUnit,
        'sku': sku,
        'printCode': printCode,
        'convQty': convQty,
      };
}

/// BOM Sub-Item entity mapping to BOMSubMst table
@immutable
class BomSubItemData {
  final String bomsId;
  final String bomsCode;
  final int itGroupCd;
  final String iCode;
  final String description;
  final String materialType;
  final double qty;
  final int unitCode;
  final String unitName;
  final double sqm;
  final double bomCons;
  final double bomExtra;
  final double bomTolQty;
  final double bomTotQty;
  final double convQty;
  final double bomRate;
  final double bomAmount;
  final String bomRemarks;

  const BomSubItemData({
    required this.bomsId,
    required this.bomsCode,
    this.itGroupCd = 0,
    required this.iCode,
    required this.description,
    this.materialType = '',
    required this.qty,
    required this.unitCode,
    this.unitName = '',
    this.sqm = 0.0,
    this.bomCons = 0.0,
    this.bomExtra = 0.0,
    this.bomTolQty = 0.0,
    this.bomTotQty = 0.0,
    this.convQty = 1.0,
    this.bomRate = 0.0,
    this.bomAmount = 0.0,
    this.bomRemarks = '',
  });

  BomSubItemData copyWith({
    String? bomsId,
    String? bomsCode,
    int? itGroupCd,
    String? iCode,
    String? description,
    String? materialType,
    double? qty,
    int? unitCode,
    String? unitName,
    double? sqm,
    double? bomCons,
    double? bomExtra,
    double? bomTolQty,
    double? bomTotQty,
    double? convQty,
    double? bomRate,
    double? bomAmount,
    String? bomRemarks,
  }) {
    return BomSubItemData(
      bomsId: bomsId ?? this.bomsId,
      bomsCode: bomsCode ?? this.bomsCode,
      itGroupCd: itGroupCd ?? this.itGroupCd,
      iCode: iCode ?? this.iCode,
      description: description ?? this.description,
      materialType: materialType ?? this.materialType,
      qty: qty ?? this.qty,
      unitCode: unitCode ?? this.unitCode,
      unitName: unitName ?? this.unitName,
      sqm: sqm ?? this.sqm,
      bomCons: bomCons ?? this.bomCons,
      bomExtra: bomExtra ?? this.bomExtra,
      bomTolQty: bomTolQty ?? this.bomTolQty,
      bomTotQty: bomTotQty ?? this.bomTotQty,
      convQty: convQty ?? this.convQty,
      bomRate: bomRate ?? this.bomRate,
      bomAmount: bomAmount ?? this.bomAmount,
      bomRemarks: bomRemarks ?? this.bomRemarks,
    );
  }

  factory BomSubItemData.fromJson(Map<String, dynamic> json) {
    return BomSubItemData(
      bomsId: (json['BOMSID'] ?? json['bomsId'] ?? '').toString(),
      bomsCode: (json['BOMSCode'] ?? json['bomsCode'] ?? '').toString(),
      itGroupCd: (json['It_GroupCD'] ?? json['itGroupCd'] ?? 0) is int
          ? (json['It_GroupCD'] ?? json['itGroupCd'] ?? 0)
          : (int.tryParse((json['It_GroupCD'] ?? json['itGroupCd'] ?? '0').toString()) ?? 0),
      iCode: (json['I_Code'] ?? json['iCode'] ?? '').toString(),
      description: (json['DESCRIPTION'] ?? json['description'] ?? '').toString(),
      materialType: (json['Material_Type'] ?? json['materialType'] ?? '').toString(),
      qty: (json['Qty'] ?? json['qty'] ?? 0.0) is num
          ? (json['Qty'] ?? json['qty'] ?? 0.0).toDouble()
          : (double.tryParse((json['Qty'] ?? json['qty'] ?? '0').toString()) ?? 0.0),
      unitCode: (json['Unit_Code'] ?? json['unitCode'] ?? 0) is int
          ? (json['Unit_Code'] ?? json['unitCode'] ?? 0)
          : (int.tryParse((json['Unit_Code'] ?? json['unitCode'] ?? '0').toString()) ?? 0),
      unitName: (json['UNIT_NAME'] ?? json['unitName'] ?? '').toString(),
      sqm: (json['SQM'] ?? json['BOM_GSM'] ?? json['sqm'] ?? 0.0) is num
          ? (json['SQM'] ?? json['BOM_GSM'] ?? json['sqm'] ?? 0.0).toDouble()
          : (double.tryParse((json['SQM'] ?? json['BOM_GSM'] ?? json['sqm'] ?? '0').toString()) ?? 0.0),
      bomCons: (json['Bom_Cons'] ?? json['bomCons'] ?? 0.0) is num
          ? (json['Bom_Cons'] ?? json['bomCons'] ?? 0.0).toDouble()
          : (double.tryParse((json['Bom_Cons'] ?? json['bomCons'] ?? '0').toString()) ?? 0.0),
      bomExtra: (json['Bom_Extra'] ?? json['bomExtra'] ?? 0.0) is num
          ? (json['Bom_Extra'] ?? json['bomExtra'] ?? 0.0).toDouble()
          : (double.tryParse((json['Bom_Extra'] ?? json['bomExtra'] ?? '0').toString()) ?? 0.0),
      bomTolQty: (json['Bom_TolQty'] ?? json['bomTolQty'] ?? 0.0) is num
          ? (json['Bom_TolQty'] ?? json['bomTolQty'] ?? 0.0).toDouble()
          : (double.tryParse((json['Bom_TolQty'] ?? json['bomTolQty'] ?? '0').toString()) ?? 0.0),
      bomTotQty: (json['Bom_TotQty'] ?? json['bomTotQty'] ?? 0.0) is num
          ? (json['Bom_TotQty'] ?? json['bomTotQty'] ?? 0.0).toDouble()
          : (double.tryParse((json['Bom_TotQty'] ?? json['bomTotQty'] ?? '0').toString()) ?? 0.0),
      convQty: (json['Conv_Qty'] ?? json['convQty'] ?? 1.0) is num
          ? (json['Conv_Qty'] ?? json['convQty'] ?? 1.0).toDouble()
          : (double.tryParse((json['Conv_Qty'] ?? json['convQty'] ?? '1').toString()) ?? 1.0),
      bomRate: (json['Bom_Rate'] ?? json['bomRate'] ?? 0.0) is num
          ? (json['Bom_Rate'] ?? json['bomRate'] ?? 0.0).toDouble()
          : (double.tryParse((json['Bom_Rate'] ?? json['bomRate'] ?? '0').toString()) ?? 0.0),
      bomAmount: (json['Bom_Amount'] ?? json['bomAmount'] ?? 0.0) is num
          ? (json['Bom_Amount'] ?? json['bomAmount'] ?? 0.0).toDouble()
          : (double.tryParse((json['Bom_Amount'] ?? json['bomAmount'] ?? '0').toString()) ?? 0.0),
      bomRemarks: (json['Bom_Remarks'] ?? json['bomRemarks'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'bomsId': bomsId,
        'bomsCode': bomsCode,
        'itGroupCd': itGroupCd,
        'iCode': iCode,
        'description': description,
        'materialType': materialType,
        'qty': qty,
        'unitCode': unitCode,
        'unitName': unitName,
        'sqm': sqm,
        'bomCons': bomCons,
        'bomExtra': bomExtra,
        'bomTolQty': bomTolQty,
        'bomTotQty': bomTotQty,
        'convQty': convQty,
        'bomRate': bomRate,
        'bomAmount': bomAmount,
        'bomRemarks': bomRemarks,
      };
}

/// Summary entity for BOM Show Record modal list
@immutable
class BomRecordSummary {
  final String bomId;
  final String bomCode;
  final int depCode;
  final String depName;
  final int strCode;
  final String strName;
  final String iCode;
  final String description;
  final double qty;
  final int unitCode;
  final String unitName;
  final String status; // 'OPEN' or 'BLOCKED'
  final String bomType; // 'JOB' or 'REGULAR'
  final DateTime bomDate;
  final String bomPo;
  final int subItemCount;
  final double totalConsumption;
  final double totalNetQty;

  const BomRecordSummary({
    required this.bomId,
    this.bomCode = '',
    required this.depCode,
    this.depName = '',
    required this.strCode,
    this.strName = '',
    required this.iCode,
    required this.description,
    required this.qty,
    required this.unitCode,
    this.unitName = '',
    this.status = 'OPEN',
    required this.bomType,
    required this.bomDate,
    this.bomPo = '',
    this.subItemCount = 0,
    this.totalConsumption = 0.0,
    this.totalNetQty = 0.0,
  });

  factory BomRecordSummary.fromJson(Map<String, dynamic> json) {
    return BomRecordSummary(
      bomId: (json['BOMID'] ?? json['bomId'] ?? '').toString(),
      bomCode: (json['BOMCode'] ?? json['bomCode'] ?? '').toString(),
      depCode: (json['BOM_DEPCODE'] ?? json['depCode'] ?? 0) is int
          ? (json['BOM_DEPCODE'] ?? json['depCode'] ?? 0)
          : (int.tryParse((json['BOM_DEPCODE'] ?? json['depCode'] ?? '0').toString()) ?? 0),
      depName: (json['DEP_NAME'] ?? json['depName'] ?? '').toString(),
      strCode: (json['BOM_STRCODE'] ?? json['strCode'] ?? 0) is int
          ? (json['BOM_STRCODE'] ?? json['strCode'] ?? 0)
          : (int.tryParse((json['BOM_STRCODE'] ?? json['strCode'] ?? '0').toString()) ?? 0),
      strName: (json['STR_NAME'] ?? json['strName'] ?? '').toString(),
      iCode: (json['I_Code'] ?? json['iCode'] ?? '').toString(),
      description: (json['DESCRIPTION'] ?? json['description'] ?? '').toString(),
      qty: (json['Qty'] ?? json['qty'] ?? 1.0) is num
          ? (json['Qty'] ?? json['qty'] ?? 1.0).toDouble()
          : (double.tryParse((json['Qty'] ?? json['qty'] ?? '1').toString()) ?? 1.0),
      unitCode: (json['Unit_Code'] ?? json['unitCode'] ?? 0) is int
          ? (json['Unit_Code'] ?? json['unitCode'] ?? 0)
          : (int.tryParse((json['Unit_Code'] ?? json['unitCode'] ?? '0').toString()) ?? 0),
      unitName: (json['UNIT_NAME'] ?? json['unitName'] ?? '').toString(),
      status: (json['Status'] ?? json['status'] ?? 'OPEN').toString().toUpperCase(),
      bomType: (json['Bom_Type'] ?? json['bomType'] ?? 'JOB').toString().toUpperCase(),
      bomDate: (json['Bom_Date'] ?? json['bomDate']) != null
          ? DateTime.tryParse((json['Bom_Date'] ?? json['bomDate']).toString()) ?? DateTime.now()
          : DateTime.now(),
      bomPo: (json['Bom_PO'] ?? json['bomPo'] ?? '').toString(),
      subItemCount: (json['SubItemCount'] ?? json['subItemCount'] ?? 0) is int
          ? (json['SubItemCount'] ?? json['subItemCount'] ?? 0)
          : (int.tryParse((json['SubItemCount'] ?? json['subItemCount'] ?? '0').toString()) ?? 0),
      totalConsumption: (json['TotalConsumption'] ?? json['totalConsumption'] ?? 0.0) is num
          ? (json['TotalConsumption'] ?? json['totalConsumption'] ?? 0.0).toDouble()
          : (double.tryParse((json['TotalConsumption'] ?? json['totalConsumption'] ?? '0').toString()) ?? 0.0),
      totalNetQty: (json['TotalNetQty'] ?? json['totalNetQty'] ?? 0.0) is num
          ? (json['TotalNetQty'] ?? json['totalNetQty'] ?? 0.0).toDouble()
          : (double.tryParse((json['TotalNetQty'] ?? json['totalNetQty'] ?? '0').toString()) ?? 0.0),
    );
  }

  Map<String, dynamic> toJson() => {
        'bomId': bomId,
        'bomCode': bomCode,
        'depCode': depCode,
        'depName': depName,
        'strCode': strCode,
        'strName': strName,
        'iCode': iCode,
        'description': description,
        'qty': qty,
        'unitCode': unitCode,
        'unitName': unitName,
        'status': status,
        'bomType': bomType,
        'bomDate': bomDate.toIso8601String(),
        'bomPo': bomPo,
        'subItemCount': subItemCount,
        'totalConsumption': totalConsumption,
        'totalNetQty': totalNetQty,
      };
}

/// Complete BOM Entity with Header and Sub-Items
@immutable
class BomCompleteRecord {
  final BomHeaderData header;
  final List<BomSubItemData> items;

  const BomCompleteRecord({
    required this.header,
    required this.items,
  });

  factory BomCompleteRecord.fromJson(Map<String, dynamic> json) {
    return BomCompleteRecord(
      header: BomHeaderData.fromJson(json['header'] as Map<String, dynamic>),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => BomSubItemData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'header': header.toJson(),
        'items': items.map((e) => e.toJson()).toList(),
      };
}

