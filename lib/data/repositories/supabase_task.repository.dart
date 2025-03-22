import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/task.model.dart';
import '../../domain/repositories/task.repository.dart';

class SupabaseTaskRepository implements TaskRepository {
  final SupabaseClient _supabaseClient;

  SupabaseTaskRepository(this._supabaseClient);

  @override
  Future<List<Task>> getTasks() async {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    try {
      final data = await _supabaseClient
          .from('tasks') // Only active tasks table
          .select()
          .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
          .order('created_at', ascending: false);

      if (data is List) {
        return data.map<Task>((item) {
          if (item is Map<String, dynamic>) {
            return Task.fromJson(item);
          } else {
            throw Exception('Invalid format for Task in Supabase response');
          }
        }).toList();
      } else {
        throw Exception('Invalid response format from Supabase');
      }
    } catch (e) {
      print('Error in getTasks: $e');
      rethrow;
    }
  }

  @override
  Future<List<Task>> getTasksHistory() async {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    try {
      final data = await _supabaseClient
          .from('task_history') // History table
          .select()
          .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
          .order('completed_at', ascending: false);

      if (data is List) {
        return data.map<Task>((item) {
          if (item is Map<String, dynamic>) {
            return Task.fromJson(item);
          } else {
            throw Exception('Invalid format for Task in Supabase response');
          }
        }).toList();
      } else {
        throw Exception('Invalid response format from Supabase');
      }
    } catch (e) {
      print('Error in getTasksHistory: $e');
      rethrow;
    }
  }

  @override
  Future<Task> getTaskById(String id) async {
    // First try to find in active tasks
    try {
      final data =
          await _supabaseClient
              .from('tasks')
              .select()
              .eq('id', id)
              .maybeSingle();

      if (data != null) {
        return Task.fromJson(data);
      }

      // If not found in active tasks, try history
      final historyData =
          await _supabaseClient
              .from('task_history')
              .select()
              .eq('id', id)
              .single();
      return Task.fromJson(historyData);
    } catch (e) {
      print('Error in getTaskById: $e');
      rethrow;
    }
  }

  @override
  Future<Task> createTask(Task task) async {
    final data =
        await _supabaseClient
            .from('tasks')
            .insert(task.toJson())
            .select()
            .single();

    return Task.fromJson(data);
  }

  @override
  Future<Task> updateTask(Task task) async {
    final data =
        await _supabaseClient
            .from('tasks')
            .update(task.toJson())
            .eq('id', task.id)
            .select()
            .single();

    return Task.fromJson(data);
  }

  @override
  Future<void> deleteTask(String id) async {
    // First try to delete from active tasks
    try {
      await _supabaseClient.from('tasks').delete().eq('id', id);
    } catch (e) {
      // If not found in active tasks, try history
      await _supabaseClient.from('task_history').delete().eq('id', id);
    }
  }

  @override
  Future<List<Task>> getTasksByStatus(TaskStatus status) async {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    // Determine which table to query based on status
    final table =
        (status == TaskStatus.completed || status == TaskStatus.canceled)
            ? 'task_history'
            : 'tasks';

    final data = await _supabaseClient
        .from(table)
        .select()
        .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
        .eq('status', status.name)
        .order(
          table == 'task_history' ? 'completed_at' : 'created_at',
          ascending: false,
        );

    return data.map<Task>((json) => Task.fromJson(json)).toList();
  }

  @override
  Future<List<Task>> getTasksByAssignee(String userId) async {
    // First get active tasks assigned to user
    final activeTasks = await _supabaseClient
        .from('tasks')
        .select()
        .eq('assignee_id', userId)
        .order('created_at', ascending: false);

    // Then get history tasks assigned to user
    final historyTasks = await _supabaseClient
        .from('task_history')
        .select()
        .eq('assignee_id', userId)
        .order('completed_at', ascending: false);

    // Combine and convert both
    final allTasks = [...activeTasks, ...historyTasks];
    return allTasks.map<Task>((json) => Task.fromJson(json)).toList();
  }

  @override
  Future<List<Task>> searchTasks(String query) async {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    // Search active tasks
    final activeTasks = await _supabaseClient
        .from('tasks')
        .select()
        .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
        .or('title.ilike.%$query%,description.ilike.%$query%')
        .order('created_at', ascending: false);

    // Search history tasks
    final historyTasks = await _supabaseClient
        .from('task_history')
        .select()
        .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
        .or('title.ilike.%$query%,description.ilike.%$query%')
        .order('completed_at', ascending: false);

    // Combine results
    final allTasks = [...activeTasks, ...historyTasks];
    return allTasks.map<Task>((json) => Task.fromJson(json)).toList();
  }

  @override
  Stream<List<Task>> subscribeToTasks() {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    return _supabaseClient
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('owner_id', currentUser.id)
        .map((data) => data.map<Task>((json) => Task.fromJson(json)).toList());
  }

  @override
  Stream<List<Task>> subscribeToTaskHistory() {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    return _supabaseClient
        .from('task_history')
        .stream(primaryKey: ['id'])
        .eq('owner_id', currentUser.id)
        .map((data) => data.map<Task>((json) => Task.fromJson(json)).toList());
  }
}
