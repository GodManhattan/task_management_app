// 2. Auth Cubit Tests
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:task_management_app/cubits/auth/auth_cubit.dart';
import 'package:task_management_app/domain/models/user.model.dart';
import 'package:task_management_app/domain/repositories/auth.repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'dart:async';
import 'auth_cubit_test.mocks.dart';
// Generate mock for AuthRepository
@GenerateMocks([AuthRepository])


void main() {
  group('AuthCubit', () {
    late MockAuthRepository mockAuthRepository;
    late AuthCubit authCubit;

    setUp(() {
      mockAuthRepository = MockAuthRepository();

      // Mock the auth state change stream
      final controller = StreamController<supabase.AuthState>();
      when(
        mockAuthRepository.onAuthStateChange(),
      ).thenAnswer((_) => controller.stream);

      // Mock the getCurrentUser method to return null initially
      when(mockAuthRepository.getCurrentUser()).thenAnswer((_) async => null);

      authCubit = AuthCubit(mockAuthRepository);
    });

    tearDown(() {
      authCubit.close();
    });

    test('initial state is AuthInitial', () {
      expect(authCubit.state, isA<AuthInitial>());
    });

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when initialized without a user',
      build: () {
        when(mockAuthRepository.getCurrentUser()).thenAnswer((_) async => null);
        return AuthCubit(mockAuthRepository);
      },
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when initialized with a user',
      build: () {
        final user = User(
          id: '12345',
          email: 'test@example.com',
          fullName: 'Test User',
          status: UserStatus.active,
          createdAt: DateTime.now(),
        );

        when(mockAuthRepository.getCurrentUser()).thenAnswer((_) async => user);
        return AuthCubit(mockAuthRepository);
      },
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when signIn succeeds',
      build: () {
        final user = User(
          id: '12345',
          email: 'test@example.com',
          fullName: 'Test User',
          status: UserStatus.active,
          createdAt: DateTime.now(),
        );

        when(
          mockAuthRepository.signIn('test@example.com', 'password123'),
        ).thenAnswer((_) async => user);

        return authCubit;
      },
      act: (cubit) => cubit.signIn('test@example.com', 'password123'),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthError] when signIn fails',
      build: () {
        when(
          mockAuthRepository.signIn('test@example.com', 'password123'),
        ).thenThrow(Exception('Invalid credentials'));

        return authCubit;
      },
      act: (cubit) => cubit.signIn('test@example.com', 'password123'),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when signUp succeeds',
      build: () {
        final user = User(
          id: '12345',
          email: 'test@example.com',
          fullName: 'Test User',
          status: UserStatus.active,
          createdAt: DateTime.now(),
        );

        when(
          mockAuthRepository.signUp(
            'test@example.com',
            'password123',
            'Test User',
          ),
        ).thenAnswer((_) async => user);

        return authCubit;
      },
      act:
          (cubit) =>
              cubit.signUp('test@example.com', 'password123', 'Test User'),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when signOut succeeds',
      build: () {
        when(mockAuthRepository.signOut()).thenAnswer((_) async => {});
        return authCubit;
      },
      act: (cubit) => cubit.signOut(),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );
  });
}
