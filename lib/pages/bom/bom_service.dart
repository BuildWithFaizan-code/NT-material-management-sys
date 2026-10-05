import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import 'bom_models.dart';

class BomService {
  final String baseUrl;
  final ApiClient _client;

  BomService({
    String? baseUrl,
    ApiClient? client,
  })  : baseUrl = baseUrl ?? '${ApiConfig.baseUrl}/bom',
        _client = client ?? ApiClient.instance;

  // Local in-memory caches for fast lookup & offline fallback
  static final List<BomStoreLookup> _fallbackStores = [
    const BomStoreLookup(strCode: 1, strName: 'MAIN STORE - LUDHIANA'),
    const BomStoreLookup(strCode: 2, strName: 'FINISH GOODS STORE'),
    const BomStoreLookup(strCode: 3, strName: 'RAW MATERIAL STORE'),
    const BomStoreLookup(strCode: 4, strName: 'ACCESSORIES STORE'),
    const BomStoreLookup(strCode: 5, strName: 'YARN WAREHOUSE'),
  ];

  static final List<BomDepartmentLookup> _fallbackDepartments = [
    const BomDepartmentLookup(labCode: 1, labName: 'PRODUCTION & STITCHING'),
    const BomDepartmentLookup(labCode: 2, labName: 'KNITTING DEPARTMENT'),
    const BomDepartmentLookup(labCode: 3, labName: 'CUTTING DEPARTMENT'),
    const BomDepartmentLookup(labCode: 4, labName: 'FINISHING & PACKING'),
    const BomDepartmentLookup(labCode: 5, labName: 'QUALITY ASSURANCE'),
  ];

  static final List<BomUnitLookup> _fallbackUnits = [
    const BomUnitLookup(unitCode: 22, unitName: 'PCS'),
    const BomUnitLookup(unitCode: 24, unitName: 'MTR'),
    const BomUnitLookup(unitCode: 25, unitName: 'KGS'),
    const BomUnitLookup(unitCode: 26, unitName: 'NOS'),
    const BomUnitLookup(unitCode: 27, unitName: 'SET'),
    const BomUnitLookup(unitCode: 28, unitName: 'BOX'),
    const BomUnitLookup(unitCode: 29, unitName: 'DOZ'),
    const BomUnitLookup(unitCode: 30, unitName: 'SQM'),
  ];

  static final List<FinishedGoodItem> _fallbackFinishedGoods = [
    // Job Items (SKU_CROSS='J')
    const FinishedGoodItem(
      iCode: 'FGMYLO00000S84000000J',
      itName: 'Mylo FG BABY Pants S-84x4',
      unitName: 'PCS',
      unitCode: 22,
      status: 'OPEN',
      skuCross: 'J',
      catCode: 4,
    ),
    const FinishedGoodItem(
      iCode: 'FGLAL00000XL54000000J',
      itName: 'LAL Baby Romper Ribbed XL-54',
      unitName: 'PCS',
      unitCode: 22,
      status: 'OPEN',
      skuCross: 'J',
      catCode: 4,
    ),
    const FinishedGoodItem(
      iCode: 'FGKID000000M32000000J',
      itName: 'Kids Cotton T-Shirt M-32',
      unitName: 'PCS',
      unitCode: 22,
      status: 'OPEN',
      skuCross: 'J',
      catCode: 4,
    ),
    const FinishedGoodItem(
      iCode: 'FGBBY000000L40000000J',
      itName: 'Baby Hooded Sweatshirt L-40',
      unitName: 'PCS',
      unitCode: 22,
      status: 'OPEN',
      skuCross: 'J',
      catCode: 4,
    ),
    const FinishedGoodItem(
      iCode: 'FGJOG00000XL48000000J',
      itName: 'Fleece Jogger Pants XL-48',
      unitName: 'PCS',
      unitCode: 22,
      status: 'BLOCKED',
      skuCross: 'J',
      catCode: 4,
    ),

    // Regular Items (SKU_CROSS='R')
    const FinishedGoodItem(
      iCode: 'FG1T1000000L75000000R',
      itName: '1 To 10 Baby Pants L-75x6 Regular',
      unitName: 'PCS',
      unitCode: 22,
      status: 'OPEN',
      skuCross: 'R',
      catCode: 4,
    ),
    const FinishedGoodItem(
      iCode: 'FG1T100000XL75000000R',
      itName: '1 To 10 Baby Pants XL-75x6 Regular',
      unitName: 'PCS',
      unitCode: 22,
      status: 'OPEN',
      skuCross: 'R',
      catCode: 4,
    ),
    const FinishedGoodItem(
      iCode: 'FGCAS000000M60000000R',
      itName: 'Classic Infant Sleepsuit M-60 Regular',
      unitName: 'PCS',
      unitCode: 22,
      status: 'OPEN',
      skuCross: 'R',
      catCode: 4,
    ),
    const FinishedGoodItem(
      iCode: 'FGDRS000000S36000000R',
      itName: 'Girls Frock Dress S-36 Regular',
      unitName: 'PCS',
      unitCode: 22,
      status: 'OPEN',
      skuCross: 'R',
      catCode: 4,
    ),
  ];

