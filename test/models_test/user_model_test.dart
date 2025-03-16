// 3. User Model Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:task_management_app/domain/models/user.model.dart';

void main() {
  group('User Model', () {
    test('should create a User instance with all properties', () {
      // Arrange
      final now = DateTime.now();

      // Act
      final user = User(
        id: '12345',
        email: 'test@example.com',
        fullName: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
        status: UserStatus.active,
        createdAt: now,
        role: 'admin',
        isOnline: true,
        lastActive: now,
      );

      // Assert
      expect(user.id, '12345');
      expect(user.email, 'test@example.com');
      expect(user.fullName, 'Test User');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
      expect(user.status, UserStatus.active);
      expect(user.createdAt, now);
      expect(user.role, 'admin');
      expect(user.isOnline, true);
      expect(user.lastActive, now);
    });

    test('should create a User with default values when not provided', () {
      // Arrange
      final now = DateTime.now();

      // Act
      final user = User(id: '12345', email: 'test@example.com', createdAt: now);

      // Assert
      expect(user.fullName, null);
      expect(user.avatarUrl, null);
      expect(user.status, UserStatus.active);
      expect(user.role, 'member');
      expect(user.isOnline, false);
      expect(user.lastActive, null);
    });

    test('should create a User from JSON', () {
      // Arrange
      final json = {
        'id': '12345',
        'email': 'test@example.com',
        'full_name': 'Test User',
        'avatar_url': 'https://example.com/avatar.jpg',
        'status': 'active',
        'created_at': '2023-01-01T12:00:00Z',
        'role': 'admin',
        'is_online': true,
        'last_active': '2023-01-01T13:00:00Z',
      };

      // Act
      final user = User.fromJson(json);

      // Assert
      expect(user.id, '12345');
      expect(user.email, 'test@example.com');
      expect(user.fullName, 'Test User');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
      expect(user.status, UserStatus.active);
      expect(user.createdAt, DateTime.parse('2023-01-01T12:00:00Z'));
      expect(user.role, 'admin');
      expect(user.isOnline, true);
      expect(user.lastActive, DateTime.parse('2023-01-01T13:00:00Z'));
    });

    test('should convert User to JSON', () {
      // Arrange
      final createdAt = DateTime.parse('2023-01-01T12:00:00Z');
      final lastActive = DateTime.parse('2023-01-01T13:00:00Z');

      final user = User(
        id: '12345',
        email: 'test@example.com',
        fullName: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
        status: UserStatus.active,
        createdAt: createdAt,
        role: 'admin',
        isOnline: true,
        lastActive: lastActive,
      );

      // Act
      final json = user.toJson();

      // Assert
      expect(json['id'], '12345');
      expect(json['email'], 'test@example.com');
      expect(json['full_name'], 'Test User');
      expect(json['avatar_url'], 'https://example.com/avatar.jpg');
      expect(json['status'], 'active');
      expect(json['created_at'], createdAt.toIso8601String());
      expect(json['role'], 'admin');
      expect(json['is_online'], true);
      expect(json['last_active'], lastActive.toIso8601String());
    });

    test('copyWith should update only the specified fields', () {
      // Arrange
      final now = DateTime.now();
      final user = User(
        id: '12345',
        email: 'test@example.com',
        fullName: 'Test User',
        createdAt: now,
      );

      // Act
      final updatedUser = user.copyWith(
        fullName: 'Updated Name',
        avatarUrl: 'https://example.com/new-avatar.jpg',
      );

      // Assert
      expect(updatedUser.id, '12345'); // Unchanged
      expect(updatedUser.email, 'test@example.com'); // Unchanged
      expect(updatedUser.fullName, 'Updated Name'); // Changed
      expect(
        updatedUser.avatarUrl,
        'https://example.com/new-avatar.jpg',
      ); // Changed
      expect(updatedUser.createdAt, now); // Unchanged
    });

    test('initials returns correct value for full name', () {
      // Arrange
      final user = User(
        id: '12345',
        email: 'test@example.com',
        fullName: 'John Doe',
        createdAt: DateTime.now(),
      );

      // Act & Assert
      expect(user.initials, 'JD');
    });

    test('initials returns first letter of email when no full name', () {
      // Arrange
      final user = User(
        id: '12345',
        email: 'test@example.com',
        createdAt: DateTime.now(),
      );

      // Act & Assert
      expect(user.initials, 'T');
    });

    test('isAdmin returns true for admin role', () {
      // Arrange
      final user = User(
        id: '12345',
        email: 'admin@example.com',
        role: 'admin',
        createdAt: DateTime.now(),
      );

      // Act & Assert
      expect(user.isAdmin, true);
    });

    test('isAdmin returns false for non-admin role', () {
      // Arrange
      final user = User(
        id: '12345',
        email: 'user@example.com',
        role: 'member',
        createdAt: DateTime.now(),
      );

      // Act & Assert
      expect(user.isAdmin, false);
    });
  });
}
