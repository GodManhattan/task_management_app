import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/comment.model.dart';
import '../../domain/repositories/comment.repository.dart';
import '../../core/services/realtime_service.dart';

class SupabaseCommentRepository implements CommentRepository {
  final SupabaseClient _supabaseClient;
  final RealtimeService _realtimeService;
  final Logger _logger = Logger();

  SupabaseCommentRepository(this._supabaseClient)
    : _realtimeService = RealtimeService(_supabaseClient);

  @override
  Future<List<Comment>> getCommentsByTask(String taskId) async {
    try {
      final data = await _supabaseClient
          .from('comments')
          .select()
          .eq('task_id', taskId)
          .order('created_at');

      return data.map<Comment>((json) => Comment.fromJson(json)).toList();
    } catch (e) {
      _logger.e('Error fetching comments for task $taskId', error: e);
      rethrow;
    }
  }

  @override
  Future<Comment> createComment(Comment comment) async {
    try {
      final data =
          await _supabaseClient
              .from('comments')
              .insert(comment.toJson())
              .select()
              .single();

      return Comment.fromJson(data);
    } catch (e) {
      _logger.e('Error creating comment', error: e);
      rethrow;
    }
  }

  @override
  Future<Comment> updateComment(Comment comment) async {
    try {
      final data =
          await _supabaseClient
              .from('comments')
              .update(comment.toJson())
              .eq('id', comment.id)
              .select()
              .single();

      return Comment.fromJson(data);
    } catch (e) {
      _logger.e('Error updating comment ${comment.id}', error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteComment(String id) async {
    try {
      await _supabaseClient.from('comments').delete().eq('id', id);
    } catch (e) {
      _logger.e('Error deleting comment $id', error: e);
      rethrow;
    }
  }

  @override
  Stream<List<Comment>> subscribeToTaskComments(String taskId) {
    return _realtimeService.createTableSubscription<Comment>(
      table: 'comments',
      primaryKey: 'id',
      fromJson: (json) => Comment.fromJson(json),
      eq: 'task_id',
      eqValue: taskId,
    );
  }

  void dispose() {
    _realtimeService.dispose();
  }
}
