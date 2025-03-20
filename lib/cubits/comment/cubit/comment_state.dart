part of 'comment_cubit.dart';

sealed class CommentState extends Equatable {
  const CommentState();

  @override
  List<Object> get props => [];
}

final class CommentInitial extends CommentState {}

final class CommentLoading extends CommentState {}

final class CommentLoaded extends CommentState {
  final List<Comment> comment;

  const CommentLoaded(this.comment);

  @override
  List<Object> get props => [comment];
}

final class CommentError extends CommentState {
  final String message;

  const CommentError({required this.message});

  @override
  List<Object> get props => [message];
}
