import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_management_app/domain/models/user.model.dart' as usermodel;

import '../../../domain/repositories/auth.repository.dart';

part 'auth_state.dart';

var logger = Logger();

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription? _authSubscription;

  AuthCubit(this._authRepository) : super(AuthInitial()) {
    _initialize();
  }

  Future<void> _initialize() async {
    emit(AuthLoading());

    // Listen to auth state changes
    _authSubscription = _authRepository.onAuthStateChange().listen((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        _getCurrentUser();
      } else if (event.event == AuthChangeEvent.signedOut) {
        emit(AuthUnauthenticated());
      }
    });
    // Check current auth state
    await _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError('Failed to get current user: ${e.toString()}'));
    }
  }

  Future<void> signIn(
    String email,
    String password,
    BuildContext context,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signIn(email, password);
      emit(AuthAuthenticated(user));
      // // Navigate to tasks page
      // if (context.mounted) {
      //   context.go('/tasks');
      // }
    } catch (e) {
      emit(AuthError('Failed to sign in: ${e.toString()}'));
    }
  }

  Future<void> signUp(String email, String password, String? fullName) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signUp(email, password, fullName);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError('Failed to sign up: ${e.toString()}'));
      logger.d(e);
    }
  }

  Future<void> signOut() async {
    emit(AuthLoading());
    try {
      await _authRepository.signOut();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError('Failed to sign out: ${e.toString()}'));
    }
  }

  Future<void> resetPassword(String email) async {
    emit(AuthLoading());
    try {
      await _authRepository.resetPassword(email);
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError('Failed to reset password: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }

  Future<void> refreshAuthState() async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user as usermodel.User));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> verifySession() async {
    emit(AuthLoading());
    try {
      bool sessionValid = await _authRepository.ensureValidSession();
      if (!sessionValid) {
        emit(AuthUnauthenticated());
        return;
      }
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user as usermodel.User));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }
}
