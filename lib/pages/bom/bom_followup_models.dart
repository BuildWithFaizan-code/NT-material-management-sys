import 'package:flutter/foundation.dart';

/// Department lookup entity for BOM Follow Up filter (from LABOURMST)
@immutable
class BomFollowupDepartment {
  final int labCode;
  final String labName;

  const BomFollowupDepartment({
    required this.labCode,
    required this.labName,
  });

  factory BomFollowupDepartment.fromJson(Map<String, dynamic> json) {
    return BomFollowupDepartment(
      labCode: (json['labCode'] ?? json['LAB_CODE'] ?? 0) is int
          ? (json['labCode'] ?? json['LAB_CODE'] ?? 0)
          : (int.tryParse((json['labCode'] ?? json['LAB_CODE'] ?? '0').toString()) ?? 0),
      labName: (json['labName'] ?? json['LAB_NAME'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'labCode': labCode,
        'labName': labName,
      };
}

/// Division lookup entity for BOM Follow Up filter (from KHATAMST)
@immutable
class BomFollowupDivision {
  final int khCode;
  final String khName;

  const BomFollowupDivision({
    required this.khCode,
    required this.khName,
  });

  factory BomFollowupDivision.fromJson(Map<String, dynamic> json) {
    return BomFollowupDivision(
      khCode: (json['khCode'] ?? json['KH_CODE'] ?? 0) is int
          ? (json['khCode'] ?? json['KH_CODE'] ?? 0)
          : (int.tryParse((json['khCode'] ?? json['KH_CODE'] ?? '0').toString()) ?? 0),
      khName: (json['khName'] ?? json['KH_NAME'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'khCode': khCode,
        'khName': khName,
      };
}

/// Order Type lookup entity for BOM Follow Up filter (from BOMMST [PURPOSE]='COSTING')
@immutable
class BomFollowupOrderType {
  final String bomType;

  const BomFollowupOrderType({
    required this.bomType,
  });

  factory BomFollowupOrderType.fromJson(Map<String, dynamic> json) {
    return BomFollowupOrderType(
      bomType: (json['bomType'] ?? json['BOM_TYPE'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'bomType': bomType,
      };
}

/// Main Grid Record Model for BOM Follow Up / Bill of Material Close Screen
/// Exactly matches verified SQL query columns:
/// [BOM ID], [DATE], [DEPARTMENT], [BRANCH], [DIVISION], [MATERIAL NAME], [MATERIAL CODE],
/// [MERGE_NO], [QTY], [STOCK], [STATUS], [DT & TIME], [USER], [RATE], [UQC], [UCODE]
@immutable
class BomFollowupRecord {
  final String bomId;
  final DateTime bomDate;
  final int labCode;
  final String department;
  final int strCode;
  final String branch;
  final int khCode;
  final String division;
  final String materialName;
  final String materialCode;
  final String mergeNo;
  final double qty;
  final double stock;
  final String status;
  final DateTime? dtAndTime;
  final String user;
  final double rate;
  final String uqc;
  final int ucode;

  const BomFollowupRecord({
    required this.bomId,
    required this.bomDate,
    required this.labCode,
    required this.department,
    required this.strCode,
    required this.branch,
    required this.khCode,
    required this.division,
    required this.materialName,
    required this.materialCode,
    this.mergeNo = '',
    required this.qty,
    required this.stock,
    this.status = 'OPEN',
    this.dtAndTime,
    required this.user,
    required this.rate,
    required this.uqc,
    required this.ucode,
  });

  factory BomFollowupRecord.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? 0;
    }

    return BomFollowupRecord(
      bomId: (json['bomId'] ?? json['BOM ID'] ?? json['BOMID'] ?? '').toString(),
      bomDate: parseDate(json['bomDate'] ?? json['DATE'] ?? json['BOM_DATE']),
      labCode: parseInt(json['labCode'] ?? json['LAB_CODE']),
      department: (json['department'] ?? json['DEPARTMENT'] ?? json['LAB_NAME'] ?? '').toString(),
      strCode: parseInt(json['strCode'] ?? json['STR_CODE']),
      branch: (json['branch'] ?? json['BRANCH'] ?? json['STR_NAME'] ?? '').toString(),
      khCode: parseInt(json['khCode'] ?? json['KH_CODE']),
      division: (json['division'] ?? json['DIVISION'] ?? json['KH_NAME'] ?? '').toString(),
      materialName: (json['materialName'] ?? json['MATERIAL NAME'] ?? json['DESCRIPTION'] ?? '').toString(),
      materialCode: (json['materialCode'] ?? json['MATERIAL CODE'] ?? json['I_CODE'] ?? '').toString(),
      mergeNo: (json['mergeNo'] ?? json['MERGE_NO'] ?? '').toString(),
      qty: parseDouble(json['qty'] ?? json['QTY']),
      stock: parseDouble(json['stock'] ?? json['STOCK']),
      status: (json['status'] ?? json['STATUS'] ?? 'OPEN').toString(),
      dtAndTime: json['dtAndTime'] != null || json['DT & TIME'] != null || json['BOM_EDATE'] != null
          ? parseDate(json['dtAndTime'] ?? json['DT & TIME'] ?? json['BOM_EDATE'])
          : null,
      user: (json['user'] ?? json['USER'] ?? json['BOM_USRNAME'] ?? '').toString(),
      rate: parseDouble(json['rate'] ?? json['RATE'] ?? json['BOM_COST']),
      uqc: (json['uqc'] ?? json['UQC'] ?? json['UNIT_NAME'] ?? '').toString(),
      ucode: parseInt(json['ucode'] ?? json['UCODE'] ?? json['UNIT_CODE']),
    );
  }

  Map<String, dynamic> toJson() => {
        'bomId': bomId,
        'bomDate': bomDate.toIso8601String(),
        'labCode': labCode,
        'department': department,
        'strCode': strCode,
        'branch': branch,
        'khCode': khCode,
        'division': division,
        'materialName': materialName,
        'materialCode': materialCode,
        'mergeNo': mergeNo,
        'qty': qty,
        'stock': stock,
        'status': status,
        'dtAndTime': dtAndTime?.toIso8601String(),
        'user': user,
        'rate': rate,
        'uqc': uqc,
        'ucode': ucode,
      };

  BomFollowupRecord copyWith({
    String? bomId,
    DateTime? bomDate,
    int? labCode,
    String? department,
    int? strCode,
    String? branch,
    int? khCode,
    String? division,
    String? materialName,
    String? materialCode,
    String? mergeNo,
    double? qty,
    double? stock,
    String? status,
    DateTime? dtAndTime,
    String? user,
    double? rate,
    String? uqc,
    int? ucode,
  }) {
    return BomFollowupRecord(
      bomId: bomId ?? this.bomId,
      bomDate: bomDate ?? this.bomDate,
      labCode: labCode ?? this.labCode,
      department: department ?? this.department,
      strCode: strCode ?? this.strCode,
      branch: branch ?? this.branch,
      khCode: khCode ?? this.khCode,
      division: division ?? this.division,
      materialName: materialName ?? this.materialName,
      materialCode: materialCode ?? this.materialCode,
      mergeNo: mergeNo ?? this.mergeNo,
      qty: qty ?? this.qty,
      stock: stock ?? this.stock,
      status: status ?? this.status,
      dtAndTime: dtAndTime ?? this.dtAndTime,
      user: user ?? this.user,
      rate: rate ?? this.rate,
      uqc: uqc ?? this.uqc,
      ucode: ucode ?? this.ucode,
    );
  }
}

/// Result of a batch close operation
@immutable
class BomFollowupCloseResult {
  final bool success;
  final int closedCount;
  final String message;
  final bool isDateLocked;

  const BomFollowupCloseResult({
    required this.success,
    this.closedCount = 0,
    required this.message,
    this.isDateLocked = false,
  });

  factory BomFollowupCloseResult.fromJson(Map<String, dynamic> json) {
    return BomFollowupCloseResult(
      success: json['success'] == true,
      closedCount: (json['closedCount'] ?? 0) is int
          ? (json['closedCount'] ?? 0)
          : (int.tryParse((json['closedCount'] ?? '0').toString()) ?? 0),
      message: (json['message'] ?? '').toString(),
      isDateLocked: json['isDateLocked'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'closedCount': closedCount,
        'message': message,
        'isDateLocked': isDateLocked,
      };
}
