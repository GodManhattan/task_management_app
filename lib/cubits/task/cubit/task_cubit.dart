import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:task_management_app/domain/models/task.model.dart';
import 'package:task_management_app/domain/repositories/task.repository.dart';

part 'task_state.dart';

var logger = Logger();

class TaskCubit extends Cubit<TaskState> {
  final TaskRepository _taskRepository;
  Stream<List<Task>>? _tasksStream;
  bool _isStreamInitialized = false;
  List<Task> _cachedTasks = []; // Cache active tasks
  List<Task> _cachedHistoryTasks = [];

  // Track whether subscriptions are active
  bool _tasksSubscriptionActive = false;
  bool _historySubscriptionActive = false;

  TaskCubit(this._taskRepository) : super(TaskInitial()) {}

  // stream getter that ensures the stream is initialized
  Stream<List<Task>> get tasksStream {
    if (!_isStreamInitialized) {
      _isStreamInitialized = true;
      _tasksStream = _taskRepository.subscribeToTasks();
    }
    return _tasksStream!;
  }

  // In task_cubit.dart
  Future<void> loadTasks({
    TaskStatus? status,
    bool isHistory = false,
    bool forceRefresh = false,
  }) async {
    emit(TaskLoading(forHistoryView: isHistory));

    try {
      final List<Task> tasks;

      if (status != null) {
        tasks = await _taskRepository.getTasksByStatus(status);
      } else if (isHistory) {
        tasks = await _taskRepository.getTasksHistory();
      } else {
        tasks = await _taskRepository.getTasks();
      }

      emit(TasksLoaded(tasks, isHistoryView: isHistory));
    } catch (e) {
      emit(
        TaskError(
          'Failed to load tasks: ${e.toString()}',
          isHistoryView: isHistory,
        ),
      );
    }
  }

  // Modified to ensure it loads active tasks
  void clearHistoryCache() {
    emit(TaskInitial()); // Reset state before loading fresh tasks
    // Ensure we reload active tasks immediately
    loadTasks(forceRefresh: true);
  }

  // Modified to ensure it loads active tasks
  void clearTasks() {
    emit(TaskInitial()); // Reset to the initial state
    // Load active tasks immediately
    loadTasks(forceRefresh: true);
  }

  // Get tasks for history view - a direct accessor to prevent unnecessary emits
  List<Task> getHistoryTasks() {
    return _cachedHistoryTasks;
  }

  // Get tasks for active view - a direct accessor to prevent unnecessary emits
  List<Task> getActiveTasks() {
    return _cachedTasks;
  }

  // Load tasks assigned to specific user
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

  // Search tasks (both active and history)
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

  // Load specific task (from either active or history)
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

  // Create task
  Future<void> createTask(Task task) async {
    emit(TaskLoading());
    try {
      final createdTask = await _taskRepository.createTask(task);
      emit(TaskOperationSuccess('Task created successfully'));

      _cachedTasks = [createdTask, ..._cachedTasks];
      emit(TasksLoaded(_cachedTasks));
    } catch (e) {
      emit(TaskError('Failed to create task: ${e.toString()}'));
      logger.e('Failed to create task', error: e);
    }
  }

