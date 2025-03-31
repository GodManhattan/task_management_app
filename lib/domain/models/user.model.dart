import 'package:equatable/equatable.dart';

/// Status of a user's account
enum UserStatus { active, inactive, pending }

/// User model representing a user in the system
class User extends Equatable {
  /// Unique identifier for the user (from Supabase Auth)
  final String id;

  /// User's email address
  final String email;

  /// User's full name
  final String? fullName;

  /// URL to the user's avatar image
  final String? avatarUrl;

  /// Current status of the user
  final UserStatus status;

  /// When the user was created in the system
  final DateTime createdAt;

  /// Whether the user is currently online
  final bool isOnline;

  /// Last time the user was active
  final DateTime? lastActive;

  /// Constructor
  const User({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.status = UserStatus.active,
    required this.createdAt,
    this.isOnline = false,
    this.lastActive,
  });

  /// Create a User from a JSON map
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      status: _parseStatus(json['status'] ?? 'active'),
      createdAt: DateTime.parse(json['created_at']),
      isOnline: json['is_online'] ?? false,
      lastActive:
          json['last_active'] != null
              ? DateTime.parse(json['last_active'])
              : null,
    );
  }

  /// Convert User to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'is_online': isOnline,
      'last_active': lastActive?.toIso8601String(),
    };
  }

  /// Create a copy of this User with some updated fields
  User copyWith({
    String? fullName,
    String? avatarUrl,
    UserStatus? status,
    String? role,
    bool? isOnline,
    DateTime? lastActive,
  }) {
    return User(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      createdAt: createdAt,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive ?? this.lastActive,
    );
  }

  /// Get user's initials for avatar placeholder
  String get initials {
    if (fullName == null || fullName!.isEmpty) {
      return email.substring(0, 1).toUpperCase();
    }

    final nameParts = fullName!.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }

    return nameParts[0].substring(0, 1).toUpperCase();
  }

  /// Parse user status from string
  static UserStatus _parseStatus(String status) {
    return UserStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => UserStatus.active,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    avatarUrl,
    status,
    createdAt,
    isOnline,
    lastActive,
  ];
}
