import '../../domain/models/task.model.dart';

abstract class TaskRepository {
  /// Get all tasks for the current user (owned or assigned)
  Future<List<Task>> getTasks();

  /// Get a specific task by ID
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

  /// Subscribe to real-time task updates
  Stream<List<Task>> subscribeToTasks();
}
