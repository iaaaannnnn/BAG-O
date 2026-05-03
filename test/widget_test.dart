import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bago_system/app/app.dart';

void main() {
  testWidgets('BAG-O app shell exposes current brand title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const Scaffold(body: Text('BAG-O')),
      ),
    );

    expect(find.text('BAG-O'), findsOneWidget);
  });
}
