import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtechmms/pages/operator_master_page.dart';
import 'package:newtechmms/services/operator_service.dart';

class FakeOperatorService extends OperatorService {
  @override
  Future<List<OperatorMaster>> fetchOperators() async {
    return [
      OperatorMaster(operCode: 1, operName: 'TANMAY', operDepCd: 1, labName: 'REGULAR'),
      OperatorMaster(operCode: 3, operName: 'RAHUL', operDepCd: 2, labName: 'FINAL PACKAGE'),
      OperatorMaster(operCode: 4, operName: 'KRISHA', operDepCd: 3, labName: 'REPACK'),
      OperatorMaster(operCode: 5, operName: 'FAIZAN', operDepCd: 2, labName: 'FINAL PACKAGE'),
    ];
  }

  @override
  Future<List<Department>> fetchDepartments() async {
    return [
      Department(labCode: 1, labName: 'REGULAR'),
      Department(labCode: 2, labName: 'FINAL PACKAGE'),
      Department(labCode: 3, labName: 'REPACK'),
    ];
  }

  @override
  Future<int> fetchNextCode() async => 6;
}

void main() {
  testWidgets('OperatorMasterPage layout test', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperatorMasterPage(
            operatorService: FakeOperatorService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Operator Master'), findsOneWidget);
    expect(find.text('Operator Directory Sheet'), findsOneWidget);
    expect(find.text('Add New Operator'), findsOneWidget);
  });
}
