import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:task_management_app/domain/models/user.model.dart';
import 'package:task_management_app/domain/repositories/user.repository.dart';

part 'user_state.dart';

var logger = Logger();

class UserCubit extends Cubit<UserState> {
  final UserRepository _userRepository;
  final Map<String, User> _userCache = {}; // Local cache for users

  UserCubit(this._userRepository) : super(UserInitial());

  // Get a user by their ID
  Future<void> loadUserById(String userId) async {
    // Check if we already have this user in cache
    if (_userCache.containsKey(userId)) {
      emit(UserLoaded(_userCache[userId]!));
      return;
    }

    emit(UserLoading());
    try {
      final user = await _userRepository.getUserById(userId);
      // Update cache
      _userCache[userId] = user;
      emit(UserLoaded(user));
    } catch (e) {
      logger.e('Failed to load user by ID', error: e);
      // Don't emit error state to avoid UI disruption
      // Just keep the current state
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
        _userCache[user.id] = user;
      }
      // No need to emit a state here as we're just updating the cache
    } catch (e) {
      logger.e('Failed to load users by IDs', error: e);
    }
  }

  // Get a user from cache (or null if not found)
  User? getUserFromCache(String userId) {
    return _userCache[userId];
  }

  // Get display name for a user (with fallback to ID)
  String getDisplayName(String userId) {
    final user = _userCache[userId];
    if (user == null) {
      // Try to load this user (for next time)
      loadUserById(userId);
      return userId; // Fallback to ID
    }

    return user.fullName ?? user.email;
  }

  bool isUserLoaded(String userId) {
    return state is UserLoaded && (state as UserLoaded).user.id == userId;
  }
}
