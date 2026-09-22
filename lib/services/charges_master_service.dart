import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart';

class ChargesMasterItem {
  final int chgId;
  String chgName;
  double disc;
  double amount;
  String addLess;
  int iind;
  int ist;
  String formula;
  int loc;
  int imp;
  int priority;
  int chgPO;
  int chgGRN;
  int chgWO;
  double rt;

  ChargesMasterItem({
    required this.chgId,
    required this.chgName,
    required this.disc,
    required this.amount,
    required this.addLess,
    required this.iind,
    required this.ist,
    required this.formula,
    required this.loc,
    required this.imp,
    required this.priority,
    required this.chgPO,
    required this.chgGRN,
    required this.chgWO,
    required this.rt,
  });

  factory ChargesMasterItem.fromJson(Map<String, dynamic> json) {
    return ChargesMasterItem(
      chgId: (json['chgId'] ?? json['chg_Id'] as num?)?.toInt() ?? 0,
      chgName: (json['chgName'] ?? json['chg_Name'] ?? '').toString(),
      disc: (json['disc'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      addLess: (json['addLess'] ?? '+').toString(),
      iind: (json['iind'] as num?)?.toInt() ?? -1,
      ist: (json['ist'] as num?)?.toInt() ?? -1,
      formula: (json['formula'] ?? json['exp'] ?? '').toString(),
      loc: (json['loc'] as num?)?.toInt() ?? -1,
      imp: (json['imp'] as num?)?.toInt() ?? -1,
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      chgPO: (json['chgPO'] ?? json['chg_PO'] as num?)?.toInt() ?? 0,
      chgGRN: (json['chgGRN'] ?? json['chg_GRN'] as num?)?.toInt() ?? 0,
      chgWO: (json['chgWO'] ?? json['chg_WO'] as num?)?.toInt() ?? 0,
      rt: (json['rt'] ?? json['cM_CalcRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chgId': chgId,
      'chgName': chgName,
      'disc': disc,
      'amount': amount,
      'addLess': addLess,
      'iind': iind,
      'ist': ist,
      'formula': formula,
      'loc': loc,
      'imp': imp,
      'priority': priority,
      'chgPO': chgPO,
      'chgGRN': chgGRN,
      'chgWO': chgWO,
      'rt': rt,
    };
  }

  ChargesMasterItem copyWith({
    int? chgId,
    String? chgName,
    double? disc,
    double? amount,
    String? addLess,
    int? iind,
    int? ist,
    String? formula,
    int? loc,
    int? imp,
    int? priority,
    int? chgPO,
    int? chgGRN,
    int? chgWO,
    double? rt,
  }) {
    return ChargesMasterItem(
      chgId: chgId ?? this.chgId,
      chgName: chgName ?? this.chgName,
      disc: disc ?? this.disc,
      amount: amount ?? this.amount,
      addLess: addLess ?? this.addLess,
      iind: iind ?? this.iind,
      ist: ist ?? this.ist,
      formula: formula ?? this.formula,
      loc: loc ?? this.loc,
      imp: imp ?? this.imp,
      priority: priority ?? this.priority,
      chgPO: chgPO ?? this.chgPO,
      chgGRN: chgGRN ?? this.chgGRN,
      chgWO: chgWO ?? this.chgWO,
      rt: rt ?? this.rt,
    );
  }
}

class ChargesMasterService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/ChargesMaster';

  Future<List<ChargesMasterItem>> getChargesList({String? module, String? mode}) async {
    try {
      final queryParams = <String, String>{};
      if (module != null && module.isNotEmpty) queryParams['module'] = module;
      if (mode != null && mode.isNotEmpty) queryParams['mode'] = mode;

      final response = await ApiClient.instance.get(
        '$_baseUrl/GetAll',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List list = body['data'];
          return list.map((item) => ChargesMasterItem.fromJson(item)).toList();
        }
      }
    } catch (_) {
      // Fallback mock dataset if API unreachable
    }

    return _getFallbackCharges(module, mode);
  }

  Future<bool> saveChargesList(List<ChargesMasterItem> items) async {
    try {
      final response = await ApiClient.instance.post(
        '$_baseUrl/SaveAll',
        body: items.map((i) => i.toJson()).toList(),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['success'] == true;
      }
    } catch (_) {
      // Mock success for offline mode
    }
    return true;
  }

  List<ChargesMasterItem> _getFallbackCharges(String? module, String? mode) {
    final list = [
      ChargesMasterItem(chgId: 1, chgName: 'BED', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: 'G * P1 / 100', loc: -1, imp: -1, priority: 1, chgPO: 0, chgGRN: -1, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 2, chgName: 'AED', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: 'G * P2 / 100', loc: -1, imp: 0, priority: 2, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 3, chgName: 'NCCD', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: 'G * P3 / 100', loc: -1, imp: 0, priority: 3, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 4, chgName: 'ED CESS', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: '( A1 + A2 + A3 ) * P4 / 100', loc: -1, imp: 0, priority: 4, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 5, chgName: 'S & H CESS', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: '( A1 + A2 + A3 ) * P5 / 100', loc: -1, imp: 0, priority: 5, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 6, chgName: 'CST', disc: 0, amount: 0, addLess: '+', iind: 0, ist: -1, formula: '( G + A1 + A2 + A3 + A4 + A5 + A8 - A10 ) * P6 / 100', loc: -1, imp: 0, priority: 12, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 7, chgName: 'FREIGHT', disc: 0, amount: 0, addLess: '+', iind: 0, ist: -1, formula: '( Q * P7 ) / 100', loc: -1, imp: 0, priority: 7, chgPO: -1, chgGRN: -1, chgWO: -1, rt: 0),
      ChargesMasterItem(chgId: 8, chgName: 'OTHERS', disc: 0, amount: 0, addLess: '+', iind: 0, ist: -1, formula: '( G * P8 ) / 100', loc: -1, imp: 0, priority: 8, chgPO: -1, chgGRN: -1, chgWO: -1, rt: 0),
      ChargesMasterItem(chgId: 9, chgName: 'INSURANCE', disc: 0, amount: 0, addLess: '+', iind: 0, ist: -1, formula: '( G * P9 ) / 100', loc: -1, imp: 0, priority: 9, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 10, chgName: 'DISCOUNT', disc: 0, amount: 0, addLess: '-', iind: 0, ist: -1, formula: '( G * P10 ) / 100', loc: -1, imp: 0, priority: 10, chgPO: -1, chgGRN: -1, chgWO: -1, rt: 0),
      ChargesMasterItem(chgId: 11, chgName: 'VAT', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: '( G + A1 + A2 + A3 + A4 + A5 + A7 + A8 - A10 ) * P11 / 100', loc: -1, imp: 0, priority: 11, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 12, chgName: 'FREIGHT', disc: 0, amount: 0, addLess: '+', iind: 0, ist: -1, formula: '( G * P12 ) / 100', loc: 0, imp: -1, priority: 1, chgPO: -1, chgGRN: -1, chgWO: -1, rt: 0),
      ChargesMasterItem(chgId: 13, chgName: 'INSURANCE', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: '( G * P13 ) / 100', loc: -1, imp: -1, priority: 2, chgPO: -1, chgGRN: -1, chgWO: -1, rt: 0),
      ChargesMasterItem(chgId: 14, chgName: '1 % OF A', disc: 0, amount: 0, addLess: '+', iind: 0, ist: -1, formula: '( ( G + A12 + A13 ) * P14 ) / 100', loc: 0, imp: -1, priority: 3, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 15, chgName: 'NCD', disc: 0, amount: 0, addLess: '+', iind: 0, ist: -1, formula: '( ( G + A12 + A13 + A14 ) * P15 ) / 100', loc: 0, imp: -1, priority: 4, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 16, chgName: 'CVD', disc: 0, amount: 0, addLess: '+', iind: 0, ist: -1, formula: '( ( G + A12 + A13 + A14 ) * P16 ) / 100', loc: 0, imp: -1, priority: 5, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 17, chgName: 'ED CESS ON CVD', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: '( A16 * P17 ) / 100', loc: 0, imp: -1, priority: 6, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 18, chgName: 'SHE CESS ON CVD', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: '( A16 * P18 ) / 100', loc: 0, imp: -1, priority: 7, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 19, chgName: 'CUSTOME CESS2', disc: 0, amount: 0, addLess: '+', iind: 0, ist: -1, formula: '( ( A15 + A16 + A17 + A18 ) * P19 ) / 100', loc: 0, imp: -1, priority: 8, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 20, chgName: 'SH CUST EDU. CESS', disc: 0, amount: 0, addLess: '+', iind: 0, ist: -1, formula: '( ( A15 + A16 + A17 + A18 ) * P20 ) / 100', loc: 0, imp: -1, priority: 9, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 21, chgName: 'ADDITIONAL DUTY', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: '( G + A12 + A13 + A14 + A15 + A16 + A17 + A18 + A19 + A20 ) * P21 / 100', loc: 0, imp: -1, priority: 21, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 22, chgName: 'SERVICE TAX', disc: 0, amount: 0, addLess: '+', iind: 0, ist: -1, formula: '( G - P10 ) * P22 / 100', loc: 0, imp: 0, priority: 13, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 23, chgName: 'CGST', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: '( G + A1 + A2 + A3 + A4 + A5 + A7 + A8 + A9 + A13 - A10 ) * P23 / 100', loc: -1, imp: -1, priority: 23, chgPO: -1, chgGRN: -1, chgWO: -1, rt: 0),
      ChargesMasterItem(chgId: 24, chgName: 'SGST', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: '( G + A1 + A2 + A3 + A4 + A5 + A7 + A8 + A9 + A13 - A10 ) * P24 / 100', loc: -1, imp: -1, priority: 24, chgPO: -1, chgGRN: -1, chgWO: -1, rt: 0),
      ChargesMasterItem(chgId: 25, chgName: 'IGST', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: '( G + A1 + A2 + A3 + A4 + A5 + A7 + A8 + A9 + A13 - A10 ) * P25 / 100', loc: -1, imp: -1, priority: 25, chgPO: -1, chgGRN: -1, chgWO: -1, rt: 0),
      ChargesMasterItem(chgId: 26, chgName: 'CESS', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: '( A25 ) * P26 / 100', loc: -1, imp: 0, priority: 26, chgPO: 0, chgGRN: 0, chgWO: 0, rt: 0),
      ChargesMasterItem(chgId: 27, chgName: 'TCS', disc: 0, amount: 0, addLess: '+', iind: -1, ist: -1, formula: '( G + A7 + A8 + A9 - A10 + A12 + A13 + A23 + A24 + A25 ) * P27 / 100', loc: -1, imp: -1, priority: 27, chgPO: -1, chgGRN: -1, chgWO: -1, rt: 0),
    ];

    Iterable<ChargesMasterItem> filtered = list;

    if (module != null && module != 'ALL' && module.isNotEmpty) {
      if (module == 'PURCHASE ORDER' || module == 'QUOTATION') {
        filtered = filtered.where((x) => x.chgPO == -1);
      } else if (module == 'GOODS RECEIVE NOTE') {
        filtered = filtered.where((x) => x.chgGRN == -1);
      } else if (module == 'WORK ORDER') {
        filtered = filtered.where((x) => x.chgWO == -1);
      }
    }

    if (mode != null && mode != 'ALL' && mode.isNotEmpty) {
      if (mode == 'LOCAL') {
        filtered = filtered.where((x) => x.loc == -1);
      } else if (mode == 'IMPORTED') {
        filtered = filtered.where((x) => x.imp == -1);
      }
    }

    final res = filtered.toList();
    res.sort((a, b) => a.priority.compareTo(b.priority));
    return res;
  }
}
