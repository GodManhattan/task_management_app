// lib/cubits/team/cubit/team_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:task_management_app/domain/models/team.model.dart';
import 'package:task_management_app/domain/repositories/team.repository.dart';

part 'team_state.dart';

class TeamCubit extends Cubit<TeamState> {
  final TeamRepository _teamRepository;
  final Logger _logger = Logger();

  TeamCubit(this._teamRepository) : super(TeamInitial());

  Future<void> loadTeams() async {
    emit(TeamLoading());
    try {
      final teams = await _teamRepository.getTeams();
      emit(TeamsLoaded(teams));
    } catch (e) {
      _logger.e('Failed to load teams', error: e);
      emit(TeamError('Failed to load teams: ${e.toString()}'));
    }
  }

  Future<void> loadTeamById(String id) async {
    emit(TeamLoading());
    try {
      final team = await _teamRepository.getTeamById(id);
      emit(TeamDetailLoaded(team));
    } catch (e) {
      _logger.e('Failed to load team', error: e);
      emit(TeamError('Failed to load team: ${e.toString()}'));
    }
  }

  Future<void> createTeam(Team team) async {
    emit(TeamLoading());
    try {
      final createdTeam = await _teamRepository.createTeam(team);
      emit(TeamOperationSuccess('Team created successfully'));
      loadTeams(); // Reload teams list
    } catch (e) {
      _logger.e('Failed to create team', error: e);
      emit(TeamError('Failed to create team: ${e.toString()}'));
    }
  }

  Future<void> updateTeam(Team team) async {
    emit(TeamLoading());
    try {
      final updatedTeam = await _teamRepository.updateTeam(team);
      emit(TeamOperationSuccess('Team updated successfully'));
      emit(TeamDetailLoaded(updatedTeam));
    } catch (e) {
      _logger.e('Failed to update team', error: e);
      emit(TeamError('Failed to update team: ${e.toString()}'));
    }
  }

  Future<void> deleteTeam(String id) async {
    emit(TeamLoading());
    try {
      await _teamRepository.deleteTeam(id);
      emit(TeamOperationSuccess('Team deleted successfully'));
      loadTeams(); // Reload teams list
    } catch (e) {
      _logger.e('Failed to delete team', error: e);
      emit(TeamError('Failed to delete team: ${e.toString()}'));
    }
  }

  Future<void> addTeamMember(
    String teamId,
    String userId, {
    TeamRole role = TeamRole.member,
  }) async {
    try {
      await _teamRepository.addTeamMember(teamId, userId, role: role);
      emit(TeamOperationSuccess('Member added successfully'));
      loadTeamById(teamId); // Reload team details
    } catch (e) {
      _logger.e('Failed to add team member', error: e);
      emit(TeamError('Failed to add member: ${e.toString()}'));
    }
  }

  Future<void> removeTeamMember(String teamId, String userId) async {
    try {
      await _teamRepository.removeTeamMember(teamId, userId);
      emit(TeamOperationSuccess('Member removed successfully'));
      loadTeamById(teamId); // Reload team details
    } catch (e) {
      _logger.e('Failed to remove team member', error: e);
      emit(TeamError('Failed to remove member: ${e.toString()}'));
    }
  }

  Future<void> updateMemberRole(
    String teamId,
    String userId,
    TeamRole newRole,
  ) async {
    try {
      await _teamRepository.updateMemberRole(teamId, userId, newRole);
      emit(TeamOperationSuccess('Member role updated successfully'));
      loadTeamById(teamId); // Reload team details
    } catch (e) {
      _logger.e('Failed to update member role', error: e);
      emit(TeamError('Failed to update member role: ${e.toString()}'));
    }
  }

  void subscribeToTeams() {
    try {
      _teamRepository.subscribeToTeams().listen((teams) {
        emit(TeamsLoaded(teams));
      });
    } catch (e) {
      _logger.e('Failed to subscribe to teams', error: e);
      // Don't emit error to avoid disrupting current state
    }
  }

  void subscribeToTeamMembers(String teamId) {
    try {
      _teamRepository.subscribeToTeamMembers(teamId).listen((members) {
        if (state is TeamDetailLoaded) {
          final currentTeam = (state as TeamDetailLoaded).team;
          emit(TeamDetailLoaded(currentTeam.withMembers(members)));
        }
      });
    } catch (e) {
      _logger.e('Failed to subscribe to team members', error: e);
      // Don't emit error to avoid disrupting current state
    }
  }
}