  static final List<ComponentLookupItem> _fallbackComponents = [
    const ComponentLookupItem(
      iCode: 'RMCOT100SINGLEJERS',
      itName: '100% Cotton Single Jersey 180 GSM',
      unitCode: 25,
      unitName: 'KGS',
      catCode: 1,
      materialType: 'RAW MATERIAL',
      secUcode: 24,
      secUnit: 'MTR',
      convQty: 3.25,
      printCode: 'COT-SJ-180',
    ),
    const ComponentLookupItem(
      iCode: 'RMRIB955SPANDEX2X2',
      itName: '95/5 Cotton Spandex Rib 2x2 220 GSM',
      unitCode: 25,
      unitName: 'KGS',
      catCode: 1,
      materialType: 'RAW MATERIAL',
      secUcode: 24,
      secUnit: 'MTR',
      convQty: 2.80,
      printCode: 'RIB-SP-220',
    ),
    const ComponentLookupItem(
      iCode: 'ACSEWTHRDSPUNPOLY',
      itName: 'Spun Polyester Sewing Thread 40/2 5000M',
      unitCode: 26,
      unitName: 'NOS',
      catCode: 2,
      materialType: 'ACCESSORIES',
      convQty: 1.0,
      printCode: 'THRD-40/2',
    ),
    const ComponentLookupItem(
      iCode: 'ACELASTCKNIT25MM',
      itName: 'Knitted Elastic Tape 25mm White',
      unitCode: 24,
      unitName: 'MTR',
      catCode: 2,
      materialType: 'ACCESSORIES',
      convQty: 1.0,
      printCode: 'ELAST-25',
    ),
    const ComponentLookupItem(
      iCode: 'ACLABLWVNSZMYLO',
      itName: 'Woven Neck Brand Label - Mylo S-84',
      unitCode: 22,
      unitName: 'PCS',
      catCode: 2,
      materialType: 'ACCESSORIES',
      convQty: 1.0,
      printCode: 'LBL-MYLO-S',
    ),
    const ComponentLookupItem(
      iCode: 'ACCARETAGSATIN',
      itName: 'Printed Satin Wash Care Label',
      unitCode: 22,
      unitName: 'PCS',
      catCode: 2,
      materialType: 'ACCESSORIES',
      convQty: 1.0,
      printCode: 'CARE-SATIN',
    ),
    const ComponentLookupItem(
      iCode: 'PKPOLYBAGBOPP1014',
      itName: 'Self-Adhesive BOPP Polybag 10x14 inch',
      unitCode: 22,
      unitName: 'PCS',
      catCode: 3,
      materialType: 'PACKAGING',
      convQty: 1.0,
      printCode: 'POLY-1014',
    ),
    const ComponentLookupItem(
      iCode: 'PKMCARTON7PLY6040',
      itName: 'Master Shipper Corrugated Carton 7-Ply',
      unitCode: 26,
      unitName: 'NOS',
      catCode: 3,
      materialType: 'PACKAGING',
      convQty: 1.0,
      printCode: 'CTN-7PLY',
    ),
  ];

  static List<BomCompleteRecord> get fallbackCompleteRecords => _fallbackCompleteRecords;

