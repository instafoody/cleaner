// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:cleanlite_pro/main.dart';

void main() {
  testWidgets('Cleaning Ninja app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CleanLiteProApp());

    // Verify that the app title is displayed
    expect(find.text('Cleaning Ninja'), findsOneWidget);
    
    // Verify that the scan button is present
    expect(find.text('Scan Phone'), findsOneWidget);
    
    // Verify that the clean button is present
    expect(find.text('Clean Now'), findsOneWidget);
  });
}
