import 'package:flutter/foundation.dart';

// ============================================================================
// ENUM DEFINITIONS
// ============================================================================
enum ButtonStatus { idle, loading, success, error }

// ============================================================================
// PURCHASE ORDER DATA MODELS (MATCHING BACKEND CONTRACTS & LEGACY SPEC)
// ============================================================================

@immutable
class PurchaseOrderHeader {
  final String poNo;
  final DateTime poDate;
  final int pCode;
  final String partyName;
  final String gstin;
  final String stateCode;
  final String address;
  final int poDelCd;
  final String delPartyName;
  final int pStrCode;
  final String storeName;
  final int deptCode;
  final String deptName;
  final String poMode;
  final int totItm;
  final double totQty;
  final double totDisc;
  final double totAmt;
  final double pfChg;
  final double excise;
  final double lstChst;
  final double freight;
  final double insurance;
  final double others;
  final double netAmt;
  final String dTerms;
  final String pTerms;
  final String dispIns;
  final String spNote;
  final String remark;
  final bool approved;
  final DateTime? appDate;
  final bool isRec;
  final DateTime? recDate;
  final bool isImp;
  final String curr;
  final String words;
  final bool closePO;
  final String suppRef;
  final int poCrDays;
  final int pomDelDays;
  final int pomCapMode;
  final String pomUsrName;
  final DateTime? pomEDate;
  final double cgPer;
  final double cgAmt;
  final double sgPer;
  final double sgAmt;
  final double igPer;
  final double igAmt;
  final int pomBrCode;
  final String brokerName;
  final int pomIsFreight;

  final List<PurchaseOrderItem> items;
  final List<PurchaseOrderCharge> charges;
  final List<PurchaseOrderCondition> conditions;

  const PurchaseOrderHeader({
    required this.poNo,
    required this.poDate,
    required this.pCode,
    this.partyName = '',
    this.gstin = '',
    this.stateCode = '',
    this.address = '',
    this.poDelCd = 0,
    this.delPartyName = '',
    this.pStrCode = 0,
    this.storeName = '',
    this.deptCode = 0,
    this.deptName = '',
    this.poMode = 'Direct',
    this.totItm = 0,
    this.totQty = 0.0,
    this.totDisc = 0.0,
    this.totAmt = 0.0,
    this.pfChg = 0.0,
    this.excise = 0.0,
    this.lstChst = 0.0,
    this.freight = 0.0,
    this.insurance = 0.0,
    this.others = 0.0,
    this.netAmt = 0.0,
    this.dTerms = '',
    this.pTerms = '',
    this.dispIns = '',
    this.spNote = '',
    this.remark = '',
    this.approved = false,
    this.appDate,
    this.isRec = false,
    this.recDate,
    this.isImp = false,
    this.curr = '',
    this.words = '',
    this.closePO = false,
    this.suppRef = '',
    this.poCrDays = 0,
    this.pomDelDays = 0,
    this.pomCapMode = 0,
    this.pomUsrName = '',
    this.pomEDate,
    this.cgPer = 0.0,
    this.cgAmt = 0.0,
    this.sgPer = 0.0,
    this.sgAmt = 0.0,
    this.igPer = 0.0,
    this.igAmt = 0.0,
    this.pomBrCode = 0,
    this.brokerName = '',
    this.pomIsFreight = 0,
    this.items = const [],
    this.charges = const [],
    this.conditions = const [],
  });

