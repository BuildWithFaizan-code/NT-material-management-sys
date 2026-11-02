/// Lookup item for Dropdowns (Department, Store, Division, Party)
class MaterialReturnLookupItem {
  final String code;
  final String name;
  final int? id;
  final String? hsn;

  const MaterialReturnLookupItem({
    required this.code,
    required this.name,
    this.id,
    this.hsn,
  });

  factory MaterialReturnLookupItem.fromJson(Map<String, dynamic> json) {
    return MaterialReturnLookupItem(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      hsn: json['hsn']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'id': id,
    'hsn': hsn,
  };
}

/// Operator lookup item from OPERATORMST
class MaterialReturnOperator {
  final String operCode;
  final String operName;
  final bool isEmp;

  const MaterialReturnOperator({
    required this.operCode,
    required this.operName,
    required this.isEmp,
  });

  factory MaterialReturnOperator.fromJson(Map<String, dynamic> json) {
    return MaterialReturnOperator(
      operCode: json['operCode']?.toString() ?? '',
      operName: json['operName']?.toString() ?? '',
      isEmp: json['isEmp'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'operCode': operCode,
    'operName': operName,
    'isEmp': isEmp,
  };
}

/// Aggregated Lookups for Material Return Wizard
class MaterialReturnLookups {
  final List<MaterialReturnLookupItem> departments;
  final List<MaterialReturnLookupItem> stores;
  final List<MaterialReturnLookupItem> divisions;
  final List<MaterialReturnLookupItem> parties;
  final List<MaterialReturnOperator> operators;
  final String defaultLocation;
  final String defaultCostCenter;

  const MaterialReturnLookups({
    required this.departments,
    required this.stores,
    required this.divisions,
    required this.parties,
    required this.operators,
    required this.defaultLocation,
    required this.defaultCostCenter,
  });

  factory MaterialReturnLookups.fromJson(Map<String, dynamic> json) {
    return MaterialReturnLookups(
      departments: (json['departments'] as List<dynamic>? ?? [])
          .map((e) => MaterialReturnLookupItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      stores: (json['stores'] as List<dynamic>? ?? [])
          .map((e) => MaterialReturnLookupItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      divisions: (json['divisions'] as List<dynamic>? ?? [])
          .map((e) => MaterialReturnLookupItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      parties: (json['parties'] as List<dynamic>? ?? [])
          .map((e) => MaterialReturnLookupItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      operators: (json['operators'] as List<dynamic>? ?? [])
          .map((e) => MaterialReturnOperator.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultLocation: json['defaultLocation']?.toString() ?? 'HO',
      defaultCostCenter: json['defaultCostCenter']?.toString() ?? 'DEFAULT',
    );
  }
}

/// Catalog item from ITEMMST + STOCKREGNEW
class MaterialReturnStockCatalogItem {
  final String itemCode;
  final String itemName;
  final String uom;
  final double balanceQty;
  final double avgRate;
  final String hsnCode;
  final int cops;
  final String convUom;
  final double convQty;
  final String mrgNo;
  final String matGrade;
  final String matShade;
  final String matMaker;
  final String binNo;
  final double cgper;
  final double sgper;
  final double igper;

  const MaterialReturnStockCatalogItem({
    required this.itemCode,
    required this.itemName,
    required this.uom,
    required this.balanceQty,
    required this.avgRate,
    required this.hsnCode,
    required this.cops,
    required this.convUom,
    required this.convQty,
    required this.mrgNo,
    required this.matGrade,
    required this.matShade,
    required this.matMaker,
    required this.binNo,
    required this.cgper,
    required this.sgper,
    required this.igper,
  });

  factory MaterialReturnStockCatalogItem.fromJson(Map<String, dynamic> json) {
    return MaterialReturnStockCatalogItem(
      itemCode: json['itemCode']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      uom: json['uom']?.toString() ?? '',
      balanceQty: (json['balanceQty'] as num?)?.toDouble() ?? 0.0,
      avgRate: (json['avgRate'] as num?)?.toDouble() ?? 0.0,
      hsnCode: json['hsnCode']?.toString() ?? '',
      cops: (json['cops'] as num?)?.toInt() ?? 0,
      convUom: json['convUom']?.toString() ?? '',
      convQty: (json['convQty'] as num?)?.toDouble() ?? 0.0,
      mrgNo: json['mrgNo']?.toString() ?? '',
      matGrade: json['matGrade']?.toString() ?? '',
      matShade: json['matShade']?.toString() ?? '',
      matMaker: json['matMaker']?.toString() ?? '',
      binNo: json['binNo']?.toString() ?? '',
      cgper: (json['cgper'] as num?)?.toDouble() ?? 0.0,
      sgper: (json['sgper'] as num?)?.toDouble() ?? 0.0,
      igper: (json['igper'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Stock catalog paged result
class MaterialReturnStockCatalogPagedResult {
  final List<MaterialReturnStockCatalogItem> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool hasMore;

  const MaterialReturnStockCatalogPagedResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory MaterialReturnStockCatalogPagedResult.fromJson(Map<String, dynamic> json) {
    return MaterialReturnStockCatalogPagedResult(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => MaterialReturnStockCatalogItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 50,
      hasMore: json['hasMore'] == true,
    );
  }
}

/// Line Item Input strictly matching the exact 21 columns of the line item grid
class MaterialReturnLineItem {
  int srNo; // 1: srno
  String itemCode; // 2: Item Code
  String itemName; // 3: Item Name
  String hsn; // 4: HSN
  String mrgNo; // 5: Merge No.
  String grade; // 6: Grade
  String shade; // 7: Shade
  String maker; // 8: Maker
  String uqc; // 9: UQC
  double qty; // 10: Qty
  double rate; // 11: Rate
  double amount; // 12: Amount (Qty * Rate)
  int cops; // 13: Cops
  double stock; // 14: Stock
  double cgst; // 15: CGST (%)
  double cgstAmt; // 16: CGST_Amt
  double sgst; // 17: SGST (%)
  double sgstAmt; // 18: SGST_Amt
  double igst; // 19: IGST (%)
  double igstAmt; // 20: IGST_Amt
  double netAmt; // 21: Net_Amt

  // Additional persistence fields
  String binNo;
  String convUom;
  double convQty;
  String rcopsType;
  String retRemark;
  double cut;

  MaterialReturnLineItem({
    required this.srNo,
    required this.itemCode,
    required this.itemName,
    required this.hsn,
    required this.mrgNo,
    required this.grade,
    required this.shade,
    required this.maker,
    required this.uqc,
    required this.qty,
    required this.rate,
    required this.amount,
    required this.cops,
    required this.stock,
    required this.cgst,
    required this.cgstAmt,
    required this.sgst,
    required this.sgstAmt,
    required this.igst,
    required this.igstAmt,
    required this.netAmt,
    this.binNo = '',
    this.convUom = '',
    this.convQty = 0.0,
    this.rcopsType = '',
    this.retRemark = '',
    this.cut = 0.0,
  });

  /// Factory from backend JSON
  factory MaterialReturnLineItem.fromJson(Map<String, dynamic> json) {
    return MaterialReturnLineItem(
      srNo: (json['srNo'] as num?)?.toInt() ?? 1,
      itemCode: json['itemCode']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      hsn: json['hsn']?.toString() ?? '',
      mrgNo: json['mrgNo']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      shade: json['shade']?.toString() ?? '',
      maker: json['maker']?.toString() ?? '',
      uqc: json['uqc']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      cops: (json['cops'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
      cgst: (json['cgst'] as num?)?.toDouble() ?? 0.0,
      cgstAmt: (json['cgstAmt'] as num?)?.toDouble() ?? 0.0,
      sgst: (json['sgst'] as num?)?.toDouble() ?? 0.0,
      sgstAmt: (json['sgstAmt'] as num?)?.toDouble() ?? 0.0,
      igst: (json['igst'] as num?)?.toDouble() ?? 0.0,
      igstAmt: (json['igstAmt'] as num?)?.toDouble() ?? 0.0,
      netAmt: (json['netAmt'] as num?)?.toDouble() ?? 0.0,
      binNo: json['binNo']?.toString() ?? '',
      convUom: json['convUom']?.toString() ?? '',
      convQty: (json['convQty'] as num?)?.toDouble() ?? 0.0,
      rcopsType: json['rcopsType']?.toString() ?? '',
      retRemark: json['retRemark']?.toString() ?? '',
      cut: (json['cut'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'srNo': srNo,
    'itemCode': itemCode,
    'itemName': itemName,
    'hsn': hsn,
    'mrgNo': mrgNo,
    'grade': grade,
    'shade': shade,
    'maker': maker,
    'uqc': uqc,
    'qty': qty,
    'rate': rate,
    'amount': amount,
    'cops': cops,
    'stock': stock,
    'cgst': cgst,
    'cgstAmt': cgstAmt,
    'sgst': sgst,
    'sgstAmt': sgstAmt,
    'igst': igst,
    'igstAmt': igstAmt,
    'netAmt': netAmt,
    'binNo': binNo,
    'convUom': convUom,
    'convQty': convQty,
    'rcopsType': rcopsType,
    'retRemark': retRemark,
    'cut': cut,
  };

  MaterialReturnLineItem clone() {
    return MaterialReturnLineItem(
      srNo: srNo,
      itemCode: itemCode,
      itemName: itemName,
      hsn: hsn,
      mrgNo: mrgNo,
      grade: grade,
      shade: shade,
      maker: maker,
      uqc: uqc,
      qty: qty,
      rate: rate,
      amount: amount,
      cops: cops,
      stock: stock,
      cgst: cgst,
      cgstAmt: cgstAmt,
      sgst: sgst,
      sgstAmt: sgstAmt,
      igst: igst,
      igstAmt: igstAmt,
      netAmt: netAmt,
      binNo: binNo,
      convUom: convUom,
      convQty: convQty,
      rcopsType: rcopsType,
      retRemark: retRemark,
      cut: cut,
    );
  }
}

/// Create/Update Request DTO
class MaterialReturnCreateRequest {
  final String? retCode;
  final DateTime retDate;
  final String retMode;
  final String retTo;
  final String source;
  final String location;
  final String costCenter;
  final String? operatorCode;
  final String currency;
  final int creditDays;
  final String? gstin;
  final String? remark;
  final double totQty;
  final int totItm;
  final List<MaterialReturnLineItem> lines;

  MaterialReturnCreateRequest({
    this.retCode,
    required this.retDate,
    required this.retMode,
    required this.retTo,
    required this.source,
    required this.location,
    required this.costCenter,
    this.operatorCode,
    this.currency = 'INR',
    this.creditDays = 0,
    this.gstin,
    this.remark,
    required this.totQty,
    required this.totItm,
    required this.lines,
  });

  Map<String, dynamic> toJson() => {
    'retCode': retCode,
    'retDate': retDate.toIso8601String().substring(0, 10),
    'retMode': retMode,
    'retTo': retTo,
    'source': source,
    'location': location,
    'costCenter': costCenter,
    'operatorCode': operatorCode,
    'currency': currency,
    'creditDays': creditDays,
    'gstin': gstin,
    'remark': remark,
    'totQty': totQty,
    'totItm': totItm,
    'lines': lines.map((l) => l.toJson()).toList(),
  };
}

/// Grid Record for the Corporate Main Table
class MaterialReturnGridRecord {
  final String retCode;
  final DateTime retDate;
  final String retMode;
  final String retTo;
  final String retToName;
  final double totQty;
  final int totItm;
  final String remark;
  final String operatorName;
  final String location;
  final DateTime? createdDate;

  const MaterialReturnGridRecord({
    required this.retCode,
    required this.retDate,
    required this.retMode,
    required this.retTo,
    required this.retToName,
    required this.totQty,
    required this.totItm,
    required this.remark,
    required this.operatorName,
    required this.location,
    this.createdDate,
  });

  factory MaterialReturnGridRecord.fromJson(Map<String, dynamic> json) {
    return MaterialReturnGridRecord(
      retCode: json['retCode']?.toString() ?? '',
      retDate: DateTime.tryParse(json['retDate']?.toString() ?? '') ?? DateTime.now(),
      retMode: json['retMode']?.toString() ?? '',
      retTo: json['retTo']?.toString() ?? '',
      retToName: json['retToName']?.toString() ?? '',
      totQty: (json['totQty'] as num?)?.toDouble() ?? 0.0,
      totItm: (json['totItm'] as num?)?.toInt() ?? 0,
      remark: json['remark']?.toString() ?? '',
      operatorName: json['operatorName']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      createdDate: json['createdDate'] != null ? DateTime.tryParse(json['createdDate'].toString()) : null,
    );
  }
}

/// Paged List for Grid
class MaterialReturnPagedList {
  final List<MaterialReturnGridRecord> records;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool hasMore;

  const MaterialReturnPagedList({
    required this.records,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory MaterialReturnPagedList.fromJson(Map<String, dynamic> json) {
    return MaterialReturnPagedList(
      records: (json['records'] as List<dynamic>? ?? [])
          .map((e) => MaterialReturnGridRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 25,
      hasMore: json['hasMore'] == true,
    );
  }
}

/// Full Detail for Edit and View
class MaterialReturnDetail {
  final String retCode;
  final DateTime retDate;
  final String retMode;
  final String retTo;
  final String retToName;
  final String source;
  final String location;
  final String costCenter;
  final String currency;
  final int creditDays;
  final String operatorCode;
  final String operatorName;
  final String gstin;
  final String remark;
  final double totQty;
  final int totItm;
  final List<MaterialReturnLineItem> lines;

  const MaterialReturnDetail({
    required this.retCode,
    required this.retDate,
    required this.retMode,
    required this.retTo,
    required this.retToName,
    required this.source,
    required this.location,
    required this.costCenter,
    this.currency = 'INR',
    this.creditDays = 0,
    required this.operatorCode,
    required this.operatorName,
    required this.gstin,
    required this.remark,
    required this.totQty,
    required this.totItm,
    required this.lines,
  });

  factory MaterialReturnDetail.fromJson(Map<String, dynamic> json) {
    final header = json['header'] as Map<String, dynamic>? ?? json;
    return MaterialReturnDetail(
      retCode: header['retCode']?.toString() ?? '',
      retDate: DateTime.tryParse(header['retDate']?.toString() ?? '') ?? DateTime.now(),
      retMode: header['retMode']?.toString() ?? '',
      retTo: header['retTo']?.toString() ?? '',
      retToName: header['retToName']?.toString() ?? '',
      source: header['source']?.toString() ?? (header['retType']?.toString() ?? 'Direct'),
      location: header['location']?.toString() ?? 'HO',
      costCenter: header['costCenter']?.toString() ?? 'DEFAULT',
      currency: header['currency']?.toString() ?? 'INR',
      creditDays: (header['creditDays'] as num?)?.toInt() ?? 0,
      operatorCode: header['operatorCode']?.toString() ?? '',
      operatorName: header['operatorName']?.toString() ?? '',
      gstin: header['gstin']?.toString() ?? '',
      remark: header['remark']?.toString() ?? '',
      totQty: (header['totQty'] as num?)?.toDouble() ?? 0.0,
      totItm: (header['totItm'] as num?)?.toInt() ?? 0,
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((e) => MaterialReturnLineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Save / Mutation Result
class MaterialReturnSaveResult {
  final bool success;
  final String docNo;
  final String message;

  const MaterialReturnSaveResult({
    required this.success,
    required this.docNo,
    required this.message,
  });

  factory MaterialReturnSaveResult.fromJson(Map<String, dynamic> json) {
    return MaterialReturnSaveResult(
      success: json['success'] == true,
      docNo: json['docNo']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}
