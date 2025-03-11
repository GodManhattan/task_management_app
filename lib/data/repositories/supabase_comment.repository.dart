import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/comment.model.dart';
import '../../domain/repositories/comment.repository.dart';

class SupabaseCommentRepository implements CommentRepository {
  final SupabaseClient _supabaseClient;

  SupabaseCommentRepository(this._supabaseClient);

  @override
  Future<List<Comment>> getCommentsByTask(String taskId) async {
    final data = await _supabaseClient
        .from('comments')
        .select()
        .eq('task_id', taskId)
        .order('created_at');

    return data.map<Comment>((json) => Comment.fromJson(json)).toList();
  }

  @override
  Future<Comment> createComment(Comment comment) async {
    final data =
        await _supabaseClient
            .from('comments')
            .insert(comment.toJson())
            .select()
            .single();

    return Comment.fromJson(data);
  }

  @override
  Future<Comment> updateComment(Comment comment) async {
    final data =
        await _supabaseClient
            .from('comments')
            .update(comment.toJson())
            .eq('id', comment.id)
            .select()
            .single();

    return Comment.fromJson(data);
  }

  @override
  Future<void> deleteComment(String id) async {
    await _supabaseClient.from('comments').delete().eq('id', id);
  }

  @override
  Stream<List<Comment>> subscribeToTaskComments(String taskId) {
    return _supabaseClient
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('task_id', taskId)
        .map(
          (data) =>
              data.map<Comment>((json) => Comment.fromJson(json)).toList(),
        );
  }
}
