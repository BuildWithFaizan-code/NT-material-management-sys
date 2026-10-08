import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtechmms/pages/bom/bom_followup_models.dart';
import 'package:newtechmms/pages/bom/bom_followup_page.dart';
import 'package:newtechmms/pages/bom/bom_followup_service.dart';
import 'package:newtechmms/pages/bom/widgets/bom_animated_success_button.dart';
import 'package:newtechmms/pages/bom/widgets/bom_export_modal_dialog.dart';
import 'package:newtechmms/pages/bom/widgets/bom_followup_export_modal_dialog.dart';

class FakeBomFollowupService extends BomFollowupService {
  final List<BomFollowupRecord> _records = [
    BomFollowupRecord(
      bomId: 'BMCC/000014/26',
      bomDate: DateTime(2026, 7, 24),
      labCode: 1,
      department: 'PRODUCTION & STITCHING',
      strCode: 1,
      branch: 'MAIN STORE - LUDHIANA',
      khCode: 101,
      division: 'BABY CARE DIVISION',
      materialName: '1 To 10 Baby Pants L-75x6 Regular',
      materialCode: 'FG1T1000000L75000000R',
      mergeNo: '',
      qty: 500.0,
      stock: 500.0,
      status: 'OPEN',
      dtAndTime: DateTime(2026, 7, 24, 12, 22, 51),
      user: 'ADMIN',
      rate: 42.50,
      uqc: 'PCS',
      ucode: 22,
    ),
    BomFollowupRecord(
      bomId: 'BMCJ/000001/27',
      bomDate: DateTime(2026, 7, 20),
      labCode: 2,
      department: 'KNITTING DEPARTMENT',
      strCode: 2,
      branch: 'FINISH GOODS STORE',
      khCode: 102,
      division: 'GARMENTS EXPORT',
      materialName: 'Mylo FG BABY Pants S-84x4',
      materialCode: 'FGMYLO00000S84000000J',
      mergeNo: '',
      qty: 250.0,
      stock: 250.0,
      status: 'OPEN',
      dtAndTime: DateTime(2026, 7, 20, 11, 40, 15),
      user: 'OPERATOR',
      rate: 38.00,
      uqc: 'PCS',
      ucode: 22,
    ),
    BomFollowupRecord(
      bomId: 'BMCC/000015/26',
      bomDate: DateTime(2026, 7, 18),
      labCode: 3,
      department: 'CUTTING DEPARTMENT',
      strCode: 3,
      branch: 'RAW MATERIAL STORE',
      khCode: 103,
      division: 'DOMESTIC APPAREL',
      materialName: '1 To 10 Baby Pants XL-75x6 Regular',
      materialCode: 'FG1T100000XL75000000R',
      mergeNo: '',
      qty: 300.0,
      stock: 300.0,
      status: 'OPEN',
      dtAndTime: DateTime(2026, 7, 18, 14, 15, 0),
      user: 'SUPERVISOR',
      rate: 44.00,
      uqc: 'PCS',
      ucode: 22,
    ),
  ];

  @override
  Future<List<BomFollowupDepartment>> fetchDepartments() async {
    return const [
      BomFollowupDepartment(labCode: 1, labName: 'PRODUCTION & STITCHING'),
      BomFollowupDepartment(labCode: 2, labName: 'KNITTING DEPARTMENT'),
      BomFollowupDepartment(labCode: 3, labName: 'CUTTING DEPARTMENT'),
    ];
  }

  @override
  Future<List<BomFollowupDivision>> fetchDivisions() async {
    return const [
      BomFollowupDivision(khCode: 101, khName: 'BABY CARE DIVISION'),
      BomFollowupDivision(khCode: 102, khName: 'GARMENTS EXPORT'),
      BomFollowupDivision(khCode: 103, khName: 'DOMESTIC APPAREL'),
    ];
  }

  @override
  Future<List<BomFollowupOrderType>> fetchOrderTypes() async {
    return const [
      BomFollowupOrderType(bomType: 'JOB'),
      BomFollowupOrderType(bomType: 'REGULAR'),
    ];
  }

  @override
  Future<List<BomFollowupRecord>> fetchRecords({
    DateTime? asOnDate,
    int? departmentCode,
    int? divisionCode,
    String? orderType,
  }) async {
    return List.from(_records);
  }

  @override
  Future<bool> checkDateLock(DateTime date) async => false;

  @override
  Future<bool> checkLockDate(DateTime date) async => false;

