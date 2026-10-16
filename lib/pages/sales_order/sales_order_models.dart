import 'package:flutter/foundation.dart';

// ============================================================================
// ENUM DEFINITIONS
// ============================================================================
enum ButtonStatus { idle, loading, success, error }

// ============================================================================
// PAGED DATA GENERIC WRAPPER
// ============================================================================
class PagedData<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;

  const PagedData({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  int get totalPages => (totalCount / pageSize).ceil();
  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
}

// ============================================================================
// SALES ORDER HEADER
// ============================================================================
@immutable
class SalesOrderHeader {
  final String soNo;
  final DateTime soDate;
  final int pCode;
  final String partyName;
  final String mobile;
  final String gstin;
  final String stateCode;
  final String address;
  final int deptCode;
  final String soMode;
  final int totItm;
  final double totQty;
  final double totDisc;
  final double totAmt;
  final double adv;
  final double pfChg;
  final double freight;
  final double others;
  final double netAmt;
  final String remark;
  final bool approved;
  final DateTime? appDate;
  final bool isRec;
  final DateTime? recDate;
  final bool isImp;
  final String curr;
  final bool closeSo;
  final String suppRef;
  final int soCrDays;
  final String somLoc;
  final DateTime? somEdate;
  final String somUsrName;
  final String somEmode;
  final int somDelDays;
  final int somCapMode;
  final String capModeName;
  final int typeId;
  final int somIsFreight;
  final int costCd;
  final String costCenterName;
  final int spCd;
  final String salesPersonName;
  final int somAddCd;

  final List<SalesOrderItem> items;
  final List<SalesOrderCharge> charges;
  final List<SalesOrderCondition> conditions;

  const SalesOrderHeader({
    required this.soNo,
    required this.soDate,
    required this.pCode,
    this.partyName = '',
    this.mobile = '',
    this.gstin = '',
    this.stateCode = '',
    this.address = '',
    this.deptCode = 0,
    this.soMode = 'Direct',
    this.totItm = 0,
    this.totQty = 0.0,
    this.totDisc = 0.0,
    this.totAmt = 0.0,
    this.adv = 0.0,
    this.pfChg = 0.0,
    this.freight = 0.0,
    this.others = 0.0,
    this.netAmt = 0.0,
    this.remark = '',
    this.approved = false,
    this.appDate,
    this.isRec = false,
    this.recDate,
    this.isImp = false,
    this.curr = 'INR',
    this.closeSo = false,
    this.suppRef = '',
    this.soCrDays = 0,
    this.somLoc = 'LWHL26_SQL',
    this.somEdate,
    this.somUsrName = '',
    this.somEmode = 'Direct',
    this.somDelDays = 0,
    this.somCapMode = 0,
    this.capModeName = '',
    this.typeId = 0,
    this.somIsFreight = 0,
    this.costCd = 0,
    this.costCenterName = '',
    this.spCd = 0,
    this.salesPersonName = '',
    this.somAddCd = 0,
    this.items = const [],
    this.charges = const [],
    this.conditions = const [],
  });

  factory SalesOrderHeader.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    bool parseBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      if (val is num) return val != 0;
      final str = val.toString().toLowerCase().trim();
      return str == 'true' || str == '1';
    }

    return SalesOrderHeader(
      soNo: json['soNo']?.toString() ?? '',
      soDate: parseDate(json['soDate']) ?? DateTime.now(),
      pCode: parseInt(json['pCode']),
      partyName: json['partyName']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      gstin: json['gstin']?.toString() ?? '',
      stateCode: json['stateCode']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      deptCode: parseInt(json['deptCode']),
      soMode: json['soMode']?.toString() ?? 'Direct',
      totItm: parseInt(json['totItm']),
      totQty: parseDouble(json['totQty']),
      totDisc: parseDouble(json['totDisc']),
      totAmt: parseDouble(json['totAmt']),
      adv: parseDouble(json['adv']),
      pfChg: parseDouble(json['pfChg']),
      freight: parseDouble(json['freight']),
      others: parseDouble(json['others']),
      netAmt: parseDouble(json['netAmt']),
      remark: json['remark']?.toString() ?? '',
      approved: parseBool(json['approved']),
      appDate: parseDate(json['appDate']),
      isRec: parseBool(json['isRec']),
      recDate: parseDate(json['recDate']),
      isImp: parseBool(json['isImp']),
      curr: json['curr']?.toString() ?? 'INR',
      closeSo: parseBool(json['closeSo']),
      suppRef: json['suppRef']?.toString() ?? '',
      soCrDays: parseInt(json['soCrDays']),
      somLoc: json['somLoc']?.toString() ?? 'LWHL26_SQL',
      somEdate: parseDate(json['somEdate']),
      somUsrName: json['somUsrName']?.toString() ?? '',
      somEmode: json['somEmode']?.toString() ?? 'Direct',
      somDelDays: parseInt(json['somDelDays']),
      somCapMode: parseInt(json['somCapMode']),
      capModeName: json['capModeName']?.toString() ?? '',
      typeId: parseInt(json['typeId']),
      somIsFreight: parseInt(json['somIsFreight']),
      costCd: parseInt(json['costCd']),
      costCenterName: json['costCenterName']?.toString() ?? '',
      spCd: parseInt(json['spCd']),
      salesPersonName: json['salesPersonName']?.toString() ?? '',
      somAddCd: parseInt(json['somAddCd']),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => SalesOrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      charges: (json['charges'] as List<dynamic>?)
              ?.map((e) => SalesOrderCharge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      conditions: (json['conditions'] as List<dynamic>?)
              ?.map((e) => SalesOrderCondition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  SalesOrderHeader copyWith({
    String? soNo,
    DateTime? soDate,
    int? pCode,
    String? partyName,
    String? mobile,
    String? gstin,
    String? stateCode,
    String? address,
    int? deptCode,
    String? soMode,
    int? totItm,
    double? totQty,
    double? totDisc,
    double? totAmt,
    double? adv,
    double? pfChg,
    double? freight,
    double? others,
    double? netAmt,
    String? remark,
    bool? approved,
    DateTime? appDate,
    bool? isRec,
    DateTime? recDate,
    bool? isImp,
    String? curr,
    bool? closeSo,
    String? suppRef,
    int? soCrDays,
    String? somLoc,
    DateTime? somEdate,
    String? somUsrName,
    String? somEmode,
    int? somDelDays,
    int? somCapMode,
    String? capModeName,
    int? typeId,
    int? somIsFreight,
    int? costCd,
    String? costCenterName,
    int? spCd,
    String? salesPersonName,
    int? somAddCd,
    List<SalesOrderItem>? items,
    List<SalesOrderCharge>? charges,
    List<SalesOrderCondition>? conditions,
  }) {
    return SalesOrderHeader(
      soNo: soNo ?? this.soNo,
      soDate: soDate ?? this.soDate,
      pCode: pCode ?? this.pCode,
      partyName: partyName ?? this.partyName,
      mobile: mobile ?? this.mobile,
      gstin: gstin ?? this.gstin,
      stateCode: stateCode ?? this.stateCode,
      address: address ?? this.address,
      deptCode: deptCode ?? this.deptCode,
      soMode: soMode ?? this.soMode,
      totItm: totItm ?? this.totItm,
      totQty: totQty ?? this.totQty,
      totDisc: totDisc ?? this.totDisc,
      totAmt: totAmt ?? this.totAmt,
      adv: adv ?? this.adv,
      pfChg: pfChg ?? this.pfChg,
      freight: freight ?? this.freight,
      others: others ?? this.others,
      netAmt: netAmt ?? this.netAmt,
      remark: remark ?? this.remark,
      approved: approved ?? this.approved,
      appDate: appDate ?? this.appDate,
      isRec: isRec ?? this.isRec,
      recDate: recDate ?? this.recDate,
      isImp: isImp ?? this.isImp,
      curr: curr ?? this.curr,
      closeSo: closeSo ?? this.closeSo,
      suppRef: suppRef ?? this.suppRef,
      soCrDays: soCrDays ?? this.soCrDays,
      somLoc: somLoc ?? this.somLoc,
      somEdate: somEdate ?? this.somEdate,
      somUsrName: somUsrName ?? this.somUsrName,
      somEmode: somEmode ?? this.somEmode,
      somDelDays: somDelDays ?? this.somDelDays,
      somCapMode: somCapMode ?? this.somCapMode,
      capModeName: capModeName ?? this.capModeName,
      typeId: typeId ?? this.typeId,
      somIsFreight: somIsFreight ?? this.somIsFreight,
      costCd: costCd ?? this.costCd,
      costCenterName: costCenterName ?? this.costCenterName,
      spCd: spCd ?? this.spCd,
      salesPersonName: salesPersonName ?? this.salesPersonName,
      somAddCd: somAddCd ?? this.somAddCd,
      items: items ?? this.items,
      charges: charges ?? this.charges,
      conditions: conditions ?? this.conditions,
    );
  }
}

// ============================================================================
// SALES ORDER ITEM (LINE ITEM)
// ============================================================================
@immutable
class SalesOrderItem {
  final String soNo;
  final int srNo;
  final String indCode;
  final String quoCode;
  final String iCode;
  final String itemName;
  final int uom;
  final String unitName;
  final double qty;
  final double accQty;
  final double rate;
  final double disc;
  final double amount;
  final bool isAppro;
  final bool isRec;
  final bool isReject;
  final bool isHold;
  final int khCode;
  final String divisionName;
  final int depCode;
  final String deptName;
  final String mrgNo;
  final String specification;
  final bool closeSo;

  const SalesOrderItem({
    this.soNo = '',
    required this.srNo,
    this.indCode = '',
    this.quoCode = '',
    required this.iCode,
    this.itemName = '',
    this.uom = 0,
    this.unitName = '',
    required this.qty,
    this.accQty = 0.0,
    required this.rate,
    this.disc = 0.0,
    required this.amount,
    this.isAppro = false,
    this.isRec = false,
    this.isReject = false,
    this.isHold = false,
    this.khCode = 0,
    this.divisionName = '',
    this.depCode = 0,
    this.deptName = '',
    this.mrgNo = '',
    this.specification = '',
    this.closeSo = false,
  });

  factory SalesOrderItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    bool parseBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      if (val is num) return val != 0;
      final str = val.toString().toLowerCase().trim();
      return str == 'true' || str == '1';
    }

    return SalesOrderItem(
      soNo: json['soNo']?.toString() ?? '',
      srNo: parseInt(json['srNo']),
      indCode: json['indCode']?.toString() ?? '',
      quoCode: json['quoCode']?.toString() ?? '',
      iCode: json['iCode']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      uom: parseInt(json['uom']),
      unitName: json['unitName']?.toString() ?? '',
      qty: parseDouble(json['qty']),
      accQty: parseDouble(json['accQty']),
      rate: parseDouble(json['rate']),
      disc: parseDouble(json['disc']),
      amount: parseDouble(json['amount']),
      isAppro: parseBool(json['isAppro']),
      isRec: parseBool(json['isRec']),
      isReject: parseBool(json['isReject']),
      isHold: parseBool(json['isHold']),
      khCode: parseInt(json['khCode']),
      divisionName: json['divisionName']?.toString() ?? '',
      depCode: parseInt(json['depCode']),
      deptName: json['deptName']?.toString() ?? '',
      mrgNo: json['mrgNo']?.toString() ?? '',
      specification: json['specification']?.toString() ?? '',
      closeSo: parseBool(json['closeSo']),
    );
  }

  Map<String, dynamic> toJson() => {
        'soNo': soNo,
        'srNo': srNo,
        'indCode': indCode,
        'quoCode': quoCode,
        'iCode': iCode,
        'itemName': itemName,
        'uom': uom,
        'unitName': unitName,
        'qty': qty,
        'accQty': accQty,
        'rate': rate,
        'disc': disc,
        'amount': amount,
        'isAppro': isAppro,
        'isRec': isRec,
        'isReject': isReject,
        'isHold': isHold,
        'khCode': khCode,
        'divisionName': divisionName,
        'depCode': depCode,
        'deptName': deptName,
        'mrgNo': mrgNo,
        'specification': specification,
        'closeSo': closeSo,
      };

  SalesOrderItem copyWith({
    String? soNo,
    int? srNo,
    String? indCode,
    String? quoCode,
    String? iCode,
    String? itemName,
    int? uom,
    String? unitName,
    double? qty,
    double? accQty,
    double? rate,
    double? disc,
    double? amount,
    bool? isAppro,
    bool? isRec,
    bool? isReject,
    bool? isHold,
    int? khCode,
    String? divisionName,
    int? depCode,
    String? deptName,
    String? mrgNo,
    String? specification,
    bool? closeSo,
  }) {
    return SalesOrderItem(
      soNo: soNo ?? this.soNo,
      srNo: srNo ?? this.srNo,
      indCode: indCode ?? this.indCode,
      quoCode: quoCode ?? this.quoCode,
      iCode: iCode ?? this.iCode,
      itemName: itemName ?? this.itemName,
      uom: uom ?? this.uom,
      unitName: unitName ?? this.unitName,
      qty: qty ?? this.qty,
      accQty: accQty ?? this.accQty,
      rate: rate ?? this.rate,
      disc: disc ?? this.disc,
      amount: amount ?? this.amount,
      isAppro: isAppro ?? this.isAppro,
      isRec: isRec ?? this.isRec,
      isReject: isReject ?? this.isReject,
      isHold: isHold ?? this.isHold,
      khCode: khCode ?? this.khCode,
      divisionName: divisionName ?? this.divisionName,
      depCode: depCode ?? this.depCode,
      deptName: deptName ?? this.deptName,
      mrgNo: mrgNo ?? this.mrgNo,
      specification: specification ?? this.specification,
      closeSo: closeSo ?? this.closeSo,
    );
  }
}

// ============================================================================
// CHARGE ITEM
// ============================================================================
@immutable
class SalesOrderCharge {
  final int id;
  final int chgId;
  final String chgName;
  final String code;
  final double per;
  final double amt;
  final String mode;
  final int addLess; // 1 for Add, -1 for Less
  final String exp;
  final String remark;

  const SalesOrderCharge({
    this.id = 0,
    required this.chgId,
    required this.chgName,
    this.code = '',
    this.per = 0.0,
    this.amt = 0.0,
    this.mode = 'QUOTATION',
    this.addLess = 1,
    this.exp = '',
    this.remark = '',
  });

  factory SalesOrderCharge.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    return SalesOrderCharge(
      id: parseInt(json['id']),
      chgId: parseInt(json['chgId']),
      chgName: json['chgName']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      per: parseDouble(json['per']),
      amt: parseDouble(json['amt']),
      mode: json['mode']?.toString() ?? 'QUOTATION',
      addLess: parseInt(json['addLess']) == -1 ? -1 : 1,
      exp: json['exp']?.toString() ?? '',
      remark: json['remark']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chgId': chgId,
        'chgName': chgName,
        'code': code,
        'per': per,
        'amt': amt,
        'mode': mode,
        'addLess': addLess,
        'exp': exp,
        'remark': remark,
      };

  SalesOrderCharge copyWith({
    int? id,
    int? chgId,
    String? chgName,
    String? code,
    double? per,
    double? amt,
    String? mode,
    int? addLess,
    String? exp,
    String? remark,
  }) {
    return SalesOrderCharge(
      id: id ?? this.id,
      chgId: chgId ?? this.chgId,
      chgName: chgName ?? this.chgName,
      code: code ?? this.code,
      per: per ?? this.per,
      amt: amt ?? this.amt,
      mode: mode ?? this.mode,
      addLess: addLess ?? this.addLess,
      exp: exp ?? this.exp,
      remark: remark ?? this.remark,
    );
  }
}

// ============================================================================
// CONDITION ITEM
// ============================================================================
@immutable
class SalesOrderCondition {
  final int conId;
  final int conNo;
  final String code;
  final String conditionText;

  const SalesOrderCondition({
    this.conId = 0,
    required this.conNo,
    this.code = '',
    required this.conditionText,
  });

  factory SalesOrderCondition.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    return SalesOrderCondition(
      conId: parseInt(json['conId']),
      conNo: parseInt(json['conNo']),
      code: json['code']?.toString() ?? '',
      conditionText: json['conditionText']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'conId': conId,
        'conNo': conNo,
        'code': code,
        'conditionText': conditionText,
      };
}

// ============================================================================
// LOOKUP MODELS
// ============================================================================
class CustomerLookup {
  final int pCode;
  final String pName;
  final String mobile;
  final String gstin;
  final String stateCode;
  final String address;

  String get gstIn => gstin;
  String get state => stateCode;

  const CustomerLookup({
    required this.pCode,
    required this.pName,
    this.mobile = '',
    this.gstin = '',
    this.stateCode = '',
    this.address = '',
  });

  factory CustomerLookup.fromJson(Map<String, dynamic> json) {
    return CustomerLookup(
      pCode: (json['pCode'] as num?)?.toInt() ?? 0,
      pName: json['pName']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      gstin: json['gstin']?.toString() ?? '',
      stateCode: json['stateCode']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}

class SalesOrderItemLookup {
  final String iCode;
  final String iName;
  final int unitCode;
  final String unitName;
  final int iBlock;
  final String hsn;

  String get hsnCode => hsn;
  String get groupName => '';
  double get balQty => 0.0;
  double get rate => 0.0;

  const SalesOrderItemLookup({
    required this.iCode,
    required this.iName,
    this.unitCode = 0,
    this.unitName = '',
    this.iBlock = 0,
    this.hsn = '',
  });

  factory SalesOrderItemLookup.fromJson(Map<String, dynamic> json) {
    return SalesOrderItemLookup(
      iCode: json['iCode']?.toString() ?? '',
      iName: json['iName']?.toString() ?? '',
      unitCode: (json['unitCode'] as num?)?.toInt() ?? 0,
      unitName: json['unitName']?.toString() ?? '',
      iBlock: (json['iBlock'] as num?)?.toInt() ?? 0,
      hsn: json['hsn']?.toString() ?? '',
    );
  }
}

class LookupCodeName {
  final int code;
  final String name;

  const LookupCodeName({required this.code, required this.name});
}

class SalesOrderLookups {
  final String nextSoNo;
  final List<String> currencies;
  final List<LookupCodeName> capModes;
  final List<LookupCodeName> costCenters;
  final List<LookupCodeName> salesPersons;
  final List<SalesOrderCharge> defaultCharges;
  final String companyStateCode;

  const SalesOrderLookups({
    required this.nextSoNo,
    required this.currencies,
    required this.capModes,
    required this.costCenters,
    required this.salesPersons,
    required this.defaultCharges,
    this.companyStateCode = '24',
  });

  factory SalesOrderLookups.fromJson(Map<String, dynamic> json) {
    final currs = (json['currencies'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['INR'];

    final caps = (json['capModes'] as List<dynamic>?)?.map((e) {
          final m = e as Map<String, dynamic>;
          return LookupCodeName(
            code: (m['locCode'] as num?)?.toInt() ?? 0,
            name: m['location']?.toString() ?? '',
          );
        }).toList() ??
        [];

    final ccs = (json['costCenters'] as List<dynamic>?)?.map((e) {
          final m = e as Map<String, dynamic>;
          return LookupCodeName(
            code: (m['khCode'] as num?)?.toInt() ?? 0,
            name: m['khName']?.toString() ?? '',
          );
        }).toList() ??
        [];

    final sps = (json['salesPersons'] as List<dynamic>?)?.map((e) {
          final m = e as Map<String, dynamic>;
          return LookupCodeName(
            code: (m['spmCode'] as num?)?.toInt() ?? 0,
            name: m['spmName']?.toString() ?? '',
          );
        }).toList() ??
        [];

    final chgs = (json['defaultCharges'] as List<dynamic>?)
            ?.map((e) => SalesOrderCharge.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return SalesOrderLookups(
      nextSoNo: json['nextSoNo']?.toString() ?? '',
      currencies: currs.isEmpty ? ['INR'] : currs,
      capModes: caps,
      costCenters: ccs,
      salesPersons: sps,
      defaultCharges: chgs,
      companyStateCode: json['companyStateCode']?.toString() ?? '24',
    );
  }
}
