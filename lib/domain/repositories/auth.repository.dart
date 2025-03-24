import '../../domain/models/user.model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

abstract class AuthRepository {
  /// Sign up a new user with email and password
  Future<User> signUp(String email, String password, String? fullName);

  /// Sign in with email and password
  Future<User> signIn(String email, String password);

  /// Sign out the current user
  Future<void> signOut();

  /// Get the current user
  Future<User?> getCurrentUser();

  /// Reset password for email
  Future<void> resetPassword(String email);

  /// Update user profile
  Future<User> updateProfile({String? fullName, String? avatarUrl});

  /// Check if user is authenticated
  Future<bool> isAuthenticated();

  /// Set up auth state change listener
  Stream<supabase.AuthState> onAuthStateChange();

  // Future<bool> isSessionValid();
  // Future<void> refreshSession();
  Future<bool> ensureValidSession();
}
