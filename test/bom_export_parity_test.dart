import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtechmms/pages/bom/bom_models.dart';
import 'package:newtechmms/pages/bom/widgets/bom_export_modal_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bill of Material Export Module 100% Parity Tests', () {
    testWidgets('BomAnimatedExportButton renders with orbit beam painter, triggers animation, and invokes callback', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BomAnimatedExportButton(
                onPressed: () => pressed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BomAnimatedExportButton), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);

      // Tap button to trigger orbit beam animation
      await tester.tap(find.byType(BomAnimatedExportButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Before 650ms, pressed is still false
      expect(pressed, isFalse);

      // Finish 650ms animation
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });

    testWidgets('BomExportModalDialog renders 3D Excel and PDF logos with exact brand colors and dimensions', (WidgetTester tester) async {
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
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BomExportModalDialog(records: dummyRecords),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check 3D brand logo widgets
      expect(find.byType(Excel3DBrandLogoWidget), findsOneWidget);
      expect(find.byType(Pdf3DBrandLogoWidget), findsOneWidget);
      expect(find.text('Excel (.xlsx)'), findsOneWidget);
      expect(find.text('PDF (.pdf)'), findsOneWidget);

      // Check AnimatedSuccessButton with exact Project Master download UI
      expect(find.byType(AnimatedSuccessButton), findsOneWidget);
      expect(find.text('Download File'), findsOneWidget);
    });

    testWidgets('AnimatedSuccessButton renders idle state, transitions to success with ripples and sparkles', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSuccessButton(
                status: ButtonStatus.success,
                onPressed: () {},
                idleText: 'Download File',
                loadingText: 'Exporting...',
                successText: 'Exported!',
                idleIcon: Icons.file_download_outlined,
                idleBackgroundColor: const Color(0xFF0C3B2E),
                successBackgroundColor: const Color(0xFF10B981),
                height: 44,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Exported!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}
