// lib/domain/models/team.model.dart
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum TeamRole { owner, admin, member }

class TeamMember extends Equatable {
  final String userId;
  final String teamId;
  final TeamRole role;
  final DateTime joinedAt;

  const TeamMember({
    required this.userId,
    required this.teamId,
    required this.role,
    required this.joinedAt,
  });

  factory TeamMember.create({
    required String userId,
    required String teamId,
    TeamRole role = TeamRole.member,
  }) {
    return TeamMember(
      userId: userId,
      teamId: teamId,
      role: role,
      joinedAt: DateTime.now(),
    );
  }

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      userId: json['user_id'],
      teamId: json['team_id'],
      role: _parseRole(json['role']),
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'team_id': teamId,
      'role': role.name,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  static TeamRole _parseRole(String role) {
    return TeamRole.values.firstWhere(
      (e) => e.name == role,
      orElse: () => TeamRole.member,
    );
  }

  @override
  List<Object?> get props => [userId, teamId, role, joinedAt];
}

class Team extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? avatarUrl;
  final List<TeamMember>? _members;

  const Team({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
    List<TeamMember>? members,
  }) : _members = members;

  // Getter for members
  List<TeamMember> get members => _members ?? const [];

  factory Team.create({
    required String name,
    String? description,
    required String ownerId,
  }) {
    final now = DateTime.now();
    return Team(
      id: const Uuid().v4(),
      name: name,
      description: description,
      ownerId: ownerId,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      ownerId: json['owner_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'avatar_url': avatarUrl,
    };
  }

  Team copyWith({
    String? name,
    String? description,
    String? avatarUrl,
    List<TeamMember>? members,
  }) {
    return Team(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      avatarUrl: avatarUrl ?? this.avatarUrl,
      members: members ?? _members,
    );
  }

  Team withMembers(List<TeamMember> members) {
    return Team(
      id: id,
      name: name,
      description: description,
      ownerId: ownerId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      avatarUrl: avatarUrl,
      members: members,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    ownerId,
    createdAt,
    updatedAt,
    avatarUrl,
    members,
  ];
}
