class PoAdvancePartyLookup {
  final int pCode;
  final String pName;

  const PoAdvancePartyLookup({
    required this.pCode,
    required this.pName,
  });

  factory PoAdvancePartyLookup.fromJson(Map<String, dynamic> json) {
    return PoAdvancePartyLookup(
      pCode: json['pCode'] as int? ?? json['PCode'] as int? ?? 0,
      pName: (json['pName'] ?? json['PName'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'pCode': pCode,
    'pName': pName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PoAdvancePartyLookup &&
          runtimeType == other.runtimeType &&
          pCode == other.pCode &&
          pName == other.pName;

  @override
  int get hashCode => pCode.hashCode ^ pName.hashCode;
}

class PoAdvanceHeaderDetails {
  final String poNo;
  final DateTime? poDate;
  final double netAmt;
  final double totGiv;
  final double pendingAmt;
  final String suppRef;
  final String pTerms;
  final String dTerms;
  final String remark;
  final String poMode;
  final double advAgreed;

  const PoAdvanceHeaderDetails({
    required this.poNo,
    this.poDate,
    required this.netAmt,
    required this.totGiv,
    required this.pendingAmt,
    this.suppRef = '',
    this.pTerms = '',
    this.dTerms = '',
    this.remark = '',
    this.poMode = '',
    this.advAgreed = 0.0,
  });

  factory PoAdvanceHeaderDetails.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['poDate'] ?? json['PoDate'];
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString());
    }

    return PoAdvanceHeaderDetails(
      poNo: (json['poNo'] ?? json['PoNo'] ?? '').toString().trim(),
      poDate: parsedDate,
      netAmt: (json['netAmt'] ?? json['NetAmt'] as num?)?.toDouble() ?? 0.0,
      totGiv: (json['totGiv'] ?? json['TotGiv'] as num?)?.toDouble() ?? 0.0,
      pendingAmt: (json['pendingAmt'] ?? json['PendingAmt'] as num?)?.toDouble() ?? 0.0,
      suppRef: (json['suppRef'] ?? json['SuppRef'] ?? '').toString().trim(),
      pTerms: (json['pTerms'] ?? json['PTerms'] ?? '').toString().trim(),
      dTerms: (json['dTerms'] ?? json['DTerms'] ?? '').toString().trim(),
      remark: (json['remark'] ?? json['Remark'] ?? '').toString().trim(),
      poMode: (json['poMode'] ?? json['PoMode'] ?? '').toString().trim(),
      advAgreed: (json['advAgreed'] ?? json['AdvAgreed'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PoAdvanceHeaderDetails &&
          runtimeType == other.runtimeType &&
          poNo == other.poNo &&
          poDate == other.poDate &&
          netAmt == other.netAmt &&
          totGiv == other.totGiv &&
          pendingAmt == other.pendingAmt;

  @override
  int get hashCode =>
      poNo.hashCode ^
      poDate.hashCode ^
      netAmt.hashCode ^
      totGiv.hashCode ^
      pendingAmt.hashCode;
}

class PoAdvanceHistoryRecord {
  final int poId;
  final String poNo;
  final DateTime? poDate;
  final DateTime? appDt;
  final String appEMode;
  final DateTime? appMDate;
  final int partyId;
  final String partyName;
  final double appAmt;
  final double appLess;
  final double appBAmt;
  final String appRemark;
  final String appUsrName;
  final String chequeNo;

  const PoAdvanceHistoryRecord({
    required this.poId,
    required this.poNo,
    this.poDate,
    this.appDt,
    required this.appEMode,
    this.appMDate,
    this.partyId = 0,
    required this.partyName,
    required this.appAmt,
    required this.appLess,
    required this.appBAmt,
    required this.appRemark,
    this.appUsrName = '',
    required this.chequeNo,
  });

  factory PoAdvanceHistoryRecord.fromJson(Map<String, dynamic> json) {
    DateTime? poDt;
    final rawPoDt = json['poDate'] ?? json['PoDate'];
    if (rawPoDt != null) {
      poDt = DateTime.tryParse(rawPoDt.toString());
    }

    DateTime? dt;
    final rawDt = json['appDt'] ?? json['AppDt'];
    if (rawDt != null) {
      dt = DateTime.tryParse(rawDt.toString());
    }

    DateTime? mDt;
    final rawMDt = json['appMDate'] ?? json['AppMDate'];
    if (rawMDt != null) {
      mDt = DateTime.tryParse(rawMDt.toString());
    }

    return PoAdvanceHistoryRecord(
      poId: json['poId'] as int? ?? json['PoId'] as int? ?? 0,
      poNo: (json['poNo'] ?? json['PoNo'] ?? '').toString().trim(),
      poDate: poDt,
      appDt: dt,
      appEMode: (json['appEMode'] ?? json['AppEMode'] ?? '').toString().trim(),
      appMDate: mDt,
      partyId: json['partyId'] as int? ?? json['PartyId'] as int? ?? 0,
      partyName: (json['partyName'] ?? json['PartyName'] ?? '').toString().trim(),
      appAmt: (json['appAmt'] ?? json['AppAmt'] as num?)?.toDouble() ?? 0.0,
      appLess: (json['appLess'] ?? json['AppLess'] as num?)?.toDouble() ?? 0.0,
      appBAmt: (json['appBAmt'] ?? json['AppBAmt'] as num?)?.toDouble() ?? 0.0,
      appRemark: (json['appRemark'] ?? json['AppRemark'] ?? '').toString().trim(),
      appUsrName: (json['appUsrName'] ?? json['AppUsrName'] ?? '').toString().trim(),
      chequeNo: (json['chequeNo'] ?? json['ChequeNo'] ?? '').toString().trim(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PoAdvanceHistoryRecord &&
          runtimeType == other.runtimeType &&
          poId == other.poId;

  @override
  int get hashCode => poId.hashCode;
}

class PoAdvancePartySummary {
  final String poNo;
  final DateTime? poDate;
  final double appBAmt;
  final double totalAdv;

  const PoAdvancePartySummary({
    required this.poNo,
    this.poDate,
    required this.appBAmt,
    required this.totalAdv,
  });

  factory PoAdvancePartySummary.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    final rawDt = json['poDate'] ?? json['PoDate'];
    if (rawDt != null) {
      dt = DateTime.tryParse(rawDt.toString());
    }

    return PoAdvancePartySummary(
      poNo: (json['poNo'] ?? json['PoNo'] ?? '').toString().trim(),
      poDate: dt,
      appBAmt: (json['appBAmt'] ?? json['AppBAmt'] as num?)?.toDouble() ?? 0.0,
      totalAdv: (json['totalAdv'] ?? json['TotalAdv'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PoAdvancePartySummary &&
          runtimeType == other.runtimeType &&
          poNo == other.poNo;

  @override
  int get hashCode => poNo.hashCode;
}

class PoAdvanceCreatePayload {
  final String poNo;
  final int partyId;
  final DateTime appDt;
  final double appAmt;
  final double appLess;
  final String? appEMode;
  final String? chequeNo;
  final String? bankName;
  final String? appRemark;
  final DateTime? appMDate;

  const PoAdvanceCreatePayload({
    required this.poNo,
    required this.partyId,
    required this.appDt,
    required this.appAmt,
    this.appLess = 0.0,
    this.appEMode,
    this.chequeNo,
    this.bankName,
    this.appRemark,
    this.appMDate,
  });

  Map<String, dynamic> toJson() => {
    'poNo': poNo,
    'partyId': partyId,
    'appDt': appDt.toIso8601String(),
    'appAmt': appAmt,
    'appLess': appLess,
    'appEMode': appEMode,
    'chequeNo': chequeNo,
    'bankName': bankName,
    'appRemark': appRemark,
    'appMDate': appMDate?.toIso8601String(),
  };
}
