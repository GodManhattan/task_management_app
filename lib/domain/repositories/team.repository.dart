// lib/domain/repositories/team.repository.dart
import '../../domain/models/team.model.dart';

abstract class TeamRepository {
  /// Get all teams for the current user
  Future<List<Team>> getTeams();

  /// Get a specific team by ID with member information
  Future<Team> getTeamById(String id);

  /// Create a new team
  Future<Team> createTeam(Team team);

  /// Update an existing team
  Future<Team> updateTeam(Team team);

  /// Delete a team
  Future<void> deleteTeam(String id);

  /// Add a user to a team
  Future<TeamMember> addTeamMember(
    String teamId,
    String userId, {
    TeamRole role = TeamRole.member,
  });

  /// Remove a user from a team
  Future<void> removeTeamMember(String teamId, String userId);

  /// Update a member's role
  Future<TeamMember> updateMemberRole(
    String teamId,
    String userId,
    TeamRole newRole,
  );

  /// Get team members
  Future<List<TeamMember>> getTeamMembers(String teamId);

  /// Subscribe to real-time team updates
  Stream<List<Team>> subscribeToTeams();

  /// Subscribe to real-time team member updates
  Stream<List<TeamMember>> subscribeToTeamMembers(String teamId);
}
