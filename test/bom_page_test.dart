import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtechmms/pages/bom/bom_models.dart';
import 'package:newtechmms/pages/bom/bom_service.dart';
import 'package:newtechmms/pages/bom/widgets/add_bom_row_dialog.dart';
import 'package:newtechmms/pages/bom/widgets/bom_export_modal_dialog.dart';
import 'package:newtechmms/pages/transactions/bill_of_material_page.dart';

class FakeBomService extends BomService {
  @override
  Future<List<BomStoreLookup>> fetchStores({bool forceRefresh = false}) async {
    return const [
      BomStoreLookup(strCode: 1, strName: 'MAIN STORE - LUDHIANA'),
      BomStoreLookup(strCode: 2, strName: 'FINISH GOODS STORE'),
    ];
  }

  @override
  Future<List<BomDepartmentLookup>> fetchDepartments({bool forceRefresh = false}) async {
    return const [
      BomDepartmentLookup(labCode: 1, labName: 'PRODUCTION & STITCHING'),
      BomDepartmentLookup(labCode: 2, labName: 'KNITTING DEPARTMENT'),
    ];
  }

  @override
  Future<List<BomUnitLookup>> fetchUnits({bool forceRefresh = false}) async {
    return const [
      BomUnitLookup(unitCode: 22, unitName: 'PCS'),
      BomUnitLookup(unitCode: 24, unitName: 'MTR'),
    ];
  }

  @override
  Future<String> fetchNextBomId(BomMode mode) async {
    return '${mode.prefix}/000001/27';
  }

  @override
  Future<List<FinishedGoodItem>> fetchFinishedGoods({
    required BomMode mode,
    String query = '',
    bool forceRefresh = false,
  }) async {
    if (mode == BomMode.job) {
      return const [
        FinishedGoodItem(
          iCode: 'FGMYLO00000S84000000J',
          itName: 'Mylo FG BABY Pants S-84x4',
          unitName: 'PCS',
          unitCode: 22,
          status: 'OPEN',
          skuCross: 'J',
        ),
      ];
    } else {
      return const [
        FinishedGoodItem(
          iCode: 'FG1T1000000L75000000R',
          itName: '1 To 10 Baby Pants L-75x6 Regular',
          unitName: 'PCS',
          unitCode: 22,
          status: 'OPEN',
          skuCross: 'R',
        ),
      ];
    }
  }

  @override
  Future<List<ComponentLookupItem>> fetchComponents({
    required String parentItemCode,
    String query = '',
    bool forceRefresh = false,
  }) async {
    const list = [
      ComponentLookupItem(
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
      ComponentLookupItem(
        iCode: 'ACSEWTHRDSPUNPOLY',
        itName: 'Spun Polyester Sewing Thread 40/2',
        unitCode: 26,
        unitName: 'NOS',
        catCode: 2,
        materialType: 'ACCESSORIES',
        convQty: 1.0,
        printCode: 'THRD-40/2',
      ),
    ];
    return list.where((item) => item.iCode != parentItemCode).toList();
  }

  @override
  Future<List<BomRecordSummary>> fetchBomRecords({
    BomMode? mode,
    String query = '',
    bool forceRefresh = false,
  }) async {
    final cleanQ = query.trim().toLowerCase();
    final list = BomService.fallbackCompleteRecords.where((record) {
      if (mode != null && record.header.bomType.toUpperCase() != mode.label.toUpperCase()) {
        return false;
      }
      if (cleanQ.isEmpty) return true;
      final h = record.header;
      return h.bomId.toLowerCase().contains(cleanQ) ||
          h.iCode.toLowerCase().contains(cleanQ) ||
          h.description.toLowerCase().contains(cleanQ);
    }).map((record) {
      final h = record.header;
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
      );
    }).toList();

    if (mode == null || mode == BomMode.job) {
      list.add(
        BomRecordSummary(
          bomId: 'BOM_APPROVED_TEST',
          bomCode: 'APPR001',
          depCode: 1,
          depName: 'PRODUCTION & STITCHING',
          strCode: 1,
          strName: 'MAIN STORE - LUDHIANA',
          iCode: 'FGMYLO00000S84000000J',
          description: 'Approved Baby Pants Test',
          qty: 50.0,
          unitCode: 22,
          unitName: 'PCS',
          status: 'APPROVED',
          bomType: 'JOB',
          bomDate: DateTime(2026, 9, 15),
          bomPo: 'PO-APPR-100',
          subItemCount: 1,
        ),
      );
      list.add(
        BomRecordSummary(
          bomId: 'BOM_MISMATCH_TEST',
          bomCode: 'MISM001',
          depCode: 999,
          depName: 'GHOST DEPARTMENT 999',
          strCode: 888,
          strName: 'GHOST STORE 888',
          iCode: 'FGMYLO00000S84000000J',
          description: 'Mismatch Baby Pants Test',
          qty: 50.0,
          unitCode: 22,
          unitName: 'PCS',
          status: 'OPEN',
          bomType: 'JOB',
          bomDate: DateTime(2026, 9, 15),
          bomPo: 'PO-MISM-100',
          subItemCount: 0,
        ),
      );
    }
    return list;
  }

