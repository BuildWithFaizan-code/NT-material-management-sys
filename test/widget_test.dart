import 'package:flutter_test/flutter_test.dart';

import 'package:newtechmms/app.dart';
import 'package:newtechmms/state/layout_state.dart';
import 'package:newtechmms/state/status_state.dart';

void main() {
  testWidgets('App shell renders without error', (WidgetTester tester) async {
    final layoutState = LayoutState();
    final statusState = StatusState();
    await tester.pumpWidget(App(
      layoutState: layoutState,
      statusState: statusState,
    ));

    expect(find.text('NewTech MMS'), findsOneWidget);
  });
}
