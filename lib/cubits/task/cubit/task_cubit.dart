import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:task_management_app/domain/models/task.model.dart';
import 'package:task_management_app/domain/repositories/task.repository.dart';

part 'task_state.dart';

var logger = Logger();

class TaskCubit extends Cubit<TaskState> {
  final TaskRepository _taskRepository;
  List<Task> _cachedTasks = []; // Cache the tasks

  TaskCubit(this._taskRepository) : super(TaskInitial());

  // Load all tasks for the current user
  Future<void> loadTasks({bool forceRefresh = false}) async {
    // Don't reload if we already have tasks cached (unless forced)
    if (_cachedTasks.isNotEmpty && !forceRefresh) {
      emit(TasksLoaded(_cachedTasks));
      return;
    }

    emit(TaskLoading());
    try {
      final tasks = await _taskRepository.getTasks();
      _cachedTasks = tasks; // Cache the tasks
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
      _cachedTasks = tasks; // Update the cache
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
      _cachedTasks = tasks; // Update the cache
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
      _cachedTasks = tasks; // Update the cache
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

      // Update the task in the cache if it exists
      final index = _cachedTasks.indexWhere((t) => t.id == id);
      if (index >= 0) {
        _cachedTasks[index] = task;
      }
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

      // Add to cache
      _cachedTasks = [createdTask, ..._cachedTasks];
      emit(TasksLoaded(_cachedTasks));
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

      // Update in cache
      final index = _cachedTasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        _cachedTasks[index] = updatedTask;
      }

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
    // Store current tasks state for rollback
    final previousTasks = List<Task>.from(_cachedTasks);
    // Optimistically update UI
    _cachedTasks.removeWhere((task) => task.id == id);
    emit(TasksLoaded(_cachedTasks));
    try {
      await _taskRepository.deleteTask(id);
      emit(TaskOperationSuccess('Task deleted successfully'));
      emit(TasksLoaded(_cachedTasks));
    } catch (e) {
      // Restore previous state on error
      emit(TaskError('Failed to delete task: ${e.toString()}'));
      _cachedTasks = previousTasks;
      emit(TasksLoaded(_cachedTasks));
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
      final result = await _taskRepository.updateTask(updatedTask);

      // Update in cache
      final index = _cachedTasks.indexWhere((t) => t.id == taskId);
      if (index >= 0) {
        _cachedTasks[index] = result;
      }

      emit(TaskOperationSuccess('Task status updated successfully'));
      // After success, load the updated task details
      emit(TaskDetailLoaded(result));
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
      final result = await _taskRepository.updateTask(updatedTask);

      // Update in cache
      final index = _cachedTasks.indexWhere((t) => t.id == taskId);
      if (index >= 0) {
        _cachedTasks[index] = result;
      }

      emit(TaskOperationSuccess('Task assigned successfully'));
      // After success, load the updated task details
      emit(TaskDetailLoaded(result));
    } catch (e) {
      emit(TaskError('Failed to assign task: ${e.toString()}'));
      logger.e('Failed to assign task', error: e);
    }
  }

  // Initialize real-time subscription to tasks
  void subscribeToTasks() {
    try {
      _taskRepository.subscribeToTasks().listen((tasks) {
        _cachedTasks = tasks; // Update the cache with real-time data
        emit(TasksLoaded(tasks));
      });
    } catch (e) {
      logger.e('Failed to subscribe to tasks', error: e);
      // Don't emit error state here as it might disrupt current state
    }
  }
}
