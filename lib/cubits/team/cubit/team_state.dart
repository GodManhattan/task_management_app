// lib/cubits/team/cubit/team_state.dart
part of 'team_cubit.dart';

abstract class TeamState extends Equatable {
  const TeamState();

  @override
  List<Object?> get props => [];
}

class TeamInitial extends TeamState {}

class TeamLoading extends TeamState {}

class TeamsLoaded extends TeamState {
  final List<Team> teams;

  const TeamsLoaded(this.teams);

  @override
  List<Object?> get props => [teams];
}

class TeamDetailLoaded extends TeamState {
  final Team team;

  const TeamDetailLoaded(this.team);

  @override
  List<Object?> get props => [team];
}

class TeamOperationSuccess extends TeamState {
  final String message;

  const TeamOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class TeamError extends TeamState {
  final String message;

  const TeamError(this.message);

  @override
  List<Object?> get props => [message];
}