  @override
  Future<BomCompleteRecord?> fetchBomDetails(String bomId) async {
    if (bomId == 'BOM_APPROVED_TEST') {
      return BomCompleteRecord(
        header: BomHeaderData(
          bomId: 'BOM_APPROVED_TEST',
          bomCode: 'APPR001',
          depCode: 1,
          depName: 'PRODUCTION & STITCHING',
          strCode: 1,
          strName: 'MAIN STORE - LUDHIANA',
          iCode: 'FGMYLO00000S84000000J',
          description: 'Approved Baby Pants Test',
          qty: 50.0,
          unitCode: 22,
          unitName: 'PCS',
          status: 'APPROVED',
          bomType: 'JOB',
          bomDate: DateTime(2026, 9, 15),
          bomPo: 'PO-APPR-100',
          bomEDate: DateTime(2026, 9, 15),
        ),
        items: const [
          BomSubItemData(
            bomsId: 'BOM_APPROVED_TEST',
            bomsCode: '1',
            itGroupCd: 1,
            iCode: 'RMCOT100SINGLEJERS',
            description: 'Cotton Fabric',
            materialType: 'RAW MATERIAL',
            qty: 1.0,
            unitCode: 25,
            unitName: 'KGS',
            sqm: 1.0,
            bomCons: 1.0,
            bomExtra: 0.0,
            bomTolQty: 0.0,
            bomTotQty: 1.0,
            convQty: 1.0,
          ),
        ],
      );
    }
    if (bomId == 'BOM_MISMATCH_TEST') {
      return BomCompleteRecord(
        header: BomHeaderData(
          bomId: 'BOM_MISMATCH_TEST',
          bomCode: 'MISM001',
          depCode: 999,
          depName: 'GHOST DEPARTMENT 999',
          strCode: 888,
          strName: 'GHOST STORE 888',
          iCode: 'FGMYLO00000S84000000J',
          description: 'Mismatch Baby Pants Test',
          qty: 50.0,
          unitCode: 22,
          unitName: 'PCS',
          status: 'OPEN',
          bomType: 'JOB',
          bomDate: DateTime(2026, 9, 15),
          bomPo: 'PO-MISM-100',
          bomEDate: DateTime(2026, 9, 15),
        ),
        items: const [],
      );
    }
    try {
      return BomService.fallbackCompleteRecords.firstWhere(
        (r) => r.header.bomId.toUpperCase() == bomId.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<BomSaveResult> saveBom({
    required BomHeaderData header,
    required List<BomSubItemData> items,
  }) async {
    if (header.status.toUpperCase() == 'APPROVED') {
      return const BomSaveResult(
        success: false,
        errorMessage: 'Cannot modify or save an APPROVED BOM record.',
      );
    }
    final authoritativeId = header.bomId.isEmpty ? 'BMCJ/000999/27' : header.bomId;
    return BomSaveResult(
      success: true,
      bomId: authoritativeId,
    );
  }

  @override
  Future<bool> deleteBom(String bomId) async {
    BomService.fallbackCompleteRecords.removeWhere((r) => r.header.bomId.toUpperCase() == bomId.toUpperCase());
    return true;
  }
}

void main() {
  group('BOM Service & Models Unit Tests', () {
    test('BomMode has correct prefixes and SKU crosses', () {
      expect(BomMode.job.prefix, 'BMCJ');
      expect(BomMode.job.skuCross, 'J');
      expect(BomMode.regular.prefix, 'BMCC');
      expect(BomMode.regular.skuCross, 'R');
    });

    test('fetchNextBomId generates standard ERP format [Prefix]/[000001]/[FY]', () async {
      final service = FakeBomService();
      final jobId = await service.fetchNextBomId(BomMode.job);
      final regularId = await service.fetchNextBomId(BomMode.regular);

      expect(jobId.startsWith('BMCJ/'), isTrue);
      expect(jobId.split('/').length, 3);
      expect(jobId.split('/')[1].length, 6);

      expect(regularId.startsWith('BMCC/'), isTrue);
      expect(regularId.split('/').length, 3);
      expect(regularId.split('/')[1].length, 6);
    });

    test('fetchFinishedGoods strictly filters by SKU cross', () async {
      final service = FakeBomService();
      final jobItems = await service.fetchFinishedGoods(mode: BomMode.job);
      final regularItems = await service.fetchFinishedGoods(mode: BomMode.regular);

      expect(jobItems.isNotEmpty, isTrue);
      expect(jobItems.every((item) => item.skuCross == 'J'), isTrue);

      expect(regularItems.isNotEmpty, isTrue);
      expect(regularItems.every((item) => item.skuCross == 'R'), isTrue);
    });

    test('FinishedGoodItem serialization roundtrip', () {
      const item = FinishedGoodItem(
        iCode: 'FGMYLO00000S84000000J',
        itName: 'Mylo FG BABY Pants S-84x4',
        unitName: 'PCS',
        unitCode: 22,
        status: 'OPEN',
        skuCross: 'J',
      );

      final json = item.toJson();
      final fromJson = FinishedGoodItem.fromJson(json);

      expect(fromJson.iCode, item.iCode);
      expect(fromJson.itName, item.itName);
      expect(fromJson.unitName, item.unitName);
      expect(fromJson.unitCode, item.unitCode);
      expect(fromJson.status, item.status);
      expect(fromJson.skuCross, item.skuCross);
    });
    test('BomSubItemData calculation: tolerance qty and net total qty', () {
      const item = BomSubItemData(
        bomsId: 'BMCJ/000001/27',
        bomsCode: '1',
        itGroupCd: 1,
        iCode: 'RMCOT100SINGLEJERS',
        description: 'Cotton Fabric',
        materialType: 'RAW MATERIAL',
        qty: 1.0,
        unitCode: 25,
        unitName: 'KGS',
        sqm: 1.25,
        bomCons: 2.0,
        bomExtra: 10.0,
        bomTolQty: 0.2,
        bomTotQty: 2.2,
        convQty: 3.25,
        bomRate: 250.0,
        bomAmount: 550.0,
        bomRemarks: 'Test remarks',
      );

      final calculatedTolQty = item.bomCons * (item.bomExtra / 100.0);
      expect(calculatedTolQty, equals(0.2));
      final calculatedTotQty = item.bomCons + calculatedTolQty;
      expect(calculatedTotQty, equals(2.2));
    });
  });

  group('BillOfMaterialPage Widget Tests', () {
    testWidgets('BillOfMaterialPage renders Header Toolbar and Form Controls', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Header Elements
      expect(find.text('Bill of Material (BOM)'), findsOneWidget);
      expect(find.text('JOB (BMCJ)'), findsWidgets);
      expect(find.text('REGULAR (BMCC)'), findsOneWidget);
      expect(find.text('Show Record'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);

      // Verify Form Cards in Left Pane
      expect(find.text('BOM HEADER DETAILS'), findsOneWidget);
      expect(find.text('PLANT / STORE'), findsOneWidget);
      expect(find.text('DEPARTMENT'), findsOneWidget);
      expect(find.text('BOM ID'), findsOneWidget);
      expect(find.text('DATE'), findsOneWidget);
      expect(find.text('FINISHED GOOD MATERIAL CODE'), findsOneWidget);
      expect(find.text('DESCRIPTION'), findsOneWidget);
      expect(find.text('PO #'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('BASE QTY'), findsOneWidget);
      expect(find.text('UNIT (UOM)'), findsOneWidget);

      // Verify Form Action Buttons
      expect(find.text('Reset (Esc)'), findsOneWidget);
      expect(find.text('Save BOM (F1)'), findsOneWidget);

      // Verify Right Pane Desk Placeholder
      expect(find.text('BOM SUB-ITEMS & COMPONENTS'), findsOneWidget);
    });

    testWidgets('Toggling BOM mode switches prefix badge', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on REGULAR (BMCC) mode option in header
      await tester.tap(find.text('REGULAR (BMCC)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify header badge updated
      expect(find.text('REGULAR (BMCC)'), findsWidgets);
    });

    testWidgets('Clicking Save BOM when form is empty triggers validation warning', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Save BOM (F1) while form is empty
      await tester.tap(find.text('Save BOM (F1)'));
      await tester.pump();

      expect(find.text('Please select Plant / Store!'), findsOneWidget);
      // Wait for validation timer to expire
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Can select Finished Good and verify empty components state', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify empty components state
      expect(find.text('No Components Added'), findsOneWidget);

      // Trigger Finished Good Lookup
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      // Finished Good Dialog is open
      expect(find.text('Select Finished Good Item'), findsOneWidget);

      // Tap on the Select button for the item
      await tester.tap(find.text('Select').first);
      await tester.pumpAndSettle();

      // Ensure Finished Good Dialog is closed
      expect(find.text('Select Finished Good Item'), findsNothing);
      expect(find.byType(Dialog), findsNothing);

      // Dialog closed and material code populated
      expect(find.text('FGMYLO00000S84000000J'), findsOneWidget);
    });

    testWidgets('Add Row medium modal box workflow opens dialog, picks item via Query 6, and adds complete row', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Attempting to click Add Row without Finished Good prompts validation
      await tester.tap(find.text('Add Row').first);
      await tester.pumpAndSettle();
      expect(find.text('Please select Finished Good Material Code first!'), findsOneWidget);

      // Select Finished Good
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select').first);
      await tester.pumpAndSettle();

      // Click Add Row to open the medium modal box
      await tester.tap(find.text('Add Row').first);
      await tester.pumpAndSettle();

      // Verify Add Row medium modal box is open with compulsory fields
      expect(find.text('Add Recipe Row / Sub-Component'), findsOneWidget);
      expect(find.text('FG: FGMYLO00000S84000000J'), findsOneWidget);
      expect(find.text('1. MATERIAL & COMPONENT IDENTIFICATION'), findsOneWidget);
      expect(find.text('2. RECIPE QUANTITIES & SPECIFICATIONS'), findsOneWidget);
      expect(find.text('3. COSTING & REMARKS'), findsOneWidget);

      // Click [...] item lookup inside the medium modal box to query ITEMMST (Query 6)
      final lookupTrigger = find.byTooltip('Lookup from ITEMMST (Query 6)');
      expect(lookupTrigger, findsOneWidget);
      await tester.tap(lookupTrigger);
      await tester.pumpAndSettle();

      // Pick component from lookup
      expect(find.text('Select Sub-Material / Component'), findsOneWidget);
      final selectSubBtn = find.descendant(
        of: find.byType(Dialog).last,
        matching: find.widgetWithText(ElevatedButton, 'Select'),
      ).first;
      await tester.tap(selectSubBtn);
      await tester.pumpAndSettle();

      // Lookup closed, component details populated into Add Row form
      expect(find.text('Add Recipe Row / Sub-Component'), findsOneWidget);
      expect(find.text('RMCOT100SINGLEJERS'), findsOneWidget);
      expect(find.text('100% Cotton Single Jersey 180 GSM'), findsOneWidget);

      // Click Add Row to Recipe button in footer
      final addRowToRecipeBtn = find.text('Add Row to Recipe');
      expect(addRowToRecipeBtn, findsOneWidget);
      await tester.tap(addRowToRecipeBtn);
      await tester.pumpAndSettle();

      // Modal closed, row added to sub-items table with all columns filled
      expect(find.text('Add Recipe Row / Sub-Component'), findsNothing);
      expect(find.text('1 Components'), findsOneWidget);
      expect(find.text('RMCOT100SINGLEJERS'), findsOneWidget);
      expect(find.text('100% Cotton Single Jersey 180 GSM'), findsOneWidget);
      expect(find.text('1 Sub-Item(s)'), findsOneWidget);
      expect(find.text('1.00'), findsWidgets);
    });

    test('BomService fetchBomRecords and fetchBomDetails return structured data', () async {
      final service = BomService();
      final records = await service.fetchBomRecords();
      expect(records.isNotEmpty, isTrue);

      final jobRecords = await service.fetchBomRecords(mode: BomMode.job);
      expect(jobRecords.every((r) => r.bomType == 'JOB'), isTrue);

      final regularRecords = await service.fetchBomRecords(mode: BomMode.regular);
      expect(regularRecords.every((r) => r.bomType == 'REGULAR'), isTrue);

      final firstId = records.first.bomId;
      final details = await service.fetchBomDetails(firstId);
      expect(details, isNotNull);
      expect(details!.header.bomId, firstId);
      expect(details.items.isNotEmpty, isTrue);
    });

    testWidgets('Tapping Show Record opens modal, filters, and selecting populates header and components', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Click "Show Record" button
      await tester.tap(find.text('Show Record'));
      await tester.pumpAndSettle();

      // Verify modal is open
      expect(find.text('Select Bill of Materials (BOM) Record'), findsOneWidget);
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('BMCJ/000001/27')), findsOneWidget);
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('BMCC/000001/27')), findsOneWidget);

      // Filter by regular mode
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('REGULAR (BMCC)')));
      await tester.pumpAndSettle();

