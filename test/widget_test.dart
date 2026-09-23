import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:newtechmms/pages/login_page.dart';

void main() {
  testWidgets('LoginPage renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(),
      ),
    );

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
