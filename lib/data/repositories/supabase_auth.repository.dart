import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/user.model.dart' as userModel;
import '../../domain/repositories/auth.repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabaseClient;
  var logger = Logger();

  SupabaseAuthRepository(this._supabaseClient);

  @override
  Future<userModel.User> signUp(
    String email,
    String password,
    String? fullName,
  ) async {
    try {
      // Include fullName in user metadata to be used by the trigger
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName ?? ''},
      );

      if (response.user == null) {
        throw Exception('Failed to sign up');
      }

      // Return user without trying to create profile manually
      return userModel.User(
        id: response.user!.id,
        email: email,
        fullName: fullName,
        status: userModel.UserStatus.active,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to sign up: ${e.toString()}');
    }
  }

  @override
  Future<userModel.User> signIn(String email, String password) async {
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Failed to sign in');
      }

      // Get user profile
      try {
        final profile =
            await _supabaseClient
                .from('profiles')
                .select()
                .eq('id', response.user!.id)
                .single();

        return userModel.User.fromJson(profile);
      } catch (e) {
        // If profile cannot be found, return basic user
        return userModel.User(
          id: response.user!.id,
          email: email,
          status: userModel.UserStatus.active,
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  @override
  Future<userModel.User?> getCurrentUser() async {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      return null;
    }

    try {
      final profile =
          await _supabaseClient
              .from('profiles')
              .select()
              .eq('id', currentUser.id)
              .single();

      return userModel.User.fromJson(profile);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    await _supabaseClient.auth.resetPasswordForEmail(email);
  }

  @override
  Future<userModel.User> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    await _supabaseClient
        .from('profiles')
        .update(updates)
        .eq('id', currentUser.id);

    final updatedProfile =
        await _supabaseClient
            .from('profiles')
            .select()
            .eq('id', currentUser.id)
            .single();

    return userModel.User.fromJson(updatedProfile);
  }

  @override
  Future<bool> isAuthenticated() async {
    return _supabaseClient.auth.currentUser != null;
  }

  /// Set up auth state change listener
  @override
  Stream<AuthState> onAuthStateChange() {
    return _supabaseClient.auth.onAuthStateChange;
  }

  // @override
  // Future<bool> isSessionValid() async {
  //   final currentSession = _supabaseClient.auth.currentSession;
  //   if (currentSession == null) return false;

  //   // Verifica si el token ha expirado o expirará en los próximos 5 minutos
  //   final expiresAt = DateTime.fromMillisecondsSinceEpoch(
  //     currentSession.expiresAt! * 1000,
  //   );
  //   return expiresAt.isAfter(DateTime.now().add(Duration(minutes: 5)));
  // }

  // @override
  // Future<void> refreshSession() async {
  //   final response = await _supabaseClient.auth.refreshSession();
  //   if (response.session == null) {
  //     throw Exception('No active session found');
  //   }
  // }

  @override
  Future<bool> ensureValidSession() async {
    try {
      final currentSession = _supabaseClient.auth.currentSession;
      if (currentSession == null) return false;

      // Check if session is about to expire (within 10 minutes)
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        currentSession.expiresAt! * 1000,
      );

      if (expiresAt.isAfter(DateTime.now().add(Duration(minutes: 10)))) {
        // Session is still valid
        return true;
      }

      // Session is close to expiration, refresh it
      logger.d('Session expiring soon, refreshing...');
      final response = await _supabaseClient.auth.refreshSession();
      return response.session != null;
    } catch (e) {
      logger.e('Error checking/refreshing session', error: e);
      return false;
    }
  }
}
