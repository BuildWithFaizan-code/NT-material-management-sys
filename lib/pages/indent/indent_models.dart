class IndentDepartmentLookup {
  final int labCode;
  final String labName;

  const IndentDepartmentLookup({
    required this.labCode,
    required this.labName,
  });

  factory IndentDepartmentLookup.fromJson(Map<String, dynamic> json) {
    return IndentDepartmentLookup(
      labCode: json['labCode'] is int ? json['labCode'] : int.tryParse(json['labCode']?.toString() ?? '0') ?? 0,
      labName: json['labName']?.toString() ?? '',
    );
  }
}

class IndentStoreLookup {
  final int strCode;
  final String strName;

  const IndentStoreLookup({
    required this.strCode,
    required this.strName,
  });

  factory IndentStoreLookup.fromJson(Map<String, dynamic> json) {
    return IndentStoreLookup(
      strCode: json['strCode'] is int ? json['strCode'] : int.tryParse(json['strCode']?.toString() ?? '0') ?? 0,
      strName: json['strName']?.toString() ?? '',
    );
  }
}

class IndentCapModeLookup {
  final int locCode;
  final String location;

  const IndentCapModeLookup({
    required this.locCode,
    required this.location,
  });

  factory IndentCapModeLookup.fromJson(Map<String, dynamic> json) {
    return IndentCapModeLookup(
      locCode: json['locCode'] is int ? json['locCode'] : int.tryParse(json['locCode']?.toString() ?? '0') ?? 0,
      location: json['location']?.toString() ?? '',
    );
  }
}

class IndentCostCenterLookup {
  final int khCode;
  final String khName;

  const IndentCostCenterLookup({
    required this.khCode,
    required this.khName,
  });

  factory IndentCostCenterLookup.fromJson(Map<String, dynamic> json) {
    return IndentCostCenterLookup(
      khCode: json['khCode'] is int ? json['khCode'] : int.tryParse(json['khCode']?.toString() ?? '0') ?? 0,
      khName: json['khName']?.toString() ?? '',
    );
  }
}

class IndentItemLookup {
  final String iCode;
  final String itName;
  final int unitCode;
  final String unitName;
  final double stk;
  final double minQty;
  final double maxQty;
  final double orderOn;
  final String reqCode;

  const IndentItemLookup({
    required this.iCode,
    required this.itName,
    required this.unitCode,
    required this.unitName,
    required this.stk,
    required this.minQty,
    required this.maxQty,
    required this.orderOn,
    required this.reqCode,
  });

  factory IndentItemLookup.fromJson(Map<String, dynamic> json) {
    return IndentItemLookup(
      iCode: json['iCode']?.toString() ?? '',
      itName: json['itName']?.toString() ?? '',
      unitCode: json['unitCode'] is int ? json['unitCode'] : int.tryParse(json['unitCode']?.toString() ?? '0') ?? 0,
      unitName: json['unitName']?.toString() ?? '',
      stk: (json['stk'] is num) ? (json['stk'] as num).toDouble() : double.tryParse(json['stk']?.toString() ?? '0') ?? 0.0,
      minQty: (json['minQty'] is num) ? (json['minQty'] as num).toDouble() : double.tryParse(json['minQty']?.toString() ?? '0') ?? 0.0,
      maxQty: (json['maxQty'] is num) ? (json['maxQty'] as num).toDouble() : double.tryParse(json['maxQty']?.toString() ?? '0') ?? 0.0,
      orderOn: (json['orderOn'] is num) ? (json['orderOn'] as num).toDouble() : double.tryParse(json['orderOn']?.toString() ?? '0') ?? 0.0,
      reqCode: json['reqCode']?.toString() ?? '',
    );
  }
}

class IndentLookups {
  final String nextIndNo;
  final List<IndentDepartmentLookup> departments;
  final List<IndentStoreLookup> stores;
  final List<IndentCapModeLookup> capModes;
  final List<String> priorities;
  final List<String> sources;

  const IndentLookups({
    required this.nextIndNo,
    required this.departments,
    required this.stores,
    required this.capModes,
    required this.priorities,
    required this.sources,
  });