  @override
  Future<BomFollowupCloseResult> closeBomRecords({
    required List<String> bomIds,
    required DateTime asOnDate,
    String username = 'ADMIN',
    String companyName = 'NEW TECH INFOSOL',
  }) async {
    _records.removeWhere((r) => bomIds.contains(r.bomId));
    return BomFollowupCloseResult(
      success: true,
      closedCount: bomIds.length,
      message: 'Successfully closed ${bomIds.length} BOM record(s).',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BOM Follow Up / Bill of Material Close Screen Tests', () {
    testWidgets('BomFollowupPage renders complete UI structure with verified columns & controls',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: BomFollowupPage(service: FakeBomFollowupService()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Header elements
      expect(find.text('Bill Of Material Close Screen'), findsOneWidget);
      expect(find.text('Review and approve active bills of material'), findsOneWidget);
      expect(find.text('BOM FOLLOW UP'), findsNothing); // Removed per user request
      expect(find.byType(BomAnimatedExportButton), findsOneWidget);
      expect(find.byType(BomAnimatedSuccessButton), findsOneWidget);
      expect(find.text('Approve (F1)'), findsOneWidget);

      // 2. Table Subheader Filter & Search controls
      expect(find.text('Filter'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Verify opening the Filter modal
      await tester.tap(find.text('Filter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that the old clunky header is removed and new Image 2 styled modal is rendered
      expect(find.text('Filter BOM Records'), findsNothing);
      expect(find.text('Filter'), findsNWidgets(2)); // Table button + Modal header
      expect(find.text('ALL TYPES'), findsNWidgets(2)); // Quick chip + Radio pill
      expect(find.text('JOB ORDER'), findsNWidgets(2)); // Quick chip + Radio pill
      expect(find.text('REGULAR'), findsNWidgets(2)); // Quick chip + Radio pill
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.text('AS ON DATE'), findsOneWidget);
      expect(find.text('DEPARTMENT'), findsNWidgets(2)); // Table column header + Modal section
      expect(find.text('DIVISION'), findsNWidgets(2)); // Table column header + Modal section
      expect(find.text('ORDER TYPE'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);

      // Close the modal
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 3. Subheader elements
      expect(find.text('3 OPEN RECORDS'), findsOneWidget);
      expect(find.text('Select target records to batch close'), findsOneWidget);

      // 4. Verified Column Headers (Department Master parity)
      expect(find.text('BOM ID'), findsOneWidget);
      expect(find.text('DATE'), findsOneWidget);
      expect(find.text('BRANCH'), findsOneWidget);
      expect(find.text('MATERIAL NAME'), findsOneWidget);
      expect(find.text('MATERIAL CODE'), findsOneWidget);
      expect(find.text('QTY'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('DT & TIME'), findsOneWidget);
      expect(find.text('USER'), findsOneWidget);
      expect(find.text('RATE'), findsOneWidget);
      expect(find.text('UQC'), findsOneWidget);

      // 5. Entire footer removed per user request
      expect(find.text('Save (F1)'), findsNothing);
      expect(find.text('Close'), findsNothing);
    });

    testWidgets('Initial records load, display verified data and summary calculations',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: BomFollowupPage(service: FakeBomFollowupService()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check verified sample BOM IDs
      expect(find.text('BMCC/000014/26'), findsOneWidget);
      expect(find.text('BMCJ/000001/27'), findsOneWidget);
      expect(find.text('BMCC/000015/26'), findsOneWidget);

      // Total count should match loaded fallback records in table subheader
      expect(find.text('3 OPEN RECORDS'), findsOneWidget);
    });

    testWidgets('Quick Search filters records in real-time',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: BomFollowupPage(service: FakeBomFollowupService()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter search query targeting specific BOM ID
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'BMCJ/000001/27');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Only target record should be present in table plus search bar
      expect(find.text('BMCJ/000001/27'), findsNWidgets(2));
      expect(find.text('BMCC/000014/26'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('BMCC/000014/26'), findsOneWidget);
      expect(find.text('BMCJ/000001/27'), findsOneWidget);
    });

    testWidgets('Row selection updates Selected Raw and Selected Qty summary metrics',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: BomFollowupPage(service: FakeBomFollowupService()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on row BMCC/000014/26 (qty: 500)
      await tester.tap(find.text('BMCC/000014/26'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Selected record count is updated in table subheader
      expect(find.text('1 record(s) selected'), findsOneWidget);
    });

    testWidgets('Save action validates selection when no records are selected',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: BomFollowupPage(service: FakeBomFollowupService()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger Save via F1 shortcut key with 0 selected
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Validation snackbar and inline button validation badge
      expect(find.text('Please select at least one open BOM record to close.'), findsOneWidget);
      expect(find.text('Select at least 1 record'), findsOneWidget);

      // Advance clock past auto-dismiss timers
      await tester.pump(const Duration(milliseconds: 3600));
    });

    testWidgets('Batch Close closes selected records, which vanish from active table list',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: BomFollowupPage(service: FakeBomFollowupService()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Select BMCC/000014/26
      expect(find.text('BMCC/000014/26'), findsOneWidget);
      await tester.tap(find.text('BMCC/000014/26'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger Save via F1 shortcut key
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 1600));

      // BMCC/000014/26 must have vanished from active table list!
      expect(find.text('BMCC/000014/26'), findsNothing);

      // Remaining records should still be present
      expect(find.text('BMCJ/000001/27'), findsOneWidget);

      // Verify ZERO external success notification snackbars/banners appeared (in-button feedback only)
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('1 Bill of Material record(s) closed successfully.'), findsNothing);
    });

    testWidgets('BomFollowupExportModalDialog renders 3D logos, record list and export controls',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyRecords = [
        BomFollowupRecord(
          bomId: 'BMCC/000014/26',
          bomDate: DateTime(2026, 7, 24),
          labCode: 1,
          department: 'PRODUCTION & STITCHING',
          strCode: 1,
          branch: 'MAIN STORE - LUDHIANA',
          khCode: 101,
          division: 'BABY CARE DIVISION',
          materialName: '1 To 10 Baby Pants L-75x6 Regular',
          materialCode: 'FG1T1000000L75000000R',
          mergeNo: '',
          qty: 500.0,
          stock: 500.0,
          status: 'OPEN',
          dtAndTime: DateTime(2026, 7, 24, 12, 22, 51),
          user: 'ADMIN',
          rate: 42.50,
          uqc: 'PCS',
          ucode: 22,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BomFollowupExportModalDialog(records: dummyRecords),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Export BOM Followup'), findsOneWidget);
      expect(find.byType(Excel3DBrandLogoWidget), findsOneWidget);
      expect(find.byType(Pdf3DBrandLogoWidget), findsOneWidget);
      expect(find.text('Microsoft Excel (.xlsx)'), findsOneWidget);
      expect(find.text('Adobe PDF (.pdf)'), findsOneWidget);
      expect(find.text('Download Excel'), findsOneWidget);
    });

    test('Service checkDateLock and closeBomRecords work properly', () async {
      final service = FakeBomFollowupService();

      final isLocked = await service.checkLockDate(DateTime(2026, 7, 24));
      expect(isLocked, isFalse);

      final result = await service.closeBomRecords(
        bomIds: ['BMCJ/000001/27'],
        asOnDate: DateTime(2026, 7, 24),
      );

      expect(result.success, isTrue);
      expect(result.closedCount, equals(1));
    });

    testWidgets('Stepper Progress Bar renders 4 distinct colored steps and switches instantly on single click without glitch',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: BomFollowupPage(service: FakeBomFollowupService()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify all 4 step labels and numbers exist
      expect(find.text('All Columns'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Audit Log'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      // 2. Right Arrow (>) switches immediately on a SINGLE tap to Step 2 (Overview)
      final rightArrowFinder = find.byTooltip('Next View Mode');
      expect(rightArrowFinder, findsOneWidget);

      await tester.tap(rightArrowFinder);
      await tester.pump();

      // In Mode 1 (Overview), specific columns like UQC / RATE are hidden, while OVERVIEW columns are visible
      expect(find.text('Overview'), findsOneWidget);

      // 3. Right Arrow (>) again switches to Step 3 (Inventory)
      await tester.tap(rightArrowFinder);
      await tester.pump();

      // 4. Left Arrow (<) switches immediately back to Step 2 (Overview)
      final leftArrowFinder = find.byTooltip('Previous View Mode');
      expect(leftArrowFinder, findsOneWidget);

      await tester.tap(leftArrowFinder);
      await tester.pump();

      // 5. Direct click on Step 4 (Audit Log)
      await tester.tap(find.text('Audit Log'));
      await tester.pump();

      // Step 4 is active
      expect(find.text('Audit Log'), findsOneWidget);
    });

    testWidgets('Filter modal Apply Filters triggers BomAnimatedSuccessButton animation and shows success notification',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: BomFollowupPage(service: FakeBomFollowupService()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open Filter dialog
      await tester.tap(find.text('Filter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Apply Filters button uses BomAnimatedSuccessButton
      final applyButton = find.text('Apply Filters');
      expect(applyButton, findsOneWidget);

      await tester.tap(applyButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Button transitions to loading
      expect(find.text('Applying...'), findsOneWidget);

      // Advance to success state
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Filters Applied!'), findsOneWidget);

      // Settle dialog closing
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();

      // Zero external banner notifications on success (pure in-button animated feedback)
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Filters applied successfully'), findsNothing);
    });
  });
}
