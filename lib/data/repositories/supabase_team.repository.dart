// lib/data/repositories/supabase_team.repository.dart
import 'dart:async';

import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/team.model.dart';
import '../../domain/repositories/team.repository.dart';
import '../../core/services/realtime_service.dart';

class SupabaseTeamRepository implements TeamRepository {
  final SupabaseClient _supabaseClient;
  final RealtimeService _realtimeService;
  final Logger _logger = Logger();

  SupabaseTeamRepository(this._supabaseClient)
    : _realtimeService = RealtimeService(_supabaseClient);

  @override
  Future<List<Team>> getTeams() async {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    try {
      // Get teams where user is a member or owner
      final response = await _supabaseClient.rpc(
        'get_user_teams',
        params: {'user_id_param': currentUser.id},
      );

      return (response as List<dynamic>)
          .map((json) => Team.fromJson(json))
          .toList();
    } catch (e) {
      _logger.e('Error fetching teams', error: e);
      rethrow;
    }
  }

  @override
  Future<Team> getTeamById(String id) async {
    try {
      // Get team data
      final teamData =
          await _supabaseClient.from('teams').select().eq('id', id).single();

      final team = Team.fromJson(teamData);

      // Get team members
      final membersData = await _supabaseClient
          .from('team_members')
          .select()
          .eq('team_id', id);

      final members =
          membersData
              .map<TeamMember>((json) => TeamMember.fromJson(json))
              .toList();

      return team.withMembers(members);
    } catch (e) {
      _logger.e('Error fetching team by id', error: e);
      rethrow;
    }
  }

  @override
  Future<Team> createTeam(Team team) async {
    try {
      // Begin transaction
      await _supabaseClient.rpc('begin_transaction');

      // Insert team
      final teamData =
          await _supabaseClient
              .from('teams')
              .insert(team.toJson())
              .select()
              .single();

      final createdTeam = Team.fromJson(teamData);

      try {
        // Add owner as a team member with owner role
        await _supabaseClient.from('team_members').insert({
          'team_id': createdTeam.id,
          'user_id': createdTeam.ownerId,
          'role': TeamRole.owner.name,
          'joined_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        _logger.w(
          'Error adding team owner as member, but team was created: $e',
        );
        // Continue anyway since the team was created successfully
      }

      // Commit transaction
      await _supabaseClient.rpc('commit_transaction');

      return createdTeam;
    } catch (e) {
      // Rollback on error
      await _supabaseClient.rpc('rollback_transaction');
      _logger.e('Error creating team', error: e);
      rethrow;
    }
  }

  @override
  Future<Team> updateTeam(Team team) async {
    try {
      final updatedData =
          await _supabaseClient
              .from('teams')
              .update(team.toJson())
              .eq('id', team.id)
              .select()
              .single();

      return Team.fromJson(updatedData);
    } catch (e) {
      _logger.e('Error updating team', error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteTeam(String id) async {
    try {
      // Delete team (team_members will be cascaded)
      await _supabaseClient.from('teams').delete().eq('id', id);
    } catch (e) {
      _logger.e('Error deleting team', error: e);
      rethrow;
    }
  }

  @override
  Future<TeamMember> addTeamMember(
    String teamId,
    String userId, {
    TeamRole role = TeamRole.member,
  }) async {
    try {
      final memberData =
          await _supabaseClient
              .from('team_members')
              .insert({
                'team_id': teamId,
                'user_id': userId,
                'role': role.name,
                'joined_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

      return TeamMember.fromJson(memberData);
    } catch (e) {
      _logger.e('Error adding team member', error: e);
      rethrow;
    }
  }

  @override
  Future<void> removeTeamMember(String teamId, String userId) async {
    try {
      await _supabaseClient
          .from('team_members')
          .delete()
          .eq('team_id', teamId)
          .eq('user_id', userId);
    } catch (e) {
      _logger.e('Error removing team member', error: e);
      rethrow;
    }
  }

  @override
  Future<TeamMember> updateMemberRole(
    String teamId,
    String userId,
    TeamRole newRole,
  ) async {
    try {
      final memberData =
          await _supabaseClient
              .from('team_members')
              .update({'role': newRole.name})
              .eq('team_id', teamId)
              .eq('user_id', userId)
              .select()
              .single();

      return TeamMember.fromJson(memberData);
    } catch (e) {
      _logger.e('Error updating member role', error: e);
      rethrow;
    }
  }

  @override
  Future<List<TeamMember>> getTeamMembers(String teamId) async {
    try {
      final membersData = await _supabaseClient
          .from('team_members')
          .select()
          .eq('team_id', teamId);

      return membersData
          .map<TeamMember>((json) => TeamMember.fromJson(json))
          .toList();
    } catch (e) {
      _logger.e('Error getting team members', error: e);
      rethrow;
    }
  }

  @override
  Stream<List<Team>> subscribeToTeams() {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    return _realtimeService.createTableSubscription<Team>(
      table: 'teams',
      primaryKey: 'id',
      fromJson: (json) => Team.fromJson(json),
      eq: 'owner_id',
      eqValue: currentUser.id,
    );
  }

  @override
  Stream<List<TeamMember>> subscribeToTeamMembers(String teamId) {
    return _realtimeService.createTableSubscription<TeamMember>(
      table: 'team_members',
      primaryKey: 'id',
      fromJson: (json) => TeamMember.fromJson(json),
      eq: 'team_id',
      eqValue: teamId,
    );
  }

  void dispose() {
    _realtimeService.dispose();
  }
}
