import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colony_login/main.dart';

void main() {
  testWidgets('ColonyApp builds MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const ColonyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
