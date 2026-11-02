class IssueManagerLookupItem {
  final int id;
  final String code;
  final String name;

  const IssueManagerLookupItem({
    required this.id,
    required this.code,
    required this.name,
  });

  factory IssueManagerLookupItem.fromJson(Map<String, dynamic> json) {
    return IssueManagerLookupItem(
      id: json['id'] as int? ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
      };
}

class IssueManagerLookups {
  final List<IssueManagerLookupItem> departments;
  final List<IssueManagerLookupItem> stores;
  final List<IssueManagerLookupItem> divisions;
  final List<String> machines;
  final List<String> issueModes;
  final List<String> issueSources;

  const IssueManagerLookups({
    required this.departments,
    required this.stores,
    required this.divisions,
    required this.machines,
    required this.issueModes,
    required this.issueSources,
  });

  factory IssueManagerLookups.fromJson(Map<String, dynamic> json) {
    return IssueManagerLookups(
      departments: (json['departments'] as List<dynamic>? ?? [])
          .map((e) => IssueManagerLookupItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      stores: (json['stores'] as List<dynamic>? ?? [])
          .map((e) => IssueManagerLookupItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      divisions: (json['divisions'] as List<dynamic>? ?? [])
          .map((e) => IssueManagerLookupItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      machines: (json['machines'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      issueModes: (json['issueModes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      issueSources: (json['issueSources'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class IssueManagerLineItem {
  int srNo;
  String itemCode;
  String itemName;
  int uom;
  String unitName;
  String mrgNo;
  String grade;
  String shade;
  String maker;
  double rate;
  double stock;
  double issPcs;
  double issueQty;
  String remark;

  IssueManagerLineItem({
    required this.srNo,
    required this.itemCode,
    required this.itemName,
    required this.uom,
    required this.unitName,
    required this.mrgNo,
    required this.grade,
    required this.shade,
    required this.maker,
    required this.rate,
    required this.stock,
    required this.issPcs,
    required this.issueQty,
    required this.remark,
  });

  double get amount => issueQty * rate;

  Map<String, dynamic> toJson() => {
        'srNo': srNo,
        'itemCode': itemCode,
        'itemName': itemName,
        'uom': uom,
        'unitName': unitName,
        'mrgNo': mrgNo,
        'grade': grade,
        'shade': shade,
        'maker': maker,
        'rate': rate,
        'stock': stock,
        'issPcs': issPcs,
        'issueQty': issueQty,
        'remark': remark,
      };

  factory IssueManagerLineItem.fromJson(Map<String, dynamic> json) {
    return IssueManagerLineItem(
      srNo: json['srNo'] as int? ?? 0,
      itemCode: json['itemCode']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      uom: json['uom'] as int? ?? 0,
      unitName: json['unitName']?.toString() ?? '',
      mrgNo: json['mrgNo']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      shade: json['shade']?.toString() ?? '',
      maker: json['maker']?.toString() ?? '',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
      issPcs: (json['issPcs'] as num?)?.toDouble() ?? 0.0,
      issueQty: (json['issueQty'] as num?)?.toDouble() ?? 0.0,
      remark: json['remark']?.toString() ?? '',
    );
  }

  IssueManagerLineItem copyWith({
    int? srNo,
    String? itemCode,
    String? itemName,
    int? uom,
    String? unitName,
    String? mrgNo,
    String? grade,
    String? shade,
    String? maker,
    double? rate,
    double? stock,
    double? issPcs,
    double? issueQty,
    String? remark,
  }) {
    return IssueManagerLineItem(
      srNo: srNo ?? this.srNo,
      itemCode: itemCode ?? this.itemCode,
      itemName: itemName ?? this.itemName,
      uom: uom ?? this.uom,
      unitName: unitName ?? this.unitName,
      mrgNo: mrgNo ?? this.mrgNo,
      grade: grade ?? this.grade,
      shade: shade ?? this.shade,
      maker: maker ?? this.maker,
      rate: rate ?? this.rate,
      stock: stock ?? this.stock,
      issPcs: issPcs ?? this.issPcs,
      issueQty: issueQty ?? this.issueQty,
      remark: remark ?? this.remark,
    );
  }
}

class IssueManagerCreateRequest {
  final DateTime issueDate;
  final String issueMode;
  final String issueSource;
  final int sourceDeptCode;
  final String sourceDeptName;
  final int sourceStoreId;
  final int sourceDivId;
  final String? machineNo;
  final String? spindal;
  final int slipNo;
  final String? jobCard;
  final String? vehicleNo;
  final String? ewayBillNo;
  final String? remark;
  final List<IssueManagerLineItem> lines;

  IssueManagerCreateRequest({
    required this.issueDate,
    this.issueMode = 'To Department',
    this.issueSource = 'Direct',
    required this.sourceDeptCode,
    required this.sourceDeptName,
    required this.sourceStoreId,
    required this.sourceDivId,
    this.machineNo,
    this.spindal,
    this.slipNo = 0,
    this.jobCard,
    this.vehicleNo,
    this.ewayBillNo,
    this.remark,
    required this.lines,
  });

  Map<String, dynamic> toJson() => {
        'issueDate': issueDate.toIso8601String(),
        'issueMode': issueMode,
        'issueSource': issueSource,
        'sourceDeptCode': sourceDeptCode,
        'sourceDeptName': sourceDeptName,
        'sourceStoreId': sourceStoreId,
        'sourceDivId': sourceDivId,
        'machineNo': machineNo,
        'spindal': spindal,
        'slipNo': slipNo,
        'jobCard': jobCard,
        'vehicleNo': vehicleNo,
        'ewayBillNo': ewayBillNo,
        'remark': remark,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
}

class IssueManagerGridRecord {
  final String issueCode;
  final DateTime issueDate;
  final String issueMode;
  final String issueSource;
  final int sourceDeptCode;
  final String sourceDeptName;
  final int sourceStoreId;
  final String sourceStoreName;
  final int sourceDivId;
  final String machineNo;
  final String spindal;
  final int slipNo;
  final double totQty;
  final int totItm;
  final double totPcs;
  final String remark;
  final String createdBy;
  final DateTime? createdDate;

  const IssueManagerGridRecord({
    required this.issueCode,
    required this.issueDate,
    required this.issueMode,
    required this.issueSource,
    this.sourceDeptCode = 0,
    required this.sourceDeptName,
    this.sourceStoreId = 0,
    required this.sourceStoreName,
    this.sourceDivId = 0,
    this.machineNo = '',
    this.spindal = '',
    this.slipNo = 0,
    required this.totQty,
    required this.totItm,
    required this.totPcs,
    required this.remark,
    required this.createdBy,
    this.createdDate,
  });

  factory IssueManagerGridRecord.fromJson(Map<String, dynamic> json) {
    return IssueManagerGridRecord(
      issueCode: json['issueCode']?.toString() ?? '',
      issueDate: json['issueDate'] != null
          ? DateTime.tryParse(json['issueDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      issueMode: json['issueMode']?.toString() ?? '',
      issueSource: json['issueSource']?.toString() ?? '',
      sourceDeptCode: json['sourceDeptCode'] as int? ?? 0,
      sourceDeptName: json['sourceDeptName']?.toString() ?? '',
      sourceStoreId: json['sourceStoreId'] as int? ?? 0,
      sourceStoreName: json['sourceStoreName']?.toString() ?? '',
      sourceDivId: json['sourceDivId'] as int? ?? 0,
      machineNo: json['machineNo']?.toString() ?? '',
      spindal: json['spindal']?.toString() ?? '',
      slipNo: json['slipNo'] as int? ?? 0,
      totQty: (json['totQty'] as num?)?.toDouble() ?? 0.0,
      totItm: json['totItm'] as int? ?? 0,
      totPcs: (json['totPcs'] as num?)?.toDouble() ?? 0.0,
      remark: json['remark']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      createdDate: json['createdDate'] != null
          ? DateTime.tryParse(json['createdDate'].toString())
          : null,
    );
  }
}

class IssueManagerPagedList {
  final List<IssueManagerGridRecord> records;
  final int totalCount;

  const IssueManagerPagedList({
    required this.records,
    required this.totalCount,
  });

  factory IssueManagerPagedList.fromJson(Map<String, dynamic> json) {
    return IssueManagerPagedList(
      records: (json['records'] as List<dynamic>? ?? [])
          .map((e) => IssueManagerGridRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }
}

class IssueManagerDetail {
  final IssueManagerGridRecord header;
  final List<IssueManagerLineItem> lines;

  const IssueManagerDetail({
    required this.header,
    required this.lines,
  });

  factory IssueManagerDetail.fromJson(Map<String, dynamic> json) {
    return IssueManagerDetail(
      header: IssueManagerGridRecord.fromJson(json['header'] as Map<String, dynamic>? ?? {}),
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((e) => IssueManagerLineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class IssueManagerSaveResult {
  final String issueCode;
  final bool success;
  final String message;

  const IssueManagerSaveResult({
    required this.issueCode,
    required this.success,
    required this.message,
  });

  factory IssueManagerSaveResult.fromJson(Map<String, dynamic> json) {
    return IssueManagerSaveResult(
      issueCode: json['issueCode']?.toString() ?? '',
      success: json['success'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
    );
  }
}
