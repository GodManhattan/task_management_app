import '../models/user.model.dart';

abstract class UserRepository {
  /// Get user profile by ID
  Future<User> getUserById(String id);

  /// Get multiple users by their IDs
  Future<List<User>> getUsersByIds(List<String> ids);

  /// Get current authenticated user
  Future<User> getCurrentUser();
}
