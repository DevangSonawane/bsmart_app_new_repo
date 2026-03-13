// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/material.dart';
import 'package:b_smart/screens/auth/login/login_screen.dart';

void main() {
  testWidgets('App launches and shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });
}
