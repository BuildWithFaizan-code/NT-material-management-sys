class IndentApprovalDepartment {
  final int labCode;
  final String labName;

  const IndentApprovalDepartment({
    required this.labCode,
    required this.labName,
  });

  factory IndentApprovalDepartment.fromJson(Map<String, dynamic> json) {
    return IndentApprovalDepartment(
      labCode: json['labCode'] is int
          ? json['labCode']
          : int.tryParse(json['labCode']?.toString() ?? '0') ?? 0,
      labName: json['labName']?.toString() ?? '',
    );
  }
}

class IndentApprovalItemLookup {
  final String code;
  final String itemName;

  const IndentApprovalItemLookup({
    required this.code,
    required this.itemName,
  });

  factory IndentApprovalItemLookup.fromJson(Map<String, dynamic> json) {
    return IndentApprovalItemLookup(
      code: json['code']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
    );
  }
}

class IndentApprovalLookups {
  final List<String> indentNumbers;
  final List<IndentApprovalDepartment> departments;
  final List<IndentApprovalItemLookup> items;

  const IndentApprovalLookups({
    required this.indentNumbers,
    required this.departments,
    required this.items,
  });

  factory IndentApprovalLookups.fromJson(Map<String, dynamic> json) {
    return IndentApprovalLookups(
      indentNumbers: (json['indentNumbers'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      departments: (json['departments'] as List<dynamic>? ?? [])
          .map((e) => IndentApprovalDepartment.fromJson(e as Map<String, dynamic>))
          .toList(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => IndentApprovalItemLookup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class IndentApprovalRecord {
  final bool isAppro;
  final String indCode;
  final DateTime indDate;
  final String labName;
  final String code;
  final String itName;
  final double qty;
  final double rate;
  final double totalValue;
  final int inddetCode;
  final bool isReject;
  final bool isHold;
  final String reqNo;
  final String processDo;
  final String status;

  const IndentApprovalRecord({
    required this.isAppro,
    required this.indCode,
    required this.indDate,
    required this.labName,
    required this.code,
    required this.itName,
    required this.qty,
    required this.rate,
    required this.totalValue,
    required this.inddetCode,
    required this.isReject,
    required this.isHold,
    required this.reqNo,
    required this.processDo,
    required this.status,
  });

  factory IndentApprovalRecord.fromJson(Map<String, dynamic> json) {
    final isAppro = json['isAppro'] == true;
    final isReject = json['isReject'] == true;
    final isHold = json['isHold'] == true;

    String calculatedStatus;
    if (isAppro) {
      calculatedStatus = 'APPROVED';
    } else if (isReject) {
      calculatedStatus = 'REJECTED';
    } else if (isHold) {
      calculatedStatus = 'HOLD';
    } else {
      calculatedStatus = 'PENDING';
    }

    return IndentApprovalRecord(
      isAppro: isAppro,
      indCode: json['indCode']?.toString() ?? '',
      indDate: DateTime.tryParse(json['indDate']?.toString() ?? '') ?? DateTime.now(),
      labName: json['labName']?.toString() ?? 'GENERAL',
      code: json['code']?.toString() ?? '',
      itName: json['itName']?.toString() ?? '',
      qty: (json['qty'] is num) ? (json['qty'] as num).toDouble() : double.tryParse(json['qty']?.toString() ?? '0') ?? 0.0,
      rate: (json['rate'] is num) ? (json['rate'] as num).toDouble() : double.tryParse(json['rate']?.toString() ?? '0') ?? 0.0,
      totalValue: (json['totalValue'] is num) ? (json['totalValue'] as num).toDouble() : double.tryParse(json['totalValue']?.toString() ?? '0') ?? 0.0,
      inddetCode: json['inddetCode'] is int ? json['inddetCode'] : int.tryParse(json['inddetCode']?.toString() ?? '0') ?? 0,
      isReject: isReject,
      isHold: isHold,
      reqNo: json['reqNo']?.toString() ?? '',
      processDo: json['processDo']?.toString() ?? '',
      status: json['status']?.toString() ?? calculatedStatus,
    );
  }

  String get uniqueId => '$indCode-$code-$inddetCode';
}

class IndentApprovalItemSelection {
  final String indCode;
  final String code;
  final int inddetCode;
  final String departmentName;

  const IndentApprovalItemSelection({
    required this.indCode,
    required this.code,
    required this.inddetCode,
    required this.departmentName,
  });

  Map<String, dynamic> toJson() => {
    'indCode': indCode,
    'code': code,
    'inddetCode': inddetCode,
    'departmentName': departmentName,
  };
}

class IndentApprovalActionPayload {
  final String action; // APPROVE, REJECT, HOLD, RESET
  final DateTime approvalDate;
  final List<IndentApprovalItemSelection> items;

  const IndentApprovalActionPayload({
    required this.action,
    required this.approvalDate,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'action': action,
    'approvalDate': approvalDate.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class IndentApprovalActionResult {
  final bool success;
  final String message;
  final int affectedCount;

  const IndentApprovalActionResult({
    required this.success,
    required this.message,
    required this.affectedCount,
  });

  factory IndentApprovalActionResult.fromJson(Map<String, dynamic> json) {
    return IndentApprovalActionResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      affectedCount: json['affectedCount'] is int
          ? json['affectedCount']
          : int.tryParse(json['affectedCount']?.toString() ?? '0') ?? 0,
    );
  }
}
