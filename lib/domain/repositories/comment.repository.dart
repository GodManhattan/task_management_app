import '../../domain/models/comment.model.dart';

abstract class CommentRepository {
  /// Get all comments for a task
  Future<List<Comment>> getCommentsByTask(String taskId);

  /// Create a new comment
  Future<Comment> createComment(Comment comment);

  /// Update an existing comment
  Future<Comment> updateComment(Comment comment);

  /// Delete a comment
  Future<void> deleteComment(String id);

  /// Subscribe to real-time comment updates for a task
  Stream<List<Comment>> subscribeToTaskComments(String taskId);
}
