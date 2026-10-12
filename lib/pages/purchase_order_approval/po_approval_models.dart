import 'package:flutter/foundation.dart';

@immutable
class PoApprovalDepartment {
  final int labCode;
  final String labName;

  const PoApprovalDepartment({required this.labCode, required this.labName});

  factory PoApprovalDepartment.fromJson(Map<String, dynamic> json) {
    return PoApprovalDepartment(
      labCode: (json['labCode'] ?? 0) as int,
      labName: (json['labName'] ?? '').toString(),
    );
  }
}

@immutable
class PoApprovalPlant {
  final int strCode;
  final String strName;

  const PoApprovalPlant({required this.strCode, required this.strName});

  factory PoApprovalPlant.fromJson(Map<String, dynamic> json) {
    return PoApprovalPlant(
      strCode: (json['strCode'] ?? 0) as int,
      strName: (json['strName'] ?? '').toString(),
    );
  }
}

@immutable
class PoApprovalSupplier {
  final int pCode;
  final String pName;

  const PoApprovalSupplier({required this.pCode, required this.pName});

  factory PoApprovalSupplier.fromJson(Map<String, dynamic> json) {
    return PoApprovalSupplier(
      pCode: (json['pCode'] ?? 0) as int,
      pName: (json['pName'] ?? '').toString(),
    );
  }
}

@immutable
class PoApprovalLookupsData {
  final List<PoApprovalDepartment> departments;
  final List<PoApprovalPlant> plants;
  final List<PoApprovalSupplier> suppliers;

  const PoApprovalLookupsData({
    this.departments = const [],
    this.plants = const [],
    this.suppliers = const [],
  });

  factory PoApprovalLookupsData.fromJson(Map<String, dynamic> json) {
    return PoApprovalLookupsData(
      departments: (json['departments'] as List?)
              ?.map((e) => PoApprovalDepartment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      plants: (json['plants'] as List?)
              ?.map((e) => PoApprovalPlant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      suppliers: (json['suppliers'] as List?)
              ?.map((e) => PoApprovalSupplier.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

@immutable
class PoApprovalRecord {
  final String purOrdNo;
  final DateTime poDate;
  final String refNo;
  final DateTime? refDate;
  final String department;
  final int deptCode;
  final String plant;
  final int plantCode;
  final String partyName;
  final int partyCode;
  final String itCode;
  final String itemName;
  final String shade;
  final double poQty;
  final double inwardQty;
  final double balanceQty;
  final double rate;
  final double amount;
  final double freight;
  final int pId;
  final int isAppro;
  final int isReject;
  final int isHold;
  final int closePo;
  final String indCode;
  final String podClosRem;
  final String? processDo;
  final String status;

  const PoApprovalRecord({
    required this.purOrdNo,
    required this.poDate,
    required this.refNo,
    this.refDate,
    required this.department,
    required this.deptCode,
    required this.plant,
    required this.plantCode,
    required this.partyName,
    required this.partyCode,
    required this.itCode,
    required this.itemName,
    required this.shade,
    required this.poQty,
    required this.inwardQty,
    required this.balanceQty,
    required this.rate,
    required this.amount,
    required this.freight,
    required this.pId,
    required this.isAppro,
    required this.isReject,
    required this.isHold,
    required this.closePo,
    required this.indCode,
    required this.podClosRem,
    this.processDo,
    required this.status,
  });

  bool get isApproved => isAppro != 0;
  bool get isRejected => isReject != 0;
  bool get isHeld => isHold != 0;
  bool get isClosed => closePo != 0;
  bool get isPending => !isApproved && !isRejected && !isHeld && !isClosed;

  /// Unique composite identifier for selection and tracking: PO_NO + P_ID
  String get rowKey => '$purOrdNo#$pId';

  factory PoApprovalRecord.fromJson(Map<String, dynamic> json) {
    return PoApprovalRecord(
      purOrdNo: (json['purOrdNo'] ?? '').toString(),
      poDate: json['poDate'] != null
          ? DateTime.tryParse(json['poDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      refNo: (json['refNo'] ?? '').toString(),
      refDate: json['refDate'] != null
          ? DateTime.tryParse(json['refDate'].toString())
          : null,
      department: (json['department'] ?? '').toString(),
      deptCode: (json['deptCode'] ?? 0) as int,
      plant: (json['plant'] ?? '').toString(),
      plantCode: (json['plantCode'] ?? 0) as int,
      partyName: (json['partyName'] ?? '').toString(),
      partyCode: (json['partyCode'] ?? 0) as int,
      itCode: (json['itCode'] ?? '').toString(),
      itemName: (json['itemName'] ?? '').toString(),
      shade: (json['shade'] ?? '').toString(),
      poQty: (json['poQty'] as num?)?.toDouble() ?? 0.0,
      inwardQty: (json['inwardQty'] as num?)?.toDouble() ?? 0.0,
      balanceQty: (json['balanceQty'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      freight: (json['freight'] as num?)?.toDouble() ?? 0.0,
      pId: (json['pId'] ?? 0) as int,
      isAppro: (json['isAppro'] ?? 0) as int,
      isReject: (json['isReject'] ?? 0) as int,
      isHold: (json['isHold'] ?? 0) as int,
      closePo: (json['closePo'] ?? 0) as int,
      indCode: (json['indCode'] ?? '').toString(),
      podClosRem: (json['podClosRem'] ?? '').toString(),
      processDo: json['processDo']?.toString(),
      status: (json['status'] ?? 'Pending').toString(),
    );
  }
}

class PoApprovalActionItemPayload {
  final String poNo;
  final int pId;
  final String? departmentName;

  const PoApprovalActionItemPayload({
    required this.poNo,
    required this.pId,
    this.departmentName,
  });

  Map<String, dynamic> toJson() => {
        'poNo': poNo,
        'pId': pId,
        'departmentName': departmentName,
      };
}
