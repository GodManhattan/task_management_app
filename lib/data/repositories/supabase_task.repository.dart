import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/task.model.dart';
import '../../domain/repositories/task.repository.dart';
import '../../core/services/realtime_service.dart';
import 'package:logger/logger.dart';

class SupabaseTaskRepository implements TaskRepository {
  final SupabaseClient _supabaseClient;
  final RealtimeService _realtimeService;
  final Logger _logger = Logger();

  SupabaseTaskRepository(this._supabaseClient)
    : _realtimeService = RealtimeService(_supabaseClient);

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

      return data.map<Task>((item) => Task.fromJson(item)).toList();
    } catch (e) {
      _logger.e('Error in getTasks: $e');
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
          .from('task_history')
          .select()
          .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
          .order('completed_at', ascending: false);

      return data.map<Task>((item) => Task.fromJson(item)).toList();
    } catch (e) {
      _logger.e('Error in getTasksHistory: $e');
      rethrow;
    }
  }

  @override
  Future<Task> getTaskById(String id) async {
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

      final historyData =
          await _supabaseClient
              .from('task_history')
              .select()
              .eq('id', id)
              .single();
      return Task.fromJson(historyData);
    } catch (e) {
      _logger.e('Error in getTaskById: $e');
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
    try {
      await _supabaseClient.from('tasks').delete().eq('id', id);
    } catch (e) {
      await _supabaseClient.from('task_history').delete().eq('id', id);
    }
  }

  @override
  Future<List<Task>> getTasksByStatus(TaskStatus status) async {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

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
    final activeTasks = await _supabaseClient
        .from('tasks')
        .select()
        .eq('assignee_id', userId)
        .order('created_at', ascending: false);

    final historyTasks = await _supabaseClient
        .from('task_history')
        .select()
        .eq('assignee_id', userId)
        .order('completed_at', ascending: false);

    final allTasks = [...activeTasks, ...historyTasks];
    return allTasks.map<Task>((json) => Task.fromJson(json)).toList();
  }

  @override
  Future<List<Task>> searchTasks(String query) async {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final activeTasks = await _supabaseClient
        .from('tasks')
        .select()
        .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
        .or('title.ilike.%$query%,description.ilike.%$query%')
        .order('created_at', ascending: false);

    final historyTasks = await _supabaseClient
        .from('task_history')
        .select()
        .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
        .or('title.ilike.%$query%,description.ilike.%$query%')
        .order('completed_at', ascending: false);

    final allTasks = [...activeTasks, ...historyTasks];
    return allTasks.map<Task>((json) => Task.fromJson(json)).toList();
  }

  @override
  Stream<List<Task>> subscribeToTasksDirectly() {
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final controller = StreamController<List<Task>>.broadcast();

    // Initialize with current data
    _supabaseClient
        .from('tasks')
        .select()
        .or('owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}')
        .then((data) {
          final tasks = data.map<Task>((item) => Task.fromJson(item)).toList();
          if (!controller.isClosed) controller.add(tasks);
        })
        .catchError((error) {
          _logger.e("Error fetching initial tasks: $error");
          // Don't close the controller on error, just log it
        });

    // Set up realtime subscription directly
    final channel = _supabaseClient.channel('public:tasks');
    channel
        .onPostgresChanges(
          schema: 'public',
          table: 'tasks',
          event: PostgresChangeEvent.all,
          callback: (payload, [ref]) {
            _logger.d("Received realtime payload: $payload");

            // Refresh the entire list on any change
            _supabaseClient
                .from('tasks')
                .select()
                .or(
                  'owner_id.eq.${currentUser.id},assignee_id.eq.${currentUser.id}',
                )
                .then((data) {
                  final tasks =
                      data.map<Task>((item) => Task.fromJson(item)).toList();
                  if (!controller.isClosed) controller.add(tasks);
                })
                .catchError((error) {
                  _logger.e("Error refreshing tasks after change: $error");
                });
          },
        )
        .subscribe((status, [error]) {
          _logger.d("Channel status changed to: $status");
          if (error != null) {
            _logger.e("Channel error: $error");
          }
        });

    // Clean up when no longer needed
    controller.onCancel = () {
      _logger.d("Cleaning up tasks subscription");
      channel.unsubscribe();
      _supabaseClient.removeChannel(channel);
    };

    return controller.stream;
  }

  // @override
  // Stream<List<Task>> subscribeToTasks() {
  //   final currentUser = _supabaseClient.auth.currentUser;

  //   if (currentUser == null) {
  //     throw Exception('No authenticated user');
  //   }

  //   return _realtimeService.createTableSubscription<Task>(
  //     table: 'tasks',
  //     primaryKey: 'id',
  //     fromJson: (json) => Task.fromJson(json),
  //     eq: 'owner_id',
  //     eqValue: currentUser.id,
  //   );
  // }
  @override
  Stream<List<Task>> subscribeToTasks() {
    return subscribeToTasksDirectly();
  }

  @override
  Stream<List<Task>> subscribeToTaskHistory() {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    return _realtimeService.createTableSubscription<Task>(
      table: 'task_history',
      primaryKey: 'id',
      fromJson: (json) => Task.fromJson(json),
      eq: 'owner_id',
      eqValue: currentUser.id,
    );
  }

  void dispose() {
    _realtimeService.dispose();
  }
}
