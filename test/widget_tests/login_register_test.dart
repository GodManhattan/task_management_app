// 4. Widget Tests for Login and Register Pages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:task_management_app/cubits/auth/auth_cubit.dart';
import 'package:task_management_app/presentation/pages/auth/login_page.dart';
import 'package:task_management_app/presentation/pages/auth/register_page.dart';
import 'package:task_management_app/core/routing/navigation_helpers.dart';
import 'login_register_test.mocks.dart';

// Create a mock NavigatorObserver
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

// Generate mocks for AuthCubit
@GenerateMocks([AuthCubit])
void main() {
  late MockAuthCubit mockAuthCubit;

  setUp(() {
    mockAuthCubit = MockAuthCubit();
    when(mockAuthCubit.state).thenReturn(AuthInitial());
  });

  group('LoginPage Widget Tests', () {
    testWidgets('renders login form', (WidgetTester tester) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthCubit>.value(
            value: mockAuthCubit,
            child: const LoginPage(),
          ),
        ),
      );

      // Verify that our login elements are present
      expect(find.text('Login'), findsOneWidget);
      expect(
        find.byType(TextFormField),
        findsAtLeast(2),
      ); // Email and password fields
      expect(find.byType(ElevatedButton), findsOneWidget); // Login button
    });

    testWidgets('calls signIn when form is submitted with valid data', (
      WidgetTester tester,
    ) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthCubit>.value(
            value: mockAuthCubit,
            child: const LoginPage(),
          ),
        ),
      );

      // Enter text in the email field
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@example.com',
      );

      // Enter text in the password field
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');

      // Tap the login button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify that signIn was called with the right parameters
      verify(mockAuthCubit.signIn('test@example.com', 'password123')).called(1);
    });

    testWidgets('shows error when email is invalid', (
      WidgetTester tester,
    ) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthCubit>.value(
            value: mockAuthCubit,
            child: const LoginPage(),
          ),
        ),
      );

      // Enter invalid text in the email field
      await tester.enterText(find.byType(TextFormField).at(0), 'invalid-email');

      // Enter text in the password field
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');

      // Tap the login button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify that signIn was not called
      verifyNever(mockAuthCubit.signIn(any, any));

      // Verify that an error message is shown
      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });
  });

  group('RegisterPage Widget Tests', () {
    testWidgets('renders registration form', (WidgetTester tester) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthCubit>.value(
            value: mockAuthCubit,
            child: const RegisterPage(),
          ),
        ),
      );

      // Verify that our registration elements are present
      expect(find.text('Create Account'), findsOneWidget);
      expect(
        find.byType(TextFormField),
        findsAtLeast(3),
      ); // Name, email, and password fields
      expect(find.byType(Checkbox), findsOneWidget); // Terms checkbox
      expect(find.byType(ElevatedButton), findsOneWidget); // Register button
    });

    testWidgets(
      'calls signUp when form is submitted with valid data and terms accepted',
      (WidgetTester tester) async {
        // Build our app and trigger a frame
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<AuthCubit>.value(
              value: mockAuthCubit,
              child: const RegisterPage(),
            ),
          ),
        );

        // Enter text in the name field
        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');

        // Enter text in the email field
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'test@example.com',
        );

        // Enter text in the password field
        await tester.enterText(find.byType(TextFormField).at(2), 'password123');

        // Check the terms checkbox
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        // Tap the register button
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        // Verify that signUp was called with the right parameters
        verify(
          mockAuthCubit.signUp('test@example.com', 'password123', 'Test User'),
        ).called(1);
      },
    );

    testWidgets('shows error when terms are not accepted', (
      WidgetTester tester,
    ) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthCubit>.value(
            value: mockAuthCubit,
            child: const RegisterPage(),
          ),
        ),
      );

      // Enter text in the name field
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');

      // Enter text in the email field
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'test@example.com',
      );

      // Enter text in the password field
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');

      // Do NOT check the terms checkbox

      // Tap the register button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify that signUp was not called
      verifyNever(mockAuthCubit.signUp(any, any, any));

      // Verify that an error message is shown (in a SnackBar)
      expect(
        find.text('Please accept the terms and conditions'),
        findsOneWidget,
      );
    });
  });
}
