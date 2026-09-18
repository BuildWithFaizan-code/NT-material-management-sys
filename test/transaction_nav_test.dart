import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtechmms/layout/widgets/transaction_nav_item.dart';
import 'package:newtechmms/state/layout_state.dart';

void main() {
  group('Transaction Data Model Tests', () {
    test('transactionSubSections contains exactly 9 sections and 45 items', () {
      expect(transactionSubSections.length, 9);
      final totalItems = transactionSubSections.fold<int>(
        0,
        (sum, section) => sum + section.items.length,
      );
      expect(totalItems, 45);

      // Verify section titles
      expect(transactionSubSections[0].sectionTitle, isNull);
      expect(transactionSubSections[1].sectionTitle, 'Indent');
      expect(transactionSubSections[2].sectionTitle, 'Sales Order');
      expect(transactionSubSections[3].sectionTitle, 'Purchase Order');
      expect(transactionSubSections[4].sectionTitle, 'Material Inward');
      expect(transactionSubSections[5].sectionTitle, 'Issue');
      expect(transactionSubSections[6].sectionTitle, 'Consumption Module');
      expect(transactionSubSections[7].sectionTitle, 'Job Work');
      expect(transactionSubSections[8].sectionTitle, 'Work Order');

      // Verify first and last items
      expect(transactionSubSections[0].items.first.title, 'Bill of Material (BOM)');
      expect(transactionSubSections[8].items.last.title, 'RGP RECEIVED');
    });
  });

  group('LayoutState Transaction State Tests', () {
    test('setPage(2) defaults to Bill of Material (BOM)', () {
      final layoutState = LayoutState();
      expect(layoutState.selectedTransactionSubItem, '');

      layoutState.setPage(2);
      expect(layoutState.currentPageIndex, 2);
      expect(layoutState.selectedTransactionSubItem, 'Bill of Material (BOM)');
    });

    test('setTransactionSubItem sets index to 2 and updates sub-item', () {
      final layoutState = LayoutState();
      layoutState.setTransactionSubItem('Gate Entry Manager');
      expect(layoutState.currentPageIndex, 2);
      expect(layoutState.selectedTransactionSubItem, 'Gate Entry Manager');
    });

    test('initFromUri correctly parses master module slug', () {
      final layoutState = LayoutState(
        initialUri: Uri.parse('https://app.newtech.com/?module=location'),
      );
      expect(layoutState.currentPageIndex, 1);
      expect(layoutState.selectedMasterSubItem, 'Location Master');
    });

    test('initFromUri correctly parses transaction module slug', () {
      final layoutState = LayoutState(
        initialUri: Uri.parse('https://app.newtech.com/?module=workorder'),
      );
      expect(layoutState.currentPageIndex, 2);
      expect(layoutState.selectedTransactionSubItem, 'Create Work Order');
    });

    test('initFromUri correctly parses ?page=reports', () {
      final layoutState = LayoutState(
        initialUri: Uri.parse('https://app.newtech.com/?page=reports'),
      );
      expect(layoutState.currentPageIndex, 3);
    });
  });

  group('TransactionNavItem Widget Tests', () {
    testWidgets('renders Transaction header and expands nested dropdowns on tap',
        (WidgetTester tester) async {
      String selectedSub = '';
      bool headerTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TransactionNavItem(
                isTransactionSelected: false,
                activeSubItem: '',
                onTransactionHeaderTap: () {
                  headerTapped = true;
                },
                onSubItemSelected: (sub) {
                  selectedSub = sub;
                },
              ),
            ),
          ),
        ),
      );

      // Verify Header exists
      expect(find.text('Transaction'), findsOneWidget);

      // Tap Header to expand Transaction menu
      await tester.tap(find.text('Transaction'));
      await tester.pumpAndSettle();

      expect(headerTapped, isTrue);

      // Top group item and nested section dropdown headers should be present
      expect(find.text('Bill of Material (BOM)'), findsOneWidget);
      expect(find.text('Indent'), findsOneWidget);
      expect(find.text('Sales Order'), findsOneWidget);
      expect(find.text('Purchase Order'), findsOneWidget);

      // Tap 'Indent' dropdown to expand it
      await tester.tap(find.text('Indent'));
      await tester.pumpAndSettle();

      // Indent sub-items should now be visible
      expect(find.text('Create Indent'), findsOneWidget);
      expect(find.text('Indent Approval'), findsOneWidget);

      // Tap 'Create Indent'
      await tester.tap(find.text('Create Indent'));
      await tester.pumpAndSettle();

      expect(selectedSub, 'Create Indent');
    });

    testWidgets('auto-expands section dropdown when activeSubItem belongs to it',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TransactionNavItem(
                isTransactionSelected: true,
                activeSubItem: 'Generate Sales Order',
                onTransactionHeaderTap: _dummyCallback,
                onSubItemSelected: _dummyValueCallback,
              ),
            ),
          ),
        ),
      );

      // Sales Order dropdown should be auto-expanded because 'Generate Sales Order' is active
      expect(find.text('Sales Order'), findsOneWidget);
      expect(find.text('Generate Sales Order'), findsOneWidget);
    });
  });
}

void _dummyCallback() {}
void _dummyValueCallback(String _) {}
