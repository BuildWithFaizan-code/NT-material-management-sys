import 'package:flutter/foundation.dart';

@immutable
class SoApprovalDepartment {
  final int labCode;
  final String labName;

  const SoApprovalDepartment({required this.labCode, required this.labName});

  factory SoApprovalDepartment.fromJson(Map<String, dynamic> json) {
    return SoApprovalDepartment(
      labCode: (json['labCode'] ?? 0) as int,
      labName: (json['labName'] ?? '').toString(),
    );
  }
}

@immutable
class SoApprovalCustomer {
  final int pCode;
  final String pName;

  const SoApprovalCustomer({required this.pCode, required this.pName});

  factory SoApprovalCustomer.fromJson(Map<String, dynamic> json) {
    return SoApprovalCustomer(
      pCode: (json['pCode'] ?? 0) as int,
      pName: (json['pName'] ?? '').toString(),
    );
  }
}

@immutable
class SoApprovalItemLookup {
  final String itCode;
  final String itemName;

  const SoApprovalItemLookup({required this.itCode, required this.itemName});

  factory SoApprovalItemLookup.fromJson(Map<String, dynamic> json) {
    return SoApprovalItemLookup(
      itCode: (json['itCode'] ?? '').toString(),
      itemName: (json['itemName'] ?? '').toString(),
    );
  }
}

@immutable
class SoApprovalLookupsData {
  final List<SoApprovalDepartment> departments;
  final List<SoApprovalCustomer> customers;
  final List<String> orderNumbers;
  final List<SoApprovalItemLookup> items;

  const SoApprovalLookupsData({
    this.departments = const [],
    this.customers = const [],
    this.orderNumbers = const [],
    this.items = const [],
  });

  factory SoApprovalLookupsData.fromJson(Map<String, dynamic> json) {
    return SoApprovalLookupsData(
      departments: (json['departments'] as List?)
              ?.map((e) => SoApprovalDepartment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      customers: (json['customers'] as List?)
              ?.map((e) => SoApprovalCustomer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      orderNumbers: (json['orderNumbers'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      items: (json['items'] as List?)
              ?.map((e) => SoApprovalItemLookup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

@immutable
class SoApprovalRecord {
  final String salOrdNo;
  final DateTime soDate;
  final String labName;
  final int deptCode;
  final String partyName;
  final int partyCode;
  final String itCode;
  final String itemName;
  final double qty;
  final double rate;
  final double amount;
  final int sId;
  final int isAppro;
  final int isReject;
  final int isHold;
  final int closeSo;
  final int isRec;
  final String indCode;
  final String sodClosRem;
  final int processDo;
  final String cellNo;
  final String status;

  const SoApprovalRecord({
    required this.salOrdNo,
    required this.soDate,
    required this.labName,
    required this.deptCode,
    required this.partyName,
    required this.partyCode,
    required this.itCode,
    required this.itemName,
    required this.qty,
    required this.rate,
    required this.amount,
    required this.sId,
    required this.isAppro,
    required this.isReject,
    required this.isHold,
    required this.closeSo,
    required this.isRec,
    required this.indCode,
    required this.sodClosRem,
    required this.processDo,
    required this.cellNo,
    required this.status,
  });

  bool get isApproved => isAppro != 0;
  bool get isRejected => isReject != 0;
  bool get isOnHold => isHold != 0;
  bool get isClosed => closeSo != 0;
  bool get isDelivered => isRec != 0;

  String get rowKey => '$salOrdNo-$sId';

  factory SoApprovalRecord.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    double parseNum(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final close = parseInt(json['closeSo']);
    final rej = parseInt(json['isReject']);
    final hold = parseInt(json['isHold']);
    final appr = parseInt(json['isAppro']);

    String computedStatus = 'Pending';
    if (close != 0) {
      computedStatus = 'Closed';
    } else if (rej != 0) {
      computedStatus = 'Rejected';
    } else if (hold != 0) {
      computedStatus = 'Hold';
    } else if (appr != 0) {
      computedStatus = 'Approved';
    }

    return SoApprovalRecord(
      salOrdNo: (json['salOrdNo'] ?? '').toString(),
      soDate: parseDate(json['soDate']),
      labName: (json['labName'] ?? '').toString(),
      deptCode: parseInt(json['deptCode']),
      partyName: (json['partyName'] ?? '').toString(),
      partyCode: parseInt(json['partyCode']),
      itCode: (json['itCode'] ?? '').toString(),
      itemName: (json['itemName'] ?? '').toString(),
      qty: parseNum(json['qty']),
      rate: parseNum(json['rate']),
      amount: parseNum(json['amount']),
      sId: parseInt(json['sId']),
      isAppro: appr,
      isReject: rej,
      isHold: hold,
      closeSo: close,
      isRec: parseInt(json['isRec']),
      indCode: (json['indCode'] ?? '').toString(),
      sodClosRem: (json['sodClosRem'] ?? '').toString(),
      processDo: parseInt(json['processDo']),
      cellNo: (json['cellNo'] ?? '').toString(),
      status: (json['status'] ?? computedStatus).toString(),
    );
  }
}

class SoApprovalActionItemPayload {
  final String soNo;
  final int sId;
  final String? itemCode;
  final String? departmentName;

  const SoApprovalActionItemPayload({
    required this.soNo,
    required this.sId,
    this.itemCode,
    this.departmentName,
  });

  Map<String, dynamic> toJson() => {
        'soNo': soNo,
        'sId': sId,
        'itemCode': itemCode ?? '',
        'departmentName': departmentName ?? '',
      };
}
