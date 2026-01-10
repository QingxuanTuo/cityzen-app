import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cityzen/main.dart';

void main() {
  group('CityZen App Tests', () {
    testWidgets('App should start without crashing', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const CityZenApp());
      await tester.pump();

      // Verify that the app starts
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App should have CityZen title', (WidgetTester tester) async {
      await tester.pumpWidget(const CityZenApp());
      await tester.pump();

      // Check if the app has the correct title
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.title, equals('CityZen'));
    });

    testWidgets('App should have MainShell as home', (WidgetTester tester) async {
      await tester.pumpWidget(const CityZenApp());
      await tester.pump();

      // Verify MainShell is present
      expect(find.byType(MainShell), findsOneWidget);
    });
  });

  group('Basic Widget Tests', () {
    testWidgets('Should create MaterialApp with correct properties', (WidgetTester tester) async {
      await tester.pumpWidget(const CityZenApp());
      
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.debugShowCheckedModeBanner, isFalse);
      expect(app.title, equals('CityZen'));
    });
  });
}