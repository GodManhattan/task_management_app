import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:task_management_app/domain/models/comment.model.dart';
import 'package:task_management_app/domain/models/task.model.dart';
import 'package:task_management_app/domain/repositories/comment.repository.dart';

part 'comment_state.dart';

var logger = Logger();

class CommentCubit extends Cubit<CommentState> {
  final CommentRepository _commentRepository;
  CommentCubit(this._commentRepository) : super(CommentInitial());

  Future<void> getCommentsByTaskId(String taskId) async {
    emit(CommentLoading());
    try {
      final comments = await _commentRepository.getCommentsByTask(taskId);
      emit(CommentLoaded(comments));
    } catch (e) {
      logger.e('Failed to load comments', error: e);
      emit(CommentError(message: 'Failed to load comments: ${e.toString()}'));
    }
  }

  Future<void> deleteComment(String commentId, String taskId) async {
    final currentState = state;
    try {
      await _commentRepository.deleteComment(commentId);

      if (currentState is CommentLoaded) {
        // Remove the deleted comment from the list
        final updatedComments =
            currentState.comment
                .where((comment) => comment.id != commentId)
                .toList();

        emit(CommentLoaded(updatedComments));
      }
    } catch (e) {
      logger.e('Failed to delete comment', error: e);
      emit(CommentError(message: 'Failed to delete comment: ${e.toString()}'));
    }
  }

  Future<void> subscribeToComments(String taskId) async {
    try {
      _commentRepository.subscribeToTaskComments(taskId).listen((comments) {
        emit(CommentLoaded(comments));
      });
    } catch (e) {
      logger.e('Failed to subscribe to comments', error: e);
      // Don't emit error state as it might disrupt current state
    }
  }

  Future<void> createComment(Comment comment) async {
    final currentState = state;
    try {
      final createdComment = await _commentRepository.createComment(comment);

      if (currentState is CommentLoaded) {
        // Add new comment to existing list
        final updatedComments = [...currentState.comment, createdComment];
        emit(CommentLoaded(updatedComments));
      } else {
        // Otherwise just load all comments
        getCommentsByTaskId(comment.taskId);
      }
    } catch (e) {
      logger.e('Failed to create comment', error: e);
      emit(CommentError(message: 'Failed to create comment: ${e.toString()}'));
    }
  }
}
