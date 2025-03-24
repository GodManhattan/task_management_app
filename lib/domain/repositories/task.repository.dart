import '../../domain/models/task.model.dart';

abstract class TaskRepository {
  /// Get all active tasks for the current user (owned or assigned)
  Future<List<Task>> getTasks();

  /// Get completed or canceled tasks from history
  Future<List<Task>> getTasksHistory();

  /// Get a specific task by ID (from either active or history)
  Future<Task> getTaskById(String id);

  /// Create a new task
  Future<Task> createTask(Task task);

  /// Update an existing task
  Future<Task> updateTask(Task task);

  /// Delete a task
  Future<void> deleteTask(String id);

  /// Get tasks filtered by status
  Future<List<Task>> getTasksByStatus(TaskStatus status);

  /// Get tasks assigned to a specific user
  Future<List<Task>> getTasksByAssignee(String userId);

  /// Search tasks by keyword
  Future<List<Task>> searchTasks(String query);

  /// Subscribe to real-time active task updates
  Stream<List<Task>> subscribeToTasks();

  /// Subscribe to real-time task history updates
  Stream<List<Task>> subscribeToTaskHistory();

  /// Subscribe to real-time task updates
  Stream<List<Task>> subscribeToTasksDirectly();
}