  factory IndentLookups.fromJson(Map<String, dynamic> json) {
    return IndentLookups(
      nextIndNo: json['nextIndNo']?.toString() ?? '',
      departments: (json['departments'] as List<dynamic>? ?? [])
          .map((e) => IndentDepartmentLookup.fromJson(e as Map<String, dynamic>))
          .toList(),
      stores: (json['stores'] as List<dynamic>? ?? [])
          .map((e) => IndentStoreLookup.fromJson(e as Map<String, dynamic>))
          .toList(),
      capModes: (json['capModes'] as List<dynamic>? ?? [])
          .map((e) => IndentCapModeLookup.fromJson(e as Map<String, dynamic>))
          .toList(),
      priorities: (json['priorities'] as List<dynamic>? ?? ['Normal', 'High', 'Urgent'])
          .map((e) => e.toString())
          .toList(),
      sources: (json['sources'] as List<dynamic>? ?? ['Manual'])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class IndentDetail {
  final String indCode;
  final int srno;
  final String reqNo;
  final String code;
  final String itemName;
  final int uom;
  final String uomName;
  final double qty;
  final double rate;
  final double totalValue;
  final int khCode;
  final String costCenterName;
  final int deptCode;
  final String deptName;
  final DateTime reqDate;
  final bool isAppro;
  final double stock;
  final double minQty;
  final double maxQty;
  final double orderOn;

  const IndentDetail({
    required this.indCode,
    required this.srno,
    this.reqNo = 'None',
    required this.code,
    required this.itemName,
    required this.uom,
    required this.uomName,
    required this.qty,
    required this.rate,
    required this.totalValue,
    required this.khCode,
    required this.costCenterName,
    required this.deptCode,
    required this.deptName,
    required this.reqDate,
    this.isAppro = false,
    this.stock = 0.0,
    this.minQty = 0.0,
    this.maxQty = 0.0,
    this.orderOn = 0.0,
  });

  factory IndentDetail.fromJson(Map<String, dynamic> json) {
    return IndentDetail(
      indCode: json['indCode']?.toString() ?? '',
      srno: json['srno'] is int ? json['srno'] : int.tryParse(json['srno']?.toString() ?? '0') ?? 0,
      reqNo: json['reqNo']?.toString() ?? 'None',
      code: json['code']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      uom: json['uom'] is int ? json['uom'] : int.tryParse(json['uom']?.toString() ?? '0') ?? 0,
      uomName: json['uomName']?.toString() ?? '',
      qty: (json['qty'] is num) ? (json['qty'] as num).toDouble() : double.tryParse(json['qty']?.toString() ?? '0') ?? 0.0,
      rate: (json['rate'] is num) ? (json['rate'] as num).toDouble() : double.tryParse(json['rate']?.toString() ?? '0') ?? 0.0,
      totalValue: (json['totalValue'] is num) ? (json['totalValue'] as num).toDouble() : double.tryParse(json['totalValue']?.toString() ?? '0') ?? 0.0,
      khCode: json['khCode'] is int ? json['khCode'] : int.tryParse(json['khCode']?.toString() ?? '0') ?? 0,
      costCenterName: json['costCenterName']?.toString() ?? '',
      deptCode: json['deptCode'] is int ? json['deptCode'] : int.tryParse(json['deptCode']?.toString() ?? '0') ?? 0,
      deptName: json['deptName']?.toString() ?? '',
      reqDate: DateTime.tryParse(json['reqDate']?.toString() ?? '') ?? DateTime.now(),
      isAppro: json['isAppro'] == true,
      stock: (json['stock'] is num) ? (json['stock'] as num).toDouble() : double.tryParse(json['stock']?.toString() ?? '0') ?? 0.0,
      minQty: (json['minQty'] is num) ? (json['minQty'] as num).toDouble() : double.tryParse(json['minQty']?.toString() ?? '0') ?? 0.0,
      maxQty: (json['maxQty'] is num) ? (json['maxQty'] as num).toDouble() : double.tryParse(json['maxQty']?.toString() ?? '0') ?? 0.0,
      orderOn: (json['orderOn'] is num) ? (json['orderOn'] as num).toDouble() : double.tryParse(json['orderOn']?.toString() ?? '0') ?? 0.0,
    );
  }

  IndentDetail copyWith({
    String? indCode,
    int? srno,
    String? reqNo,
    String? code,
    String? itemName,
    int? uom,
    String? uomName,
    double? qty,
    double? rate,
    double? totalValue,
    int? khCode,
    String? costCenterName,
    int? deptCode,
    String? deptName,
    DateTime? reqDate,
    bool? isAppro,
    double? stock,
    double? minQty,
    double? maxQty,
    double? orderOn,
  }) {
    return IndentDetail(
      indCode: indCode ?? this.indCode,
      srno: srno ?? this.srno,
      reqNo: reqNo ?? this.reqNo,
      code: code ?? this.code,
      itemName: itemName ?? this.itemName,
      uom: uom ?? this.uom,
      uomName: uomName ?? this.uomName,
      qty: qty ?? this.qty,
      rate: rate ?? this.rate,
      totalValue: totalValue ?? this.totalValue,
      khCode: khCode ?? this.khCode,
      costCenterName: costCenterName ?? this.costCenterName,
      deptCode: deptCode ?? this.deptCode,
      deptName: deptName ?? this.deptName,
      reqDate: reqDate ?? this.reqDate,
      isAppro: isAppro ?? this.isAppro,
      stock: stock ?? this.stock,
      minQty: minQty ?? this.minQty,
      maxQty: maxQty ?? this.maxQty,
      orderOn: orderOn ?? this.orderOn,
    );
  }
}

class IndentHeader {
  final String indCode;
  final DateTime indDate;
  final int deptCode;
  final String deptName;
  final int storeCode;
  final String storeName;
  final String priority;
  final String source;
  final int totItem;
  final double totQty;
  final double totAmt;
  final String remark;
  final bool isAppro;
  final DateTime? appDate;
  final String indUsrName;
  final String indEMode;
  final int indCapMode;
  final String capModeName;
  final int typeId;
  final List<IndentDetail> items;

  const IndentHeader({
    required this.indCode,
    required this.indDate,
    required this.deptCode,
    required this.deptName,
    required this.storeCode,
    required this.storeName,
    this.priority = 'Normal',
    this.source = 'Manual',
    required this.totItem,
    required this.totQty,
    required this.totAmt,
    this.remark = '',
    this.isAppro = false,
    this.appDate,
    this.indUsrName = '',
    this.indEMode = 'New',
    this.indCapMode = 3,
    this.capModeName = '',
    this.typeId = 0,
    this.items = const [],
  });

  factory IndentHeader.fromJson(Map<String, dynamic> json) {
    return IndentHeader(
      indCode: json['indCode']?.toString() ?? '',
      indDate: DateTime.tryParse(json['indDate']?.toString() ?? '') ?? DateTime.now(),
      deptCode: json['deptCode'] is int ? json['deptCode'] : int.tryParse(json['deptCode']?.toString() ?? '0') ?? 0,
      deptName: json['deptName']?.toString() ?? '',
      storeCode: json['storeCode'] is int ? json['storeCode'] : int.tryParse(json['storeCode']?.toString() ?? '0') ?? 0,
      storeName: json['storeName']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'Normal',
      source: json['source']?.toString() ?? 'Manual',
      totItem: json['totItem'] is int ? json['totItem'] : int.tryParse(json['totItem']?.toString() ?? '0') ?? 0,
      totQty: (json['totQty'] is num) ? (json['totQty'] as num).toDouble() : double.tryParse(json['totQty']?.toString() ?? '0') ?? 0.0,
      totAmt: (json['totAmt'] is num) ? (json['totAmt'] as num).toDouble() : double.tryParse(json['totAmt']?.toString() ?? '0') ?? 0.0,
      remark: json['remark']?.toString() ?? '',
      isAppro: json['isAppro'] == true,
      appDate: json['appDate'] != null ? DateTime.tryParse(json['appDate'].toString()) : null,
      indUsrName: json['indUsrName']?.toString() ?? '',
      indEMode: json['indEMode']?.toString() ?? 'New',
      indCapMode: json['indCapMode'] is int ? json['indCapMode'] : int.tryParse(json['indCapMode']?.toString() ?? '0') ?? 0,
      capModeName: json['capModeName']?.toString() ?? '',
      typeId: json['typeId'] is int ? json['typeId'] : int.tryParse(json['typeId']?.toString() ?? '0') ?? 0,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => IndentDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class IndentPagedResult<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;

  const IndentPagedResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  int get totalPages => pageSize > 0 ? (totalCount / pageSize).ceil() : 0;
}

class IndentSavePayload {
  final DateTime indDate;
  final int deptCode;
  final int storeCode;
  final String priority;
  final String source;
  final String remark;
  final int capMode;
  final List<IndentLineItemPayload> items;

  const IndentSavePayload({
    required this.indDate,
    required this.deptCode,
    required this.storeCode,
    this.priority = 'Normal',
    this.source = 'Manual',
    this.remark = '',
    this.capMode = 3,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'indDate': indDate.toIso8601String(),
      'deptCode': deptCode,
      'storeCode': storeCode,
      'priority': priority,
      'source': source,
      'remark': remark,
      'capMode': capMode,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}

class IndentLineItemPayload {
  final int srno;
  final String reqNo;
  final String code;
  final String description;
  final int uom;
  final double qty;
  final double rate;
  final double totalValue;
  final int khCode;
  final int deptCode;
  final DateTime reqDate;

  const IndentLineItemPayload({
    required this.srno,
    this.reqNo = 'None',
    required this.code,
    this.description = '',
    required this.uom,
    required this.qty,
    required this.rate,
    required this.totalValue,
    required this.khCode,
    required this.deptCode,
    required this.reqDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'srno': srno,
      'reqNo': reqNo,
      'code': code,
      'description': description,
      'uom': uom,
      'qty': qty,
      'rate': rate,
      'totalValue': totalValue,
      'khCode': khCode,
      'deptCode': deptCode,
      'reqDate': reqDate.toIso8601String(),
    };
  }
}
