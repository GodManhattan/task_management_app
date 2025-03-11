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

    final data = await _supabaseClient
        .from('tasks')
        .select()
        .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
        .order('created_at', ascending: false);

    return data.map<Task>((json) => Task.fromJson(json)).toList();
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
        .stream(primaryKey: ['id'])
        .eq('owner_id', currentUser.id)
        .map((data) => data.map<Task>((json) => Task.fromJson(json)).toList());
  }
}