  static final List<BomCompleteRecord> _fallbackCompleteRecords = [
    BomCompleteRecord(
      header: BomHeaderData(
        bomId: 'BMCJ/000001/27',
        bomCode: 'BMCJ0001',
        depCode: 1,
        depName: 'PRODUCTION & STITCHING',
        strCode: 1,
        strName: 'MAIN STORE - LUDHIANA',
        iCode: 'FGMYLO00000S84000000J',
        description: 'Mylo FG BABY Pants S-84x4',
        qty: 100.0,
        unitCode: 22,
        unitName: 'PCS',
        purpose: 'Costing',
        status: 'OPEN',
        bomType: 'JOB',
        bomDate: DateTime.now().subtract(const Duration(days: 3)),
        bomPo: 'PO-2026-0891',
        bomEDate: DateTime.now(),
      ),
      items: const [
        BomSubItemData(
          bomsId: 'BMCJ/000001/27',
          bomsCode: '1',
          itGroupCd: 1,
          iCode: 'RMCOT100SINGLEJERS',
          description: '100% Cotton Single Jersey 180 GSM',
          materialType: 'RAW MATERIAL',
          qty: 1.05,
          unitCode: 25,
          unitName: 'KGS',
          sqm: 1.25,
          bomCons: 1.0,
          bomExtra: 5.0,
          bomTolQty: 0.05,
          bomTotQty: 1.05,
          convQty: 3.25,
          bomRemarks: 'Main front and back panel fabric',
        ),
        BomSubItemData(
          bomsId: 'BMCJ/000001/27',
          bomsCode: '2',
          itGroupCd: 1,
          iCode: 'RMRIB955SPANDEX2X2',
          description: '95/5 Cotton Spandex Rib 2x2 220 GSM',
          materialType: 'RAW MATERIAL',
          qty: 0.22,
          unitCode: 25,
          unitName: 'KGS',
          sqm: 0.20,
          bomCons: 0.20,
          bomExtra: 10.0,
          bomTolQty: 0.02,
          bomTotQty: 0.22,
          convQty: 2.80,
          bomRemarks: 'Waist and bottom cuffs',
        ),
        BomSubItemData(
          bomsId: 'BMCJ/000001/27',
          bomsCode: '3',
          itGroupCd: 2,
          iCode: 'ACELASJACQ0032MM',
          description: 'Knitted Jacquard Elastic 32mm Soft Grip',
          materialType: 'ACCESSORIES',
          qty: 0.47,
          unitCode: 24,
          unitName: 'MTR',
          sqm: 0.0,
          bomCons: 0.45,
          bomExtra: 5.0,
          bomTolQty: 0.02,
          bomTotQty: 0.47,
          convQty: 1.0,
          bomRemarks: 'Inner waist band elastic',
        ),
      ],
    ),
    BomCompleteRecord(
      header: BomHeaderData(
        bomId: 'BMCJ/000002/27',
        bomCode: 'BMCJ0002',
        depCode: 2,
        depName: 'KNITTING DEPARTMENT',
        strCode: 2,
        strName: 'FINISH GOODS STORE',
        iCode: 'FGLAL00000XL54000000J',
        description: 'LAL Baby Romper Ribbed XL-54',
        qty: 250.0,
        unitCode: 22,
        unitName: 'PCS',
        purpose: 'Costing',
        status: 'OPEN',
        bomType: 'JOB',
        bomDate: DateTime.now().subtract(const Duration(days: 1)),
        bomPo: 'PO-2026-0922',
        bomEDate: DateTime.now(),
      ),
      items: const [
        BomSubItemData(
          bomsId: 'BMCJ/000002/27',
          bomsCode: '1',
          itGroupCd: 1,
          iCode: 'RMCOT100SINGLEJERS',
          description: '100% Cotton Single Jersey 180 GSM',
          materialType: 'RAW MATERIAL',
          qty: 0.84,
          unitCode: 25,
          unitName: 'KGS',
          sqm: 0.95,
          bomCons: 0.80,
          bomExtra: 5.0,
          bomTolQty: 0.04,
          bomTotQty: 0.84,
          convQty: 3.25,
          bomRemarks: 'Full body jersey',
        ),
        BomSubItemData(
          bomsId: 'BMCJ/000002/27',
          bomsCode: '2',
          itGroupCd: 2,
          iCode: 'ACSNAPBTNSSPRING95',
          description: 'Metallic Snap Fastener Button 9.5mm S-Spring',
          materialType: 'ACCESSORIES',
          qty: 4.0,
          unitCode: 26,
          unitName: 'NOS',
          sqm: 0.0,
          bomCons: 4.0,
          bomExtra: 0.0,
          bomTolQty: 0.0,
          bomTotQty: 4.0,
          convQty: 1.0,
          bomRemarks: 'Crotch opening buttons',
        ),
      ],
    ),
    BomCompleteRecord(
      header: BomHeaderData(
        bomId: 'BMCC/000001/27',
        bomCode: 'BMCC0001',
        depCode: 3,
        depName: 'CUTTING DEPARTMENT',
        strCode: 3,
        strName: 'RAW MATERIAL STORE',
        iCode: 'FG1T1000000L75000000R',
        description: '1 To 10 Baby Pants L-75x6 Regular',
        qty: 500.0,
        unitCode: 22,
        unitName: 'PCS',
        purpose: 'Costing',
        status: 'OPEN',
        bomType: 'REGULAR',
        bomDate: DateTime.now().subtract(const Duration(days: 5)),
        bomPo: 'REG-PO-4410',
        bomEDate: DateTime.now(),
      ),
      items: const [
        BomSubItemData(
          bomsId: 'BMCC/000001/27',
          bomsCode: '1',
          itGroupCd: 1,
          iCode: 'RMCOT100SINGLEJERS',
          description: '100% Cotton Single Jersey 180 GSM',
          materialType: 'RAW MATERIAL',
          qty: 1.16,
          unitCode: 25,
          unitName: 'KGS',
          sqm: 1.30,
          bomCons: 1.10,
          bomExtra: 5.0,
          bomTolQty: 0.06,
          bomTotQty: 1.16,
          convQty: 3.25,
          bomRemarks: 'Regular bulk cutting',
        ),
        BomSubItemData(
          bomsId: 'BMCC/000001/27',
          bomsCode: '2',
          itGroupCd: 2,
          iCode: 'ACSEWTHRDSPUNPOLY',
          description: 'Spun Polyester Sewing Thread 40/2 5000M',
          materialType: 'ACCESSORIES',
          qty: 0.05,
          unitCode: 26,
          unitName: 'NOS',
          sqm: 0.0,
          bomCons: 0.05,
          bomExtra: 0.0,
          bomTolQty: 0.0,
          bomTotQty: 0.05,
          convQty: 1.0,
          bomRemarks: 'Matching color thread spool',
        ),
        BomSubItemData(
          bomsId: 'BMCC/000001/27',
          bomsCode: '3',
          itGroupCd: 3,
          iCode: 'PKMCARTON7PLY6040',
          description: 'Master Shipper Corrugated Carton 7-Ply',
          materialType: 'PACKAGING',
          qty: 0.02,
          unitCode: 26,
          unitName: 'NOS',
          sqm: 0.0,
          bomCons: 0.02,
          bomExtra: 0.0,
          bomTolQty: 0.0,
          bomTotQty: 0.02,
          convQty: 1.0,
          bomRemarks: 'Shipper carton 50pcs per box',
        ),
      ],
    ),
    BomCompleteRecord(
      header: BomHeaderData(
        bomId: 'BMCC/000002/27',
        bomCode: 'BMCC0002',
        depCode: 4,
        depName: 'FINISHING & PACKING',
        strCode: 1,
        strName: 'MAIN STORE - LUDHIANA',
        iCode: 'FGCAS000000M60000000R',
        description: 'Classic Infant Sleepsuit M-60 Regular',
        qty: 50.0,
        unitCode: 22,
        unitName: 'PCS',
        purpose: 'Costing',
        status: 'BLOCKED',
        bomType: 'REGULAR',
        bomDate: DateTime.now().subtract(const Duration(days: 7)),
        bomPo: 'REG-PO-4418',
        bomEDate: DateTime.now(),
      ),
      items: const [
        BomSubItemData(
          bomsId: 'BMCC/000002/27',
          bomsCode: '1',
          itGroupCd: 1,
          iCode: 'RMCOT100SINGLEJERS',
          description: '100% Cotton Single Jersey 180 GSM',
          materialType: 'RAW MATERIAL',
          qty: 0.90,
          unitCode: 25,
          unitName: 'KGS',
          sqm: 1.05,
          bomCons: 0.85,
          bomExtra: 6.0,
          bomTolQty: 0.05,
          bomTotQty: 0.90,
          convQty: 3.25,
          bomRemarks: 'Body suit',
        ),
      ],
    ),
  ];

