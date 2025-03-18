// task_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:task_management_app/domain/models/task.model.dart';
import 'package:task_management_app/domain/repositories/task.repository.dart';

part 'task_state.dart';

var logger = Logger();

class TaskCubit extends Cubit<TaskState> {
  final TaskRepository _taskRepository;

  TaskCubit(this._taskRepository) : super(TaskInitial());

  // Load all tasks for the current user
  Future<void> loadTasks() async {
    emit(TaskLoading());
    try {
      final tasks = await _taskRepository.getTasks();
      emit(TasksLoaded(tasks));
    } catch (e) {
      emit(TaskError('Failed to load tasks: ${e.toString()}'));
      logger.e('Failed to load tasks', error: e);
    }
  }

  // Load tasks filtered by status
  Future<void> loadTasksByStatus(TaskStatus status) async {
    emit(TaskLoading());
    try {
      final tasks = await _taskRepository.getTasksByStatus(status);
      emit(TasksLoaded(tasks));
    } catch (e) {
      emit(TaskError('Failed to load tasks: ${e.toString()}'));
      logger.e('Failed to load tasks by status', error: e);
    }
  }

  // Load tasks assigned to a specific user
  Future<void> loadTasksByAssignee(String userId) async {
    emit(TaskLoading());
    try {
      final tasks = await _taskRepository.getTasksByAssignee(userId);
      emit(TasksLoaded(tasks));
    } catch (e) {
      emit(TaskError('Failed to load tasks: ${e.toString()}'));
      logger.e('Failed to load tasks by assignee', error: e);
    }
  }

  // Search tasks
  Future<void> searchTasks(String query) async {
    emit(TaskLoading());
    try {
      final tasks = await _taskRepository.searchTasks(query);
      emit(TasksLoaded(tasks));
    } catch (e) {
      emit(TaskError('Failed to search tasks: ${e.toString()}'));
      logger.e('Failed to search tasks', error: e);
    }
  }

  // Load a specific task by ID
  Future<void> loadTaskById(String id) async {
    emit(TaskLoading());
    try {
      final task = await _taskRepository.getTaskById(id);
      emit(TaskDetailLoaded(task));
    } catch (e) {
      emit(TaskError('Failed to load task: ${e.toString()}'));
      logger.e('Failed to load task by ID', error: e);
    }
  }

  // Create a new task
  Future<void> createTask(Task task) async {
    emit(TaskLoading());
    try {
      final createdTask = await _taskRepository.createTask(task);
      emit(TaskOperationSuccess('Task created successfully'));
      // After success, load the newly created task details
      emit(TaskDetailLoaded(createdTask));
    } catch (e) {
      emit(TaskError('Failed to create task: ${e.toString()}'));
      logger.e('Failed to create task', error: e);
    }
  }

  // Update an existing task
  Future<void> updateTask(Task task) async {
    emit(TaskLoading());
    try {
      final updatedTask = await _taskRepository.updateTask(task);
      emit(TaskOperationSuccess('Task updated successfully'));
      // After success, load the updated task details
      emit(TaskDetailLoaded(updatedTask));
    } catch (e) {
      emit(TaskError('Failed to update task: ${e.toString()}'));
      logger.e('Failed to update task', error: e);
    }
  }

  // Delete a task
  Future<void> deleteTask(String id) async {
    emit(TaskLoading());
    try {
      await _taskRepository.deleteTask(id);
      emit(TaskOperationSuccess('Task deleted successfully'));
      // After success, load all tasks again
      await loadTasks();
    } catch (e) {
      emit(TaskError('Failed to delete task: ${e.toString()}'));
      logger.e('Failed to delete task', error: e);
    }
  }

  // Change task status
  Future<void> changeTaskStatus(String taskId, TaskStatus newStatus) async {
    emit(TaskLoading());
    try {
      // First get the current task
      final task = await _taskRepository.getTaskById(taskId);
      // Create a new task with updated status
      final updatedTask = task.copyWith(status: newStatus);
      // Update the task
      await _taskRepository.updateTask(updatedTask);

      emit(TaskOperationSuccess('Task status updated successfully'));
      // After success, load the updated task details
      emit(TaskDetailLoaded(updatedTask));
    } catch (e) {
      emit(TaskError('Failed to change task status: ${e.toString()}'));
      logger.e('Failed to change task status', error: e);
    }
  }

  // Assign task to a user
  Future<void> assignTask(String taskId, String assigneeId) async {
    emit(TaskLoading());
    try {
      // First get the current task
      final task = await _taskRepository.getTaskById(taskId);
      // Create a new task with updated assignee
      final updatedTask = task.copyWith(assigneeId: assigneeId);
      // Update the task
      await _taskRepository.updateTask(updatedTask);

      emit(TaskOperationSuccess('Task assigned successfully'));
      // After success, load the updated task details
      emit(TaskDetailLoaded(updatedTask));
    } catch (e) {
      emit(TaskError('Failed to assign task: ${e.toString()}'));
      logger.e('Failed to assign task', error: e);
    }
  }

  // Initialize real-time subscription to tasks
  void subscribeToTasks() {
    try {
      _taskRepository.subscribeToTasks().listen((tasks) {
        emit(TasksLoaded(tasks));
      });
    } catch (e) {
      logger.e('Failed to subscribe to tasks', error: e);
      // Don't emit error state here as it might disrupt current state
      //If you still want to notify the user about the failure without
      //disrupting the state, consider using a separate UI message instead
      // showSnackbar(
      //   'Real-time updates are unavailable, but you can still refresh manually.',
      // );
    }
  }
}
