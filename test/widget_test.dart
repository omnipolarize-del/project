// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:curvi_grid/main.dart';

void main() {
  testWidgets('CurviGrid app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CurviGridApp());

    // Check for the initial interaction hint which is a visible Text widget.
    expect(find.text('Swipe up for controls'), findsOneWidget);
  });
}
