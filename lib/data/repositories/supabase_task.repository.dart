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
          .from('tasks')
          .select()
          .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
          .order('created_at', ascending: false);

      print('Raw Supabase response: $data'); // Log the raw response

      if (data is List) {
        // Make sure each item is a map before using fromJson
        return data.map<Task>((item) {
          if (item is Map<String, dynamic>) {
            return Task.fromJson(item);
          } else {
            print('Unexpected item format: $item (${item.runtimeType})');
            throw Exception('Invalid format for Task in Supabase response');
          }
        }).toList();
      } else {
        print('Unexpected data format: $data (${data.runtimeType})');
        throw Exception('Invalid response format from Supabase');
      }
    } catch (e) {
      print('Error in getTasks: $e');
      rethrow; // Re-throw to be handled by the cubit
    }
  }

  @override
  Future<Task> getTaskById(String id) async {
    final data =
        await _supabaseClient.from('tasks').select().eq('id', id).single();

    return Task.fromJson(data);
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
    await _supabaseClient.from('tasks').delete().eq('id', id);
  }

  @override
  Future<List<Task>> getTasksByStatus(TaskStatus status) async {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final data = await _supabaseClient
        .from('tasks')
        .select()
        .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
        .eq('status', status.name)
        .order('created_at', ascending: false);

    return data.map<Task>((json) => Task.fromJson(json)).toList();
  }

  @override
  Future<List<Task>> getTasksByAssignee(String userId) async {
    final data = await _supabaseClient
        .from('tasks')
        .select()
        .eq('assignee_id', userId)
        .order('created_at', ascending: false);

    return data.map<Task>((json) => Task.fromJson(json)).toList();
  }

  @override
  Future<List<Task>> searchTasks(String query) async {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final data = await _supabaseClient
        .from('tasks')
        .select()
        .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
        .or('title.ilike.%$query%,description.ilike.%$query%')
        .order('created_at', ascending: false);

    return data.map<Task>((json) => Task.fromJson(json)).toList();
  }

  @override
  Stream<List<Task>> subscribeToTasks() {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    return _supabaseClient
        .from('tasks')
        .stream(primaryKey: ['id']) // Get real-time updates for all tasks
        .map((data) {
          return data
              .map<Task>(
                (json) => Task.fromJson(json),
              ) // Convert JSON to Task objects
              .where(
                (task) =>
                    task.ownerId == currentUser.id ||
                    task.assigneeId == currentUser.id,
              ) // Filter manually
              .toList();
        });
  }
}