  // Update task
  Future<void> updateTask(Task task) async {
    emit(TaskLoading());
    try {
      final updatedTask = await _taskRepository.updateTask(task);

      // If task is completed/canceled, it will be moved to history via DB trigger
      // Update cache if found
      final index = _cachedTasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        if (updatedTask.status == TaskStatus.completed ||
            updatedTask.status == TaskStatus.canceled) {
          // Remove from active cache if completed
          _cachedTasks.removeAt(index);
        } else {
          // Update in cache
          _cachedTasks[index] = updatedTask;
        }
      }

      // Show updated task details
      emit(TaskDetailLoaded(updatedTask));
    } catch (e) {
      emit(TaskError('Failed to update task: ${e.toString()}'));
      logger.e('Failed to update task', error: e);
    }
  }

  // Delete task
  Future<void> deleteTask(String id) async {
    emit(TaskLoading());
    try {
      await _taskRepository.deleteTask(id);
      emit(TaskOperationSuccess('Task deleted successfully'));

      // Remove from cache if present
      _cachedTasks.removeWhere((task) => task.id == id);
      emit(TasksLoaded(_cachedTasks));
    } catch (e) {
      emit(TaskError('Failed to delete task: ${e.toString()}'));
      logger.e('Failed to delete task', error: e);
    }
  }

  // Change task status
  Future<void> changeTaskStatus(String taskId, TaskStatus newStatus) async {
    emit(TaskLoading());
    try {
      // Get current task
      final task = await _taskRepository.getTaskById(taskId);
      // Update with new status
      final updatedTask = task.copyWith(status: newStatus);
      // Update task
      final result = await _taskRepository.updateTask(updatedTask);

      // Update cache - if task is completed/canceled, DB trigger will move it to history
      final index = _cachedTasks.indexWhere((t) => t.id == taskId);
      if (index >= 0) {
        if (newStatus == TaskStatus.completed ||
            newStatus == TaskStatus.canceled) {
          // Remove from active tasks cache
          _cachedTasks.removeAt(index);
        } else {
          // Update in cache
          _cachedTasks[index] = result;
        }
      }

      emit(TaskOperationSuccess('Task status updated successfully'));
      emit(TaskDetailLoaded(result));
    } catch (e) {
      emit(TaskError('Failed to change task status: ${e.toString()}'));
      logger.e('Failed to change task status', error: e);
    }
  }

  // Assign task to user
  Future<void> assignTask(String taskId, String assigneeId) async {
    emit(TaskLoading());
    try {
      // Get current task
      final task = await _taskRepository.getTaskById(taskId);
      // Update with new assignee
      final updatedTask = task.copyWith(assigneeId: assigneeId);
      // Update task
      final result = await _taskRepository.updateTask(updatedTask);

      // Update in cache if present
      final index = _cachedTasks.indexWhere((t) => t.id == taskId);
      if (index >= 0) {
        _cachedTasks[index] = result;
      }

      emit(TaskOperationSuccess('Task assigned successfully'));
      emit(TaskDetailLoaded(result));
    } catch (e) {
      emit(TaskError('Failed to assign task: ${e.toString()}'));
      logger.e('Failed to assign task', error: e);
    }
  }

  // Subscribe to active tasks
  void subscribeToTasks() {
    try {
      _tasksSubscriptionActive = true;
      _taskRepository.subscribeToTasks().listen((tasks) {
        _cachedTasks = tasks; // Update cache
        // Only emit if in the appropriate view mode
        if (state is TasksLoaded && !(state as TasksLoaded).isHistoryView) {
          emit(TasksLoaded(tasks, isHistoryView: false));
        }
      });
    } catch (e) {
      logger.e('Failed to subscribe to tasks', error: e);
    }
  }

  // Subscribe to history tasks
  void subscribeToTaskHistory() {
    if (_historySubscriptionActive) return;

    try {
      _historySubscriptionActive = true;
      _taskRepository.subscribeToTaskHistory().listen((tasks) {
        _cachedHistoryTasks = tasks;
        // Only emit if in the appropriate view mode
        if (state is TasksLoaded && (state as TasksLoaded).isHistoryView) {
          emit(TasksLoaded(tasks, isHistoryView: true));
        }
      });
    } catch (e) {
      logger.e('Failed to subscribe to task history', error: e);
    }
  }

  // Add to task_cubit.dart
  Future<void> loadTeamTasks(String teamId) async {
    emit(TaskLoading());
    try {
      final tasks = await _taskRepository.getTeamTasks(teamId);
      emit(TasksLoaded(tasks));
    } catch (e) {
      emit(TaskError('Failed to load team tasks: ${e.toString()}'));
    }
  }
}