      // Only regular records are visible in dialog
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('BMCC/000001/27')), findsOneWidget);
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('BMCJ/000001/27')), findsNothing);

      // Ensure Edit button is visible and tap 'Edit' on BMCC/000001/27
      final selectBtn = find.byTooltip('Edit BOM').first;
      await tester.ensureVisible(selectBtn);
      await tester.tap(selectBtn);
      await tester.pumpAndSettle();

      // Ensure modal is dismissed
      expect(find.text('Select Bill of Materials (BOM) Record'), findsNothing);

      // Verify Left Pane Header is populated
      expect(find.text('BMCC/000001/27'), findsWidgets);
      expect(find.text('FG1T1000000L75000000R'), findsOneWidget);
      expect(find.text('1 To 10 Baby Pants L-75x6 Regular'), findsWidgets);
      expect(find.text('REG-PO-4410'), findsOneWidget);

      // Verify Right Pane Components Table has the 3 components loaded
      expect(find.text('3 Components'), findsOneWidget);
      expect(find.text('3 Sub-Item(s)'), findsOneWidget);
      expect(find.text('RMCOT100SINGLEJERS'), findsOneWidget);
      expect(find.text('ACSEWTHRDSPUNPOLY'), findsOneWidget);
      expect(find.text('PKMCARTON7PLY6040'), findsOneWidget);
    });

    testWidgets('Deleting record from Show Record modal prompts confirmation dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Click "Show Record" button
      await tester.tap(find.text('Show Record'));
      await tester.pumpAndSettle();

      // Click delete on the first row in the modal
      final deleteIcon = find.descendant(
        of: find.byType(Dialog),
        matching: find.byIcon(Icons.delete_outline_rounded),
      ).first;

      await tester.ensureVisible(deleteIcon);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      // Confirmation dialog is shown
      expect(find.text('Delete BOM Record?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete BOM Record?'), findsNothing);
      expect(find.text('Select Bill of Materials (BOM) Record'), findsOneWidget);
    });

    testWidgets('BomExportModalDialog renders 3D format cards, toggles selection, filters search, and triggers download', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyRecords = [
        BomRecordSummary(
          bomId: 'BMCJ/000001/27',
          bomCode: '1',
          depCode: 1,
          depName: 'PRODUCTION & STITCHING',
          strCode: 1,
          strName: 'MAIN STORE - LUDHIANA',
          iCode: 'FG1T1000000L75000000J',
          description: '1 To 10 Baby Pants L-75x6 Jobwork',
          qty: 1.0,
          unitCode: 1,
          unitName: 'PCS',
          status: 'OPEN',
          bomType: 'JOB',
          bomDate: DateTime(2026, 9, 1),
          bomPo: 'JOB-PO-9921',
          subItemCount: 2,
          totalConsumption: 2.5,
          totalNetQty: 2.65,
        ),
        BomRecordSummary(
          bomId: 'BMCC/000001/27',
          bomCode: '2',
          depCode: 1,
          depName: 'PRODUCTION & STITCHING',
          strCode: 1,
          strName: 'MAIN STORE - LUDHIANA',
          iCode: 'FG1T1000000L75000000R',
          description: '1 To 10 Baby Pants L-75x6 Regular',
          qty: 1.0,
          unitCode: 1,
          unitName: 'PCS',
          status: 'OPEN',
          bomType: 'REGULAR',
          bomDate: DateTime(2026, 9, 2),
          bomPo: 'REG-PO-4410',
          subItemCount: 3,
          totalConsumption: 3.2,
          totalNetQty: 3.42,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BomExportModalDialog(records: dummyRecords),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Left Pane Header & Format Cards
      expect(find.text('Export Bill of Materials'), findsOneWidget);
      expect(find.text('Excel (.xlsx)'), findsOneWidget);
      expect(find.text('PDF (.pdf)'), findsOneWidget);
      expect(find.text('Download File'), findsOneWidget);
      expect(find.byType(Excel3DBrandLogoWidget), findsOneWidget);
      expect(find.byType(Pdf3DBrandLogoWidget), findsOneWidget);

      // Verify Right Pane Preview Table
      expect(find.text('2 of 2 selected'), findsOneWidget);
      expect(find.text('BMCJ/000001/27'), findsOneWidget);
      expect(find.text('BMCC/000001/27'), findsOneWidget);

      // Switch Format to PDF
      await tester.tap(find.text('PDF (.pdf)'));
      await tester.pumpAndSettle();

      // Filter via search
      await tester.enterText(find.widgetWithText(TextField, 'Search records...'), 'JOB-PO');
      await tester.pumpAndSettle();

      // Only JOB record remains visible in preview
      expect(find.text('BMCJ/000001/27'), findsOneWidget);
      expect(find.text('BMCC/000001/27'), findsNothing);

      // Clear search
      await tester.enterText(find.widgetWithText(TextField, 'Search records...'), '');
      await tester.pumpAndSettle();

      expect(find.text('BMCC/000001/27'), findsOneWidget);

      // Toggle Select All
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 2 selected'), findsOneWidget);

      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2 selected'), findsOneWidget);
    });

    testWidgets('Tapping Export on BillOfMaterialPage opens BomExportModalDialog with fetched records', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Header Export Button
      final exportBtn = find.byTooltip('Export BOM Records');
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      // Verify BomExportModalDialog is displayed
      expect(find.byType(BomExportModalDialog), findsOneWidget);
      expect(find.text('Export Bill of Materials'), findsOneWidget);
      expect(find.text('Download File'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(BomExportModalDialog), findsNothing);
    });

    testWidgets('Sub-Items table has Edit & Delete actions, and Zoom In button opens full detail modal', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open Show Record and select BMCC/000001/27
      await tester.tap(find.text('Show Record'));
      await tester.pumpAndSettle();

      final selectBtn = find.byTooltip('Edit BOM').first;
      await tester.ensureVisible(selectBtn);
      await tester.tap(selectBtn);
      await tester.pumpAndSettle();

      // Verify table headers: SR, MATERIAL TYPE, MATERIAL CODE, MATERIAL DESCRIPTION, CONS., NET QTY, ACTION
      expect(find.text('SR'), findsOneWidget);
      expect(find.text('MATERIAL TYPE'), findsOneWidget);
      expect(find.text('MATERIAL CODE'), findsOneWidget);
      expect(find.text('MATERIAL DESCRIPTION'), findsOneWidget);
      expect(find.text('CONS.'), findsOneWidget);
      expect(find.text('NET QTY'), findsWidgets);
      expect(find.text('ACTION'), findsOneWidget);

      // Verify Edit and Delete buttons exist in row
      expect(find.byTooltip('Edit Component'), findsWidgets);
      expect(find.byTooltip('Delete Component'), findsWidgets);

      // Verify Zoom In button is present in footer
      final zoomInBtn = find.text('Zoom In (Full Detail)');
      expect(zoomInBtn, findsOneWidget);

      // Tap Zoom In (Full Detail)
      await tester.tap(zoomInBtn);
      await tester.pumpAndSettle();

      // Verify Full Detail modal is shown with all detailed columns and Edit & Delete actions
      expect(find.text('BOM SUB-ITEMS & COMPONENTS — FULL DETAIL VIEW'), findsOneWidget);
      expect(find.text('Close View'), findsOneWidget);
      expect(find.byTooltip('Edit Component'), findsWidgets);
      expect(find.byTooltip('Delete Component'), findsWidgets);

      // Close Zoom In modal
      await tester.tap(find.text('Close View'));
      await tester.pumpAndSettle();
      expect(find.text('BOM SUB-ITEMS & COMPONENTS — FULL DETAIL VIEW'), findsNothing);
    });

    testWidgets('Tapping Edit Component opens edit row dialog and allows updating sub-item component', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Load record
      await tester.tap(find.text('Show Record'));
      await tester.pumpAndSettle();
      final selectBtn = find.byTooltip('Edit BOM').first;
      await tester.ensureVisible(selectBtn);
      await tester.tap(selectBtn);
      await tester.pumpAndSettle();

      // Edit component tooltip and dialog exists
      expect(find.byTooltip('Edit Component'), findsWidgets);

      // Tap Edit Component on first row
      await tester.tap(find.byTooltip('Edit Component').first);
      await tester.pumpAndSettle();

      // Dialog is displayed with edit header
      expect(find.byType(AddBomRowDialog), findsOneWidget);
      expect(find.textContaining('Edit Recipe Row'), findsOneWidget);
    });

    testWidgets('Deleting a component prompts project master delete UI pane and deletes row in real time', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Load regular record with 3 components
      await tester.tap(find.text('Show Record'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('REGULAR (BMCC)')));
      await tester.pumpAndSettle();
      final selectBtn = find.byTooltip('Edit BOM').first;
      await tester.ensureVisible(selectBtn);
      await tester.tap(selectBtn);
      await tester.pumpAndSettle();

      expect(find.text('3 Components'), findsOneWidget);

      // Tap Delete on first row
      final firstDelete = find.byTooltip('Delete Component').first;
      await tester.tap(firstDelete);
      await tester.pumpAndSettle();

      // Project Master style delete dialog is shown
      expect(find.text('Are you sure you want to delete this'), findsOneWidget);
      expect(find.text('Delete'), findsWidgets);
      expect(find.text('Cancel'), findsWidgets);

      // Confirm deletion
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Confirmation dialog dismissed and component count updated to 2 in real time
      expect(find.text('Are you sure you want to delete this'), findsNothing);
      expect(find.text('2 Components'), findsOneWidget);
      expect(find.text('2 Sub-Item(s)'), findsOneWidget);
    });

    testWidgets('Loading an APPROVED record freezes the form, disables save/delete, and displays lock banner', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open Show Record modal
      await tester.tap(find.text('Show Record'));
      await tester.pumpAndSettle();

      // Search and select BOM_APPROVED_TEST
      await tester.enterText(
        find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
        'BOM_APPROVED_TEST',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final selectBtn = find.byTooltip('Edit BOM').first;
      await tester.ensureVisible(selectBtn);
      await tester.tap(selectBtn);
      await tester.pumpAndSettle();

      // Ensure modal is dismissed
      expect(find.text('Select Bill of Materials (BOM) Record'), findsNothing);

      // Verify prominent APPROVED Lock banner is visible
      expect(find.text('This BOM is APPROVED and locked for editing.'), findsOneWidget);

      // Verify Save button indicates locked state
      expect(find.text('Locked (Approved)'), findsOneWidget);
      expect(find.text('Save BOM (F1)'), findsNothing);

      // Verify tapping delete component does not show confirmation dialog
      await tester.tap(find.byTooltip('Delete Component').first);
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to delete this'), findsNothing);

      // Verify F1 shortcut does not trigger save
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      expect(find.text('Saving BOM...'), findsNothing);
    });

    testWidgets('Loading record with unknown store/department displays mismatch warning and unmatched code', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillOfMaterialPage(
              bomService: FakeBomService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open Show Record modal and search for mismatch record
      await tester.tap(find.text('Show Record'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
        'BOM_MISMATCH_TEST',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final selectBtn = find.byTooltip('Edit BOM').first;
      await tester.ensureVisible(selectBtn);
      await tester.tap(selectBtn);
      await tester.pumpAndSettle();

      // Verify Master Data Mismatch warning banner appears
      expect(
        find.text('One or more master data values on this record no longer exist in master data. Review Store / Department / Unit before saving.'),
        findsOneWidget,
      );

      // Verify unmatched store/department indicator is displayed
      expect(find.text('Unmatched (Code: 888)'), findsOneWidget);
      expect(find.text('Unmatched (Code: 999)'), findsOneWidget);
    });

    test('BomService in-memory caching and cache invalidation behavior', () async {
      final service = BomService();

      // First fetch populates cache
      final stores1 = await service.fetchStores();
      final stores2 = await service.fetchStores();
      expect(identical(stores1, stores2), isTrue);

      final depts1 = await service.fetchDepartments();
      final depts2 = await service.fetchDepartments();
      expect(identical(depts1, depts2), isTrue);

      final units1 = await service.fetchUnits();
      final units2 = await service.fetchUnits();
      expect(identical(units1, units2), isTrue);

      // Invalidate cache
      service.clearAllCache();
      final stores3 = await service.fetchStores();
      expect(stores3.length, stores1.length);
    });
  });
}
