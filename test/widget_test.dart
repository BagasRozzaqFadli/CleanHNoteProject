// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleanhnoteapp/main.dart';

void main() {
  testWidgets('App should show login screen initially', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that we're on the login screen
    expect(find.text('Login'), findsOneWidget);
    
    // Verify that we have email and password fields
    expect(find.byType(TextField), findsAtLeast(2));
  });
}
