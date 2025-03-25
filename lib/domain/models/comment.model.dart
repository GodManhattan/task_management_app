import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Comment model representing a comment on a task
class Comment extends Equatable {
  /// Unique identifier for the comment
  final String id;

  /// ID of the task this comment belongs to
  final String taskId;

  /// ID of the user who created the comment
  final String userId;

  /// Content of the comment
  final String content;

  /// When the comment was created
  final DateTime createdAt;

  /// Whether the comment has been edited
  final bool isEdited;

  /// When the comment was last edited (if applicable)
  final DateTime? editedAt;

  /// Any attachments to the comment (file URLs)
  final List<String> attachments;

  /// Constructor
  const Comment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.isEdited = false,
    this.editedAt,
    this.attachments = const [],
  });

  /// Create a new comment with default values
  factory Comment.create({
    required String taskId,
    required String userId,
    required String content,
    List<String> attachments = const [],
  }) {
    return Comment(
      id: const Uuid().v4(),
      taskId: taskId,
      userId: userId,
      content: content,
      createdAt: DateTime.now().toUtc(),
      attachments: attachments,
    );
  }

  /// Create a Comment from a JSON map
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      taskId: json['task_id'],
      userId: json['user_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      isEdited: json['is_edited'] ?? false,
      editedAt:
          json['edited_at'] != null ? DateTime.parse(json['edited_at']) : null,
      attachments:
          json['attachments'] != null
              ? List<String>.from(json['attachments'])
              : const [],
    );
  }

  /// Convert Comment to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'is_edited': isEdited,
      'edited_at': editedAt?.toIso8601String(),
      'attachments': attachments,
    };
  }

  /// Create a copy of this Comment with some updated fields
  Comment copyWith({String? content, List<String>? attachments}) {
    final now = DateTime.now();
    return Comment(
      id: id,
      taskId: taskId,
      userId: userId,
      content: content ?? this.content,
      createdAt: createdAt,
      isEdited: true,
      editedAt: now,
      attachments: attachments ?? this.attachments,
    );
  }

  /// Format the timestamp for display
  String get formattedTimestamp {
    final now = DateTime.now();
    final localCreatedAt = createdAt;
    final difference = now.difference(localCreatedAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${localCreatedAt.month}/${localCreatedAt.day}/${localCreatedAt.year}';
    }
  }

  @override
  List<Object?> get props => [
    id,
    taskId,
    userId,
    content,
    createdAt,
    isEdited,
    editedAt,
    attachments,
  ];
}
