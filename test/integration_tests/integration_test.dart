// 5. Integration Tests for Authentication Flow
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:task_management_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Integration Tests', () {
    testWidgets('full registration and login flow', (
      WidgetTester tester,
    ) async {
      // Load the app
      app.main();
      await tester.pumpAndSettle();

      // We should start at the login screen
      expect(find.text('Login'), findsOneWidget);

      // Navigate to the registration screen
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      // Verify we're on the registration screen
      expect(find.text('Create Account'), findsOneWidget);

      // Fill in registration form with test data
      // Note: For integration tests that interact with real backend,
      // you should use unique email addresses to avoid conflicts
      final testEmail =
          'test_${DateTime.now().millisecondsSinceEpoch}@example.com';

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Integration Test User',
      );
      await tester.enterText(find.byType(TextFormField).at(1), testEmail);
      await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');

      // Accept terms
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Submit registration
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle(
        const Duration(seconds: 3),
      ); // Wait for network request

      // We should now be logged in and see the tasks screen
      expect(find.text('Tasks'), findsOneWidget);

      // Sign out
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      // We should be back at the login screen
      expect(find.text('Login'), findsOneWidget);

      // Now try logging in with the created account
      await tester.enterText(find.byType(TextFormField).at(0), testEmail);
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');

      // Submit login
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle(
        const Duration(seconds: 3),
      ); // Wait for network request

      // We should be logged in and see the tasks screen again
      expect(find.text('Tasks'), findsOneWidget);
    });
  });
}
