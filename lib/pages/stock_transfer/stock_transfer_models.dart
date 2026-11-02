class StockTransferLookupItem {
  final int id;
  final String code;
  final String name;

  const StockTransferLookupItem({
    required this.id,
    required this.code,
    required this.name,
  });

  factory StockTransferLookupItem.fromJson(Map<String, dynamic> json) {
    return StockTransferLookupItem(
      id: json['id'] as int? ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class StockTransferLookups {
  final List<StockTransferLookupItem> departments;
  final List<StockTransferLookupItem> stores;
  final List<StockTransferLookupItem> divisions;
  final List<StockTransferLookupItem> plants;
  final List<String> issueModes;
  final String nextDocNo;

  const StockTransferLookups({
    required this.departments,
    required this.stores,
    required this.divisions,
    required this.plants,
    this.issueModes = const ['Stock Transfer', 'To Department', 'To WIP'],
    this.nextDocNo = '',
  });

  factory StockTransferLookups.fromJson(Map<String, dynamic> json) {
    return StockTransferLookups(
      departments: (json['departments'] as List<dynamic>? ?? [])
          .map((e) => StockTransferLookupItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      stores: (json['stores'] as List<dynamic>? ?? [])
          .map((e) => StockTransferLookupItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      divisions: (json['divisions'] as List<dynamic>? ?? [])
          .map((e) => StockTransferLookupItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      plants: (json['plants'] as List<dynamic>? ?? [])
          .map((e) => StockTransferLookupItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      issueModes: (json['issueModes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      nextDocNo: json['nextDocNo']?.toString() ?? '',
    );
  }
}

class StockCatalogItem {
  final String itemCode;
  final String itemName;
  final String mrgNo;
  final String grade;
  final String shade;
  final String maker;
  final int unitCode;
  final String unitName;
  final double pcs;
  final double rate;
  final double stock;
  final String iBlock;
  final String simBin;
  final double meter;
  final String matType;

  const StockCatalogItem({
    required this.itemCode,
    required this.itemName,
    required this.mrgNo,
    required this.grade,
    required this.shade,
    required this.maker,
    required this.unitCode,
    required this.unitName,
    required this.pcs,
    required this.rate,
    required this.stock,
    required this.iBlock,
    required this.simBin,
    required this.meter,
    required this.matType,
  });

  factory StockCatalogItem.fromJson(Map<String, dynamic> json) {
    return StockCatalogItem(
      itemCode: json['itemCode']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      mrgNo: json['mrgNo']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      shade: json['shade']?.toString() ?? '',
      maker: json['maker']?.toString() ?? '',
      unitCode: json['unitCode'] as int? ?? 0,
      unitName: json['unitName']?.toString() ?? '',
      pcs: (json['pcs'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
      iBlock: json['iBlock']?.toString() ?? '',
      simBin: json['simBin']?.toString() ?? '',
      meter: (json['meter'] as num?)?.toDouble() ?? 0.0,
      matType: json['matType']?.toString() ?? '',
    );
  }
}

class StockCatalogPagedResult {
  final List<StockCatalogItem> items;
  final int totalCount;

  const StockCatalogPagedResult({
    required this.items,
    required this.totalCount,
  });

  factory StockCatalogPagedResult.fromJson(Map<String, dynamic> json) {
    return StockCatalogPagedResult(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => StockCatalogItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }
}

class PendingRequisitionItem {
  final String reqCode;
  final DateTime reqDate;
  final String itemCode;
  final String itemName;
  final int uom;
  final String unitName;
  final double reqQty;
  final double balQty;
  final double rate;
  final String mrgNo;
  final String grade;
  final String shade;

  const PendingRequisitionItem({
    required this.reqCode,
    required this.reqDate,
    required this.itemCode,
    required this.itemName,
    required this.uom,
    required this.unitName,
    required this.reqQty,
    required this.balQty,
    required this.rate,
    required this.mrgNo,
    required this.grade,
    required this.shade,
  });

  factory PendingRequisitionItem.fromJson(Map<String, dynamic> json) {
    return PendingRequisitionItem(
      reqCode: json['reqCode']?.toString() ?? '',
      reqDate: json['reqDate'] != null
          ? DateTime.tryParse(json['reqDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      itemCode: json['itemCode']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      uom: json['uom'] as int? ?? 0,
      unitName: json['unitName']?.toString() ?? '',
      reqQty: (json['reqQty'] as num?)?.toDouble() ?? 0.0,
      balQty: (json['balQty'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      mrgNo: json['mrgNo']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      shade: json['shade']?.toString() ?? '',
    );
  }
}

class StockTransferLineItem {
  int srNo;
  String reqCode;
  double reqQty;
  String itemCode;
  String itemName;
  int toDeptCode;
  String toDeptName;
  int toStoreId;
  String toStoreName;
  int toCostId;
  String toCostName;
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
  String binNo;
  String remark;

  StockTransferLineItem({
    required this.srNo,
    this.reqCode = 'None',
    this.reqQty = 0.0,
    required this.itemCode,
    required this.itemName,
    required this.toDeptCode,
    required this.toDeptName,
    required this.toStoreId,
    required this.toStoreName,
    required this.toCostId,
    required this.toCostName,
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
    required this.binNo,
    required this.remark,
  });

  Map<String, dynamic> toJson() => {
        'srNo': srNo,
        'reqCode': reqCode,
        'reqQty': reqQty,
        'itemCode': itemCode,
        'itemName': itemName,
        'toDeptCode': toDeptCode,
        'toDeptName': toDeptName,
        'toStoreId': toStoreId,
        'toStoreName': toStoreName,
        'toCostId': toCostId,
        'toCostName': toCostName,
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
        'binNo': binNo,
        'remark': remark,
      };

  factory StockTransferLineItem.fromJson(Map<String, dynamic> json) {
    return StockTransferLineItem(
      srNo: json['srNo'] as int? ?? 0,
      reqCode: json['reqCode']?.toString() ?? 'None',
      reqQty: (json['reqQty'] as num?)?.toDouble() ?? 0.0,
      itemCode: json['itemCode']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      toDeptCode: json['toDeptCode'] as int? ?? 0,
      toDeptName: json['toDeptName']?.toString() ?? '',
      toStoreId: json['toStoreId'] as int? ?? 0,
      toStoreName: json['toStoreName']?.toString() ?? '',
      toCostId: json['toCostId'] as int? ?? 0,
      toCostName: json['toCostName']?.toString() ?? '',
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
      binNo: json['binNo']?.toString() ?? '',
      remark: json['remark']?.toString() ?? '',
    );
  }
}

class StockTransferCreateRequest {
  final DateTime issueDate;
  final String issueMode;
  final String issueSource;
  final int sourceStoreId;
  final int sourceDeptCode;
  final int sourceDivId;
  final String plantName;
  final String spindal;
  final int slipNo;
  final String jobCard;
  final String remark;
  final String vehicleNo;
  final String ewayBillNo;
  final List<StockTransferLineItem> lines;

  StockTransferCreateRequest({
    required this.issueDate,
    this.issueMode = 'Stock Transfer',
    this.issueSource = 'Direct',
    required this.sourceStoreId,
    required this.sourceDeptCode,
    required this.sourceDivId,
    required this.plantName,
    required this.spindal,
    required this.slipNo,
    required this.jobCard,
    required this.remark,
    required this.vehicleNo,
    required this.ewayBillNo,
    required this.lines,
  });

  Map<String, dynamic> toJson() => {
        'issueDate': issueDate.toIso8601String(),
        'issueMode': issueMode,
        'issueSource': issueSource,
        'sourceStoreId': sourceStoreId,
        'sourceDeptCode': sourceDeptCode,
        'sourceDivId': sourceDivId,
        'plantName': plantName,
        'spindal': spindal,
        'slipNo': slipNo,
        'jobCard': jobCard,
        'remark': remark,
        'vehicleNo': vehicleNo,
        'ewayBillNo': ewayBillNo,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
}

class StockTransferGridRecord {
  final String issueCode;
  final DateTime issueDate;
  final String issueMode;
  final String issueSource;
  final int sourceStoreId;
  final String sourceStoreName;
  final int sourceDeptCode;
  final String sourceDeptName;
  final int sourceDivId;
  final String plantName;
  final String spindal;
  final int slipNo;
  final String jobCard;
  final String vehicleNo;
  final String ewayBillNo;
  final double totQty;
  final int totItm;
  final double totPcs;
  final String remark;
  final String createdBy;
  final DateTime? createdDate;

  const StockTransferGridRecord({
    required this.issueCode,
    required this.issueDate,
    this.issueMode = 'Stock Transfer',
    this.issueSource = 'Direct',
    this.sourceStoreId = 0,
    required this.sourceStoreName,
    this.sourceDeptCode = 0,
    required this.sourceDeptName,
    this.sourceDivId = 0,
    required this.plantName,
    this.spindal = '',
    this.slipNo = 0,
    this.jobCard = '',
    this.vehicleNo = '',
    this.ewayBillNo = '',
    required this.totQty,
    required this.totItm,
    required this.totPcs,
    required this.remark,
    required this.createdBy,
    this.createdDate,
  });

  factory StockTransferGridRecord.fromJson(Map<String, dynamic> json) {
    return StockTransferGridRecord(
      issueCode: json['issueCode']?.toString() ?? '',
      issueDate: json['issueDate'] != null
          ? DateTime.tryParse(json['issueDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      issueMode: json['issueMode']?.toString() ?? 'Stock Transfer',
      issueSource: json['issueSource']?.toString() ?? 'Direct',
      sourceStoreId: json['sourceStoreId'] as int? ?? 0,
      sourceStoreName: json['sourceStoreName']?.toString() ?? '',
      sourceDeptCode: json['sourceDeptCode'] as int? ?? 0,
      sourceDeptName: json['sourceDeptName']?.toString() ?? '',
      sourceDivId: json['sourceDivId'] as int? ?? 0,
      plantName: json['plantName']?.toString() ?? '',
      spindal: json['spindal']?.toString() ?? '',
      slipNo: json['slipNo'] as int? ?? 0,
      jobCard: json['jobCard']?.toString() ?? '',
      vehicleNo: json['vehicleNo']?.toString() ?? '',
      ewayBillNo: json['ewayBillNo']?.toString() ?? '',
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

class StockTransferPagedList {
  final List<StockTransferGridRecord> records;
  final int totalCount;

  const StockTransferPagedList({
    required this.records,
    required this.totalCount,
  });

  factory StockTransferPagedList.fromJson(Map<String, dynamic> json) {
    return StockTransferPagedList(
      records: (json['records'] as List<dynamic>? ?? [])
          .map((e) => StockTransferGridRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }
}

class StockTransferDetail {
  final StockTransferGridRecord header;
  final List<StockTransferLineItem> lines;

  const StockTransferDetail({
    required this.header,
    required this.lines,
  });

  factory StockTransferDetail.fromJson(Map<String, dynamic> json) {
    return StockTransferDetail(
      header: StockTransferGridRecord.fromJson(json['header'] as Map<String, dynamic>? ?? {}),
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((e) => StockTransferLineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