  factory PurchaseOrderHeader.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderHeader(
      poNo: (json['poNo'] ?? '').toString(),
      poDate: json['poDate'] != null ? DateTime.tryParse(json['poDate'].toString()) ?? DateTime.now() : DateTime.now(),
      pCode: (json['pCode'] ?? 0) as int,
      partyName: (json['partyName'] ?? '').toString(),
      gstin: (json['gstin'] ?? '').toString(),
      stateCode: (json['stateCode'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      poDelCd: (json['poDelCd'] ?? 0) as int,
      delPartyName: (json['delPartyName'] ?? '').toString(),
      pStrCode: (json['pStrCode'] ?? 0) as int,
      storeName: (json['storeName'] ?? '').toString(),
      deptCode: (json['deptCode'] ?? 0) as int,
      deptName: (json['deptName'] ?? '').toString(),
      poMode: (json['poMode'] ?? 'Direct').toString(),
      totItm: (json['totItm'] ?? 0) as int,
      totQty: (json['totQty'] as num?)?.toDouble() ?? 0.0,
      totDisc: (json['totDisc'] as num?)?.toDouble() ?? 0.0,
      totAmt: (json['totAmt'] as num?)?.toDouble() ?? 0.0,
      pfChg: (json['pfChg'] as num?)?.toDouble() ?? 0.0,
      excise: (json['excise'] as num?)?.toDouble() ?? 0.0,
      lstChst: (json['lstChst'] as num?)?.toDouble() ?? 0.0,
      freight: (json['freight'] as num?)?.toDouble() ?? 0.0,
      insurance: (json['insurance'] as num?)?.toDouble() ?? 0.0,
      others: (json['others'] as num?)?.toDouble() ?? 0.0,
      netAmt: (json['netAmt'] as num?)?.toDouble() ?? 0.0,
      dTerms: (json['dTerms'] ?? '').toString(),
      pTerms: (json['pTerms'] ?? '').toString(),
      dispIns: (json['dispIns'] ?? '').toString(),
      spNote: (json['spNote'] ?? '').toString(),
      remark: (json['remark'] ?? '').toString(),
      approved: json['approved'] == true,
      appDate: json['appDate'] != null ? DateTime.tryParse(json['appDate'].toString()) : null,
      isRec: json['isRec'] == true,
      recDate: json['recDate'] != null ? DateTime.tryParse(json['recDate'].toString()) : null,
      isImp: json['isImp'] == true,
      curr: (json['curr'] ?? '').toString(),
      words: (json['words'] ?? '').toString(),
      closePO: json['closePO'] == true,
      suppRef: (json['suppRef'] ?? '').toString(),
      poCrDays: (json['poCrDays'] ?? 0) as int,
      pomDelDays: (json['pomDelDays'] ?? 0) as int,
      pomCapMode: (json['pomCapMode'] ?? 0) as int,
      pomUsrName: (json['pomUsrName'] ?? '').toString(),
      pomEDate: json['pomEDate'] != null ? DateTime.tryParse(json['pomEDate'].toString()) : null,
      cgPer: (json['cgPer'] as num?)?.toDouble() ?? 0.0,
      cgAmt: (json['cgAmt'] as num?)?.toDouble() ?? 0.0,
      sgPer: (json['sgPer'] as num?)?.toDouble() ?? 0.0,
      sgAmt: (json['sgAmt'] as num?)?.toDouble() ?? 0.0,
      igPer: (json['igPer'] as num?)?.toDouble() ?? 0.0,
      igAmt: (json['igAmt'] as num?)?.toDouble() ?? 0.0,
      pomBrCode: (json['pomBrCode'] ?? 0) as int,
      brokerName: (json['brokerName'] ?? '').toString(),
      pomIsFreight: (json['pomIsFreight'] ?? 0) as int,
      items: (json['items'] as List?)?.map((i) => PurchaseOrderItem.fromJson(i as Map<String, dynamic>)).toList() ?? const [],
      charges: (json['charges'] as List?)?.map((c) => PurchaseOrderCharge.fromJson(c as Map<String, dynamic>)).toList() ?? const [],
      conditions: (json['conditions'] as List?)?.map((c) => PurchaseOrderCondition.fromJson(c as Map<String, dynamic>)).toList() ?? const [],
    );
  }
}

@immutable
class PurchaseOrderItem {
  final int pId;
  final String poNo;
  final int srNo;
  final String indCode;
  final String quoCode;
  final String iCode;
  final String itemName;
  final String hsn;
  final int uom;
  final String unitName;
  final double qty;
  final double accQty;
  final double rate;
  final double disc;
  final double amount;
  final int khCode;
  final String divisionName;
  final int depCode;
  final String deptName;
  final String mrgNo;
  final String shade;
  final String specification;
  final String pRemark;
  final double freight;
  final int podIsFreight;
  final double cgPer;
  final double cgAmt;
  final double sgPer;
  final double sgAmt;
  final double igPer;
  final double igAmt;
  final double netAmt;
  final double podStock;
  final double podLastRate;
  final int podMakeId;
  final String makerName;
  final int podConvUom;
  final String convUnitName;
  final double podConvQty;
  final bool closePO;