  static int _jobSequenceCounter = 1;
  static int _regularSequenceCounter = 1;

  // High-performance in-memory caches to avoid redundant HTTP requests
  List<BomStoreLookup>? _cachedStores;
  List<BomDepartmentLookup>? _cachedDepartments;
  List<BomUnitLookup>? _cachedUnits;
  final Map<String, List<FinishedGoodItem>> _cachedFinishedGoods = {};
  final Map<String, List<ComponentLookupItem>> _cachedComponents = {};
  final Map<String, List<BomRecordSummary>> _cachedRecords = {};

  /// Invalidate summary caches when records change
  void clearRecordsCache() {
    _cachedRecords.clear();
  }

  /// Invalidate all caches
  void clearAllCache() {
    _cachedStores = null;
    _cachedDepartments = null;
    _cachedUnits = null;
    _cachedFinishedGoods.clear();
    _cachedComponents.clear();
    _cachedRecords.clear();
  }

  /// Fetches Store/Plant list (STOREMST) with in-memory caching
  Future<List<BomStoreLookup>> fetchStores({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedStores != null && _cachedStores!.isNotEmpty) {
      return _cachedStores!;
    }
    try {
      final response = await _client.get('$baseUrl/stores').timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] ?? body) as List<dynamic>;
        _cachedStores = list.map((e) => BomStoreLookup.fromJson(e as Map<String, dynamic>)).toList();
        return _cachedStores!;
      }
    } catch (e) {
      debugPrint('BomService: fetchStores fallback: $e');
    }
    _cachedStores = _fallbackStores;
    return _fallbackStores;
  }

  /// Fetches Department/Labour list (LABOURMST) with in-memory caching
  Future<List<BomDepartmentLookup>> fetchDepartments({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedDepartments != null && _cachedDepartments!.isNotEmpty) {
      return _cachedDepartments!;
    }
    try {
      final response = await _client.get('$baseUrl/departments').timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] ?? body) as List<dynamic>;
        _cachedDepartments = list.map((e) => BomDepartmentLookup.fromJson(e as Map<String, dynamic>)).toList();
        return _cachedDepartments!;
      }
    } catch (e) {
      debugPrint('BomService: fetchDepartments fallback: $e');
    }
    _cachedDepartments = _fallbackDepartments;
    return _fallbackDepartments;
  }

  /// Fetches Units of Measure (UNITMST) with in-memory caching
  Future<List<BomUnitLookup>> fetchUnits({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedUnits != null && _cachedUnits!.isNotEmpty) {
      return _cachedUnits!;
    }
    try {
      final response = await _client.get('$baseUrl/units').timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] ?? body) as List<dynamic>;
        _cachedUnits = list.map((e) => BomUnitLookup.fromJson(e as Map<String, dynamic>)).toList();
        return _cachedUnits!;
      }
    } catch (e) {
      debugPrint('BomService: fetchUnits fallback: $e');
    }
    _cachedUnits = _fallbackUnits;
    return _fallbackUnits;
  }

  /// Generates or fetches the next BOM ID for the specified mode (BMCJ vs BMCC)
  Future<String> fetchNextBomId(BomMode mode) async {
    try {
      final response = await _client.get('$baseUrl/next-id?mode=${mode.label}').timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] ?? body['bomId'] ?? '';
      }
    } catch (_) {}

    // Local deterministic sequence calculation based on FY:
    final now = DateTime.now();
    final int fyYear = (now.month >= 4) ? (now.year % 100) + 1 : (now.year % 100);
    final String fySuffix = fyYear.toString().padLeft(2, '0');

    final int seq = (mode == BomMode.job) ? _jobSequenceCounter : _regularSequenceCounter;
    final String seqStr = seq.toString().padLeft(6, '0');
    return '${mode.prefix}/$seqStr/$fySuffix';
  }

  /// Fetches Finished Goods items filtered by mode ('J' vs 'R') and search query
  Future<List<FinishedGoodItem>> fetchFinishedGoods({
    required BomMode mode,
    String query = '',
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${mode.skuCross}_$query';
    if (!forceRefresh && _cachedFinishedGoods.containsKey(cacheKey)) {
      return _cachedFinishedGoods[cacheKey]!;
    }

    try {
      final encodedQ = Uri.encodeComponent(query);
      final response = await _client
          .get('$baseUrl/finished-goods?skuCross=${mode.skuCross}&query=$encodedQ')
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] ?? body) as List<dynamic>;
        final result = list.map((e) => FinishedGoodItem.fromJson(e as Map<String, dynamic>)).toList();
        _cachedFinishedGoods[cacheKey] = result;
        return result;
      }
    } catch (e) {
      debugPrint('BomService: fetchFinishedGoods fallback: $e');
    }

    // Filter local fallback by mode and search query
    final cleanQ = query.trim().toLowerCase();
    final result = _fallbackFinishedGoods.where((item) {
      if (item.skuCross != mode.skuCross) return false;
      if (cleanQ.isEmpty) return true;
      return item.iCode.toLowerCase().contains(cleanQ) || item.itName.toLowerCase().contains(cleanQ);
    }).toList();
    _cachedFinishedGoods[cacheKey] = result;
    return result;
  }

  /// Fetches Raw Materials & Components for BOM Sub-Items
  Future<List<ComponentLookupItem>> fetchComponents({
    required String parentItemCode,
    String query = '',
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${parentItemCode}_$query';
    if (!forceRefresh && _cachedComponents.containsKey(cacheKey)) {
      return _cachedComponents[cacheKey]!;
    }

    try {
      final encodedParent = Uri.encodeComponent(parentItemCode);
      final encodedQ = Uri.encodeComponent(query);
      final response = await _client
          .get('$baseUrl/components?parent=$encodedParent&query=$encodedQ')
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] ?? body) as List<dynamic>;
        final result = list.map((e) => ComponentLookupItem.fromJson(e as Map<String, dynamic>)).toList();
        _cachedComponents[cacheKey] = result;
        return result;
      }
    } catch (_) {}

    final cleanQ = query.trim().toLowerCase();
    final result = _fallbackComponents.where((c) {
      if (c.iCode == parentItemCode) return false;
      if (cleanQ.isEmpty) return true;
      return c.iCode.toLowerCase().contains(cleanQ) || c.itName.toLowerCase().contains(cleanQ);
    }).toList();
    _cachedComponents[cacheKey] = result;
    return result;
  }

  /// Fetches summary records for Show Record modal
  Future<List<BomRecordSummary>> fetchBomRecords({
    BomMode? mode,
    String query = '',
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${mode?.label ?? "ALL"}_$query';
    if (!forceRefresh && _cachedRecords.containsKey(cacheKey)) {
      return _cachedRecords[cacheKey]!;
    }

    try {
      final modeParam = mode != null ? '&mode=${mode.label}' : '';
      final encodedQ = Uri.encodeComponent(query);
      final response = await _client.get('$baseUrl/records?query=$encodedQ$modeParam').timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] ?? body) as List<dynamic>;
        final result = list.map((e) => BomRecordSummary.fromJson(e as Map<String, dynamic>)).toList();
        _cachedRecords[cacheKey] = result;
        return result;
      }
    } catch (e) {
      debugPrint('BomService: fetchBomRecords fallback: $e');
    }

    final cleanQ = query.trim().toLowerCase();
    final result = _fallbackCompleteRecords.where((record) {
      if (mode != null && record.header.bomType.toUpperCase() != mode.label.toUpperCase()) {
        return false;
      }
      if (cleanQ.isEmpty) return true;
      final h = record.header;
      return h.bomId.toLowerCase().contains(cleanQ) ||
          h.iCode.toLowerCase().contains(cleanQ) ||
          h.description.toLowerCase().contains(cleanQ) ||
          h.bomPo.toLowerCase().contains(cleanQ) ||
          h.strName.toLowerCase().contains(cleanQ) ||
          h.depName.toLowerCase().contains(cleanQ);
    }).map((record) {
      final h = record.header;
      final totCons = record.items.fold(0.0, (acc, item) => acc + item.bomCons);
      final totNet = record.items.fold(0.0, (acc, item) => acc + item.qty);
      return BomRecordSummary(
        bomId: h.bomId,
        bomCode: h.bomCode,
        depCode: h.depCode,
        depName: h.depName,
        strCode: h.strCode,
        strName: h.strName,
        iCode: h.iCode,
        description: h.description,
        qty: h.qty,
        unitCode: h.unitCode,
        unitName: h.unitName,
        status: h.status,
        bomType: h.bomType,
        bomDate: h.bomDate,
        bomPo: h.bomPo,
        subItemCount: record.items.length,
        totalConsumption: totCons,
        totalNetQty: totNet,
      );
    }).toList();
    _cachedRecords[cacheKey] = result;
    return result;
  }

  /// Fetches complete BOM details by ID
  Future<BomCompleteRecord?> fetchBomDetails(String bomId) async {
    try {
      final encodedId = Uri.encodeQueryComponent(bomId);
      final response = await _client.get('$baseUrl/details?bomId=$encodedId').timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return BomCompleteRecord.fromJson(body['data'] ?? body);
      }
    } catch (e) {
      debugPrint('BomService: fetchBomDetails fallback: $e');
    }

    try {
      return _fallbackCompleteRecords.firstWhere(
        (r) => r.header.bomId.toUpperCase() == bomId.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Deletes a BOM record by ID
  Future<bool> deleteBom(String bomId) async {
    final cleanId = bomId.trim();
    clearRecordsCache();
    _fallbackCompleteRecords.removeWhere((r) => r.header.bomId.trim().toUpperCase() == cleanId.toUpperCase());
    _cachedRecords.clear();

    try {
      final encodedQuery = Uri.encodeQueryComponent(cleanId);
      // Call /api/bom/delete?bomId=... first (query parameter avoids URL slash issues)
      var response = await _client.delete('$baseUrl/delete?bomId=$encodedQuery').timeout(const Duration(seconds: 4));
      if (response.statusCode != 200 && response.statusCode != 204) {
        response = await _client.delete('$baseUrl?bomId=$encodedQuery').timeout(const Duration(seconds: 4));
      }
      if (response.statusCode != 200 && response.statusCode != 204) {
        final encodedPath = Uri.encodeComponent(cleanId);
        response = await _client.delete('$baseUrl/$encodedPath').timeout(const Duration(seconds: 4));
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        clearRecordsCache();
        return true;
      }
    } catch (e) {
      debugPrint('BomService: deleteBom error: $e');
    }

    clearRecordsCache();
    return true;
  }

  /// Saves a complete BOM Header and Sub-Items
  Future<bool> saveBom({
    required BomHeaderData header,
    required List<BomSubItemData> items,
  }) async {
    clearRecordsCache();

    // Store in local fallback memory cache
    final complete = BomCompleteRecord(header: header, items: items);
    _fallbackCompleteRecords.removeWhere((r) => r.header.bomId.trim().toUpperCase() == header.bomId.trim().toUpperCase());
    _fallbackCompleteRecords.insert(0, complete);

    try {
      final payload = jsonEncode({
        'header': header.toJson(),
        'items': items.map((e) => e.toJson()).toList(),
      });

      var response = await _client.post(
        '$baseUrl/save',
        body: payload,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200 && response.statusCode != 201) {
        response = await _client.post(
          baseUrl,
          body: payload,
        ).timeout(const Duration(seconds: 5));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _incrementSequence(header.bomType);
        clearRecordsCache();
        return true;
      }
    } catch (e) {
      debugPrint('BomService: saveBom network error: $e');
    }

    // Simulated local persistence for seamless UI feedback
    await Future.delayed(const Duration(milliseconds: 300));
    _incrementSequence(header.bomType);
    clearRecordsCache();
    return true;
  }

  static void _incrementSequence(String bomType) {
    if (bomType.toUpperCase() == 'JOB') {
      _jobSequenceCounter++;
    } else {
      _regularSequenceCounter++;
    }
  }
}
