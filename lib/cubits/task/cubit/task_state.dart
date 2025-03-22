// task_state.dart
part of 'task_cubit.dart';

abstract class TaskState extends Equatable {
  const TaskState();

  @override
  List<Object?> get props => [];
}

class TaskInitial extends TaskState {}

class TaskLoading extends TaskState {
  // Include a reference to where we're loading from to maintain context
  final bool forHistoryView;

  const TaskLoading({this.forHistoryView = false});

  @override
  List<Object?> get props => [forHistoryView];
}

class TasksLoaded extends TaskState {
  final List<Task> tasks;
  final bool isHistoryView;

  const TasksLoaded(this.tasks, {this.isHistoryView = false});

  @override
  List<Object?> get props => [tasks, isHistoryView];
}

class TaskDetailLoaded extends TaskState {
  final Task task;

  const TaskDetailLoaded(this.task);

  @override
  List<Object?> get props => [task];
}

class TaskOperationSuccess extends TaskState {
  final String message;

  const TaskOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class TaskError extends TaskState {
  final String message;
  final bool isHistoryView;

  const TaskError(this.message, {this.isHistoryView = false});

  @override
  List<Object?> get props => [message, isHistoryView];
}