  const PurchaseOrderItem({
    this.pId = 0,
    this.poNo = '',
    required this.srNo,
    this.indCode = 'None',
    this.quoCode = 'None',
    required this.iCode,
    this.itemName = '',
    this.hsn = '',
    this.uom = 0,
    this.unitName = '',
    required this.qty,
    this.accQty = 0.0,
    required this.rate,
    this.disc = 0.0,
    this.amount = 0.0,
    this.khCode = 0,
    this.divisionName = '',
    this.depCode = 0,
    this.deptName = '',
    this.mrgNo = '',
    this.shade = '*',
    this.specification = '',
    this.pRemark = '',
    this.freight = 0.0,
    this.podIsFreight = 0,
    this.cgPer = 0.0,
    this.cgAmt = 0.0,
    this.sgPer = 0.0,
    this.sgAmt = 0.0,
    this.igPer = 0.0,
    this.igAmt = 0.0,
    this.netAmt = 0.0,
    this.podStock = 0.0,
    this.podLastRate = 0.0,
    this.podMakeId = 0,
    this.makerName = '',
    this.podConvUom = 0,
    this.convUnitName = '',
    this.podConvQty = 0.0,
    this.closePO = false,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      pId: (json['pId'] ?? 0) as int,
      poNo: (json['poNo'] ?? '').toString(),
      srNo: (json['srNo'] ?? 1) as int,
      indCode: (json['indCode'] ?? 'None').toString(),
      quoCode: (json['quoCode'] ?? 'None').toString(),
      iCode: (json['iCode'] ?? '').toString(),
      itemName: (json['itemName'] ?? '').toString(),
      hsn: (json['hsn'] ?? '').toString(),
      uom: (json['uom'] ?? 0) as int,
      unitName: (json['unitName'] ?? '').toString(),
      qty: (json['qty'] as num?)?.toDouble() ?? 0.0,
      accQty: (json['accQty'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      disc: (json['disc'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      khCode: (json['khCode'] ?? 0) as int,
      divisionName: (json['divisionName'] ?? '').toString(),
      depCode: (json['depCode'] ?? 0) as int,
      deptName: (json['deptName'] ?? '').toString(),
      mrgNo: (json['mrgNo'] ?? '').toString(),
      shade: (json['shade'] ?? '*').toString(),
      specification: (json['specification'] ?? '').toString(),
      pRemark: (json['pRemark'] ?? '').toString(),
      freight: (json['freight'] as num?)?.toDouble() ?? 0.0,
      podIsFreight: (json['podIsFreight'] ?? 0) as int,
      cgPer: (json['cgPer'] as num?)?.toDouble() ?? 0.0,
      cgAmt: (json['cgAmt'] as num?)?.toDouble() ?? 0.0,
      sgPer: (json['sgPer'] as num?)?.toDouble() ?? 0.0,
      sgAmt: (json['sgAmt'] as num?)?.toDouble() ?? 0.0,
      igPer: (json['igPer'] as num?)?.toDouble() ?? 0.0,
      igAmt: (json['igAmt'] as num?)?.toDouble() ?? 0.0,
      netAmt: (json['netAmt'] as num?)?.toDouble() ?? 0.0,
      podStock: (json['podStock'] as num?)?.toDouble() ?? 0.0,
      podLastRate: (json['podLastRate'] as num?)?.toDouble() ?? 0.0,
      podMakeId: (json['podMakeId'] ?? 0) as int,
      makerName: (json['makerName'] ?? '').toString(),
      podConvUom: (json['podConvUom'] ?? 0) as int,
      convUnitName: (json['convUnitName'] ?? '').toString(),
      podConvQty: (json['podConvQty'] as num?)?.toDouble() ?? 0.0,
      closePO: json['closePO'] == true,
    );
  }

  Map<String, dynamic> toSaveJson() => {
    'srNo': srNo,
    'iCode': iCode,
    'uom': uom,
    'qty': qty,
    'rate': rate,
    'disc': disc,
    'amount': amount,
    'khCode': khCode,
    'depCode': depCode,
    'mrgNo': mrgNo,
    'shade': shade,
    'specification': specification,
    'pRemark': pRemark,
    'freight': freight,
    'podIsFreight': podIsFreight,
    'cgPer': cgPer,
    'cgAmt': cgAmt,
    'sgPer': sgPer,
    'sgAmt': sgAmt,
    'igPer': igPer,
    'igAmt': igAmt,
    'podStock': podStock,
    'podLastRate': podLastRate,
    'podMakeId': podMakeId,
    'podConvUom': podConvUom,
    'podConvQty': podConvQty,
  };
}

int _parseAddLess(dynamic value) {
  if (value == null) return 1;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final s = value.toString().trim();
  if (s == '-' || s == '-1') return -1;
  final parsed = int.tryParse(s);
  if (parsed != null) return parsed;
  return 1;
}

@immutable
class PurchaseOrderCharge {
  final int id;
  final int chgId;
  final String chgName;
  final String code;
  final double per;
  final double amt;
  final String mode;
  final int addLess; // 1 = Add, -1 = Less
  final String exp;
  final String remark;

  const PurchaseOrderCharge({
    this.id = 0,
    required this.chgId,
    this.chgName = '',
    this.code = '',
    this.per = 0.0,
    this.amt = 0.0,
    this.mode = 'PURCHASE',
    this.addLess = 1,
    this.exp = '',
    this.remark = '',
  });

  factory PurchaseOrderCharge.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderCharge(
      id: (json['id'] ?? 0) as int,
      chgId: (json['chgId'] ?? 0) as int,
      chgName: (json['chgName'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      per: (json['per'] as num?)?.toDouble() ?? 0.0,
      amt: (json['amt'] as num?)?.toDouble() ?? 0.0,
      mode: (json['mode'] ?? 'PURCHASE').toString(),
      addLess: _parseAddLess(json['addLess']),
      exp: (json['exp'] ?? '').toString(),
      remark: (json['remark'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toSaveJson() => {
    'chgId': chgId,
    'per': per,
    'amt': amt,
    'remark': remark,
  };
}

@immutable
class PurchaseOrderCondition {
  final int conId;
  final int conNo;
  final String code;
  final String conditionText;

  const PurchaseOrderCondition({
    this.conId = 0,
    required this.conNo,
    this.code = '',
    this.conditionText = '',
  });

  factory PurchaseOrderCondition.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderCondition(
      conId: (json['conId'] ?? 0) as int,
      conNo: (json['conNo'] ?? 0) as int,
      code: (json['code'] ?? '').toString(),
      conditionText: (json['conditionText'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toSaveJson() => {
    'conNo': conNo,
    'conditionText': conditionText,
  };
}

// ============================================================================
// LOOKUP MODELS
// ============================================================================

@immutable
class SupplierLookupItem {
  final int pCode;
  final String pName;
  final String gstin;
  final String stateCode;
  final String address;
  final int brkCode;
  final String agent;
  final String typeOfRegistrant;
  final int creditDays;

  const SupplierLookupItem({
    required this.pCode,
    required this.pName,
    this.gstin = '',
    this.stateCode = '',
    this.address = '',
    this.brkCode = 0,
    this.agent = '',
    this.typeOfRegistrant = '',
    this.creditDays = 0,
  });

  factory SupplierLookupItem.fromJson(Map<String, dynamic> json) {
    return SupplierLookupItem(
      pCode: (json['pCode'] ?? 0) as int,
      pName: (json['pName'] ?? '').toString(),
      gstin: (json['gstin'] ?? '').toString(),
      stateCode: (json['stateCode'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      brkCode: (json['brkCode'] ?? 0) as int,
      agent: (json['agent'] ?? '').toString(),
      typeOfRegistrant: (json['typeOfRegistrant'] ?? '').toString(),
      creditDays: (json['creditDays'] ?? 0) as int,
    );
  }
}

@immutable
class ItemLookupItem {
  final String iCode;
  final String itName;
  final int unitCode;
  final String unitName;
  final double stock;
  final String catName;
  final int catCode;
  final String hsn;
  final double taxSlab;
  final String shade;
  final int secUcode;
  final String secUnit;
  final double conversion;
  final String design;
  final String style;
  final String size;
  final bool sizeReq;
  final bool gradeReq;

  const ItemLookupItem({
    required this.iCode,
    required this.itName,
    this.unitCode = 0,
    this.unitName = '',
    this.stock = 0.0,
    this.catName = '',
    this.catCode = 0,
    this.hsn = '',
    this.taxSlab = 0.0,
    this.shade = '',
    this.secUcode = 0,
    this.secUnit = '',
    this.conversion = 1.0,
    this.design = '',
    this.style = '',
    this.size = '',
    this.sizeReq = false,
    this.gradeReq = false,
  });

  factory ItemLookupItem.fromJson(Map<String, dynamic> json) {
    return ItemLookupItem(
      iCode: (json['iCode'] ?? '').toString(),
      itName: (json['itName'] ?? '').toString(),
      unitCode: (json['unitCode'] ?? 0) as int,
      unitName: (json['unitName'] ?? '').toString(),
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
      catName: (json['catName'] ?? '').toString(),
      catCode: (json['catCode'] ?? 0) as int,
      hsn: (json['hsn'] ?? '').toString(),
      taxSlab: (json['taxSlab'] as num?)?.toDouble() ?? 0.0,
      shade: (json['shade'] ?? '').toString(),
      secUcode: (json['secUcode'] ?? 0) as int,
      secUnit: (json['secUnit'] ?? '').toString(),
      conversion: (json['conversion'] as num?)?.toDouble() ?? 1.0,
      design: (json['design'] ?? '').toString(),
      style: (json['style'] ?? '').toString(),
      size: (json['size'] ?? '').toString(),
      sizeReq: json['sizeReq'] == true,
      gradeReq: json['gradeReq'] == true,
    );
  }
}

@immutable
class ItemMergeLookupItem {
  final String mergeLotNo;
  final String shade;
  final String maker;
  final int makerCode;

  const ItemMergeLookupItem({
    required this.mergeLotNo,
    this.shade = '',
    this.maker = '',
    this.makerCode = 0,
  });

  factory ItemMergeLookupItem.fromJson(Map<String, dynamic> json) {
    return ItemMergeLookupItem(
      mergeLotNo: (json['mergeLotNo'] ?? '').toString(),
      shade: (json['shade'] ?? '').toString(),
      maker: (json['maker'] ?? '').toString(),
      makerCode: (json['makerCode'] ?? 0) as int,
    );
  }
}

@immutable
class PurchaseOrderLookupsData {
  final String nextPoNo;
  final String companyStateCode;
  final List<StoreLookupItem> stores;
  final List<String> currencies;
  final List<CapModeLookupItem> capModes;
  final List<DepartmentLookupItem> departments;
  final List<DivisionLookupItem> divisions;
  final List<ChargesMasterLookupItem> defaultCharges;
  final List<String> deliveryTermsSuggestions;
  final List<String> paymentTermsSuggestions;
  final List<String> dispatchInstructionsSuggestions;
  final List<String> specialNotesSuggestions;
  final List<String> remarksSuggestions;

  const PurchaseOrderLookupsData({
    this.nextPoNo = '',
    this.companyStateCode = '27',
    this.stores = const [],
    this.currencies = const [],
    this.capModes = const [],
    this.departments = const [],
    this.divisions = const [],
    this.defaultCharges = const [],
    this.deliveryTermsSuggestions = const [],
    this.paymentTermsSuggestions = const [],
    this.dispatchInstructionsSuggestions = const [],
    this.specialNotesSuggestions = const [],
    this.remarksSuggestions = const [],
  });

  factory PurchaseOrderLookupsData.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderLookupsData(
      nextPoNo: (json['nextPoNo'] ?? '').toString(),
      companyStateCode: (json['companyStateCode'] ?? '27').toString(),
      stores: (json['stores'] as List?)?.map((e) => StoreLookupItem.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      currencies: (json['currencies'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      capModes: (json['capModes'] as List?)?.map((e) => CapModeLookupItem.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      departments: (json['departments'] as List?)?.map((e) => DepartmentLookupItem.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      divisions: (json['divisions'] as List?)?.map((e) => DivisionLookupItem.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      defaultCharges: (json['defaultCharges'] as List?)?.map((e) => ChargesMasterLookupItem.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      deliveryTermsSuggestions: (json['deliveryTermsSuggestions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      paymentTermsSuggestions: (json['paymentTermsSuggestions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      dispatchInstructionsSuggestions: (json['dispatchInstructionsSuggestions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      specialNotesSuggestions: (json['specialNotesSuggestions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      remarksSuggestions: (json['remarksSuggestions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

@immutable
class StoreLookupItem {
  final int strCode;
  final String strName;

  const StoreLookupItem({required this.strCode, required this.strName});

  factory StoreLookupItem.fromJson(Map<String, dynamic> json) {
    return StoreLookupItem(
      strCode: (json['strCode'] ?? 0) as int,
      strName: (json['strName'] ?? '').toString(),
    );
  }
}

@immutable
class CapModeLookupItem {
  final int locCode;
  final String location;

  const CapModeLookupItem({required this.locCode, required this.location});

  factory CapModeLookupItem.fromJson(Map<String, dynamic> json) {
    return CapModeLookupItem(
      locCode: (json['locCode'] ?? 0) as int,
      location: (json['location'] ?? '').toString(),
    );
  }
}

@immutable
class DepartmentLookupItem {
  final int labCode;
  final String labName;

  const DepartmentLookupItem({required this.labCode, required this.labName});

  factory DepartmentLookupItem.fromJson(Map<String, dynamic> json) {
    return DepartmentLookupItem(
      labCode: (json['labCode'] ?? 0) as int,
      labName: (json['labName'] ?? '').toString(),
    );
  }
}

@immutable
class DivisionLookupItem {
  final int khCode;
  final String khName;

  const DivisionLookupItem({required this.khCode, required this.khName});

  factory DivisionLookupItem.fromJson(Map<String, dynamic> json) {
    return DivisionLookupItem(
      khCode: (json['khCode'] ?? 0) as int,
      khName: (json['khName'] ?? '').toString(),
    );
  }
}

@immutable
class ChargesMasterLookupItem {
  final int priority;
  final int chgId;
  final String chgName;
  final double disc;
  final int addLess;
  final String exp;

  const ChargesMasterLookupItem({
    required this.priority,
    required this.chgId,
    required this.chgName,
    this.disc = 0.0,
    this.addLess = 1,
    this.exp = '',
  });

  factory ChargesMasterLookupItem.fromJson(Map<String, dynamic> json) {
    return ChargesMasterLookupItem(
      priority: (json['priority'] ?? 0) as int,
      chgId: (json['chgId'] ?? 0) as int,
      chgName: (json['chgName'] ?? '').toString(),
      disc: (json['disc'] as num?)?.toDouble() ?? 0.0,
      addLess: _parseAddLess(json['addLess']),
      exp: (json['exp'] ?? '').toString(),
    );
  }
}

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
}
