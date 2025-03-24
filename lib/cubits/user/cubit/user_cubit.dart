import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:task_management_app/domain/models/user.model.dart';
import 'package:task_management_app/domain/repositories/user.repository.dart';

part 'user_state.dart';

var logger = Logger();

// Helper class for caching users with timestamps
class _CachedUser {
  final User user;
  final DateTime timestamp;

  _CachedUser({required this.user, required this.timestamp});
}

class UserCubit extends Cubit<UserState> {
  final UserRepository _userRepository;
  final Map<String, _CachedUser> _userCache = {};
  final _cacheExpiryDuration = Duration(minutes: 30);
  final Map<String, Completer<User>> _pendingRequests = {};

  UserCubit(this._userRepository) : super(UserInitial());

  // Get user from cache or load from repository
  Future<void> loadUserById(String userId) async {
    // Check if we have a valid cached user
    final cachedUser = _getCachedUser(userId);
    if (cachedUser != null) {
      emit(UserLoaded(cachedUser));

      // If cache is fresh enough, don't reload
      if (!_isCacheExpired(userId)) {
        return;
      }
      // If expired, continue in background
    } else {
      emit(UserLoading());
    }

    // Check if this user is already being loaded
    if (_pendingRequests.containsKey(userId)) {
      try {
        // Wait for the existing request to complete
        final user = await _pendingRequests[userId]!.future;
        if (state is! UserLoaded || (state as UserLoaded).user.id != userId) {
          emit(UserLoaded(user));
        }
      } catch (_) {
        // Error handled in original request
      }
      return;
    }

    // Start new request
    final completer = Completer<User>();
    _pendingRequests[userId] = completer;

    try {
      final user = await _userRepository.getUserById(userId);

      // Update cache with timestamp
      _userCache[userId] = _CachedUser(user: user, timestamp: DateTime.now());

      completer.complete(user);

      // Only emit new state if this is still the relevant user
      if (state is! UserLoaded || (state as UserLoaded).user.id != userId) {
        emit(UserLoaded(user));
      }
    } catch (e) {
      completer.completeError(e);

      // Only emit error if we don't have cached data
      if (cachedUser == null) {
        emit(UserError('Failed to load user data: ${e.toString()}'));
      }
    } finally {
      _pendingRequests.remove(userId);
    }
  }

  // Get user synchronously from cache
  User? getUserFromCache(String userId) {
    return _getCachedUser(userId);
  }

  // Helper to get cached user
  User? _getCachedUser(String userId) {
    final cached = _userCache[userId];
    return cached?.user;
  }

  // Check if cache is expired
  bool _isCacheExpired(String userId) {
    final cached = _userCache[userId];
    if (cached == null) return true;

    final age = DateTime.now().difference(cached.timestamp);
    return age > _cacheExpiryDuration;
  }

  // Preload multiple users at once (e.g., for task assignees)
  Future<void> preloadUsers(List<String> userIds) async {
    if (userIds.isEmpty) return;

    // Filter to only load uncached or expired users
    final usersToLoad =
        userIds
            .where((id) => !_userCache.containsKey(id) || _isCacheExpired(id))
            .toList();

    if (usersToLoad.isEmpty) return;

    try {
      final users = await _userRepository.getUsersByIds(usersToLoad);

      // Update cache with fetched users
      final now = DateTime.now();
      for (final user in users) {
        _userCache[user.id] = _CachedUser(user: user, timestamp: now);
      }
    } catch (e) {
      // Log error but don't disrupt the UI
      print('Failed to preload users: $e');
    }
  }

  // Get multiple users by their IDs
  Future<void> loadUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return;

    // Filter out IDs we already have cached
    final uncachedIds =
        userIds.where((id) => !_userCache.containsKey(id)).toList();

    if (uncachedIds.isEmpty) {
      // All requested users are already in cache
      return;
    }

    try {
      final users = await _userRepository.getUsersByIds(uncachedIds);
      // Update cache with new users
      for (final user in users) {
        _userCache[user.id] = user as _CachedUser;
      }
      // No need to emit a state here as we're just updating the cache
    } catch (e) {
      logger.e('Failed to load users by IDs', error: e);
    }
  }

  // Get display name for a user (with fallback to ID)
  String getDisplayName(String userId) {
    final user = _userCache[userId];
    if (user == null) {
      // Try to load this user (for next time)
      loadUserById(userId);
      return userId; // Fallback to ID
    }

    return user.user.fullName ?? user.user.email;
  }

  bool isUserLoaded(String userId) {
    return state is UserLoaded && (state as UserLoaded).user.id == userId;
  }
}
