import 'package:equatable/equatable.dart';
import 'package:task_management_app/domain/models/comment.model.dart';
import 'package:uuid/uuid.dart';

/// Represents the status of a task in the system
enum TaskStatus { pending, inProgress, underReview, completed, canceled }

/// Represents the priority level of a task
enum TaskPriority { low, medium, high, urgent }

class Task extends Equatable {
  final String id;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String ownerId;
  final String? assigneeId;
  final List<String>? tags;
  final List<Comment>? comments;

  /// Constructor
  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerId,
    this.assigneeId,
    this.tags = const [],
    this.comments = const [],
  });

  /// Create a new task with default values
  factory Task.create({
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    required String ownerId,
    String? assigneeId,
    List<String> tags = const [],
    List<Comment> comments = const [],
  }) {
    final now = DateTime.now();
    return Task(
      id: const Uuid().v4(),
      title: title,
      description: description,
      status: TaskStatus.pending,
      priority: priority,
      dueDate: dueDate,
      createdAt: now,
      updatedAt: now,
      ownerId: ownerId,
      assigneeId: assigneeId,
      tags: tags,
      comments: comments,
    );
  }

  /// Create a Task from a JSON map
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: _parseStatus(json['status']),
      priority: _parsePriority(json['priority']),
      dueDate:
          json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      ownerId: json['owner_id'],
      assigneeId: json['assignee_id'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : const [],
      comments:
          (json['comments'] as List?)
              ?.map((c) => Comment.fromJson(c))
              .toList() ??
          const [],
    );
  }

  /// Convert Task to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.name,
      'priority': priority.name,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'owner_id': ownerId,
      'assignee_id': assigneeId,
      'tags': tags,
      'comments': comments,
    };
  }

  /// Create a copy of this Task with some updated fields
  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    String? assigneeId,
    List<String>? tags,
    List<Comment>? comments,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      ownerId: ownerId,
      assigneeId: assigneeId ?? this.assigneeId,
      tags: tags ?? this.tags,
      comments: comments ?? this.comments,
    );
  }

  /// Check if task is overdue
  bool get isOverdue {
    if (dueDate == null) return false;
    return dueDate!.isBefore(DateTime.now()) && status != TaskStatus.completed;
  }

  /// Parse task status from string
  static TaskStatus _parseStatus(String status) {
    return TaskStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => TaskStatus.pending,
    );
  }

  /// Parse task priority from string
  static TaskPriority _parsePriority(String priority) {
    return TaskPriority.values.firstWhere(
      (e) => e.name == priority,
      orElse: () => TaskPriority.medium,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    status,
    priority,
    dueDate,
    createdAt,
    updatedAt,
    ownerId,
    assigneeId,
    tags,
    comments,
  ];

  Task addComment(String userId, String content, List<String> attachments) {
    final newComment = Comment.create(
      taskId: id,
      userId: userId,
      content: content,
      attachments: attachments,
    );
    return copyWith(comments: [...?comments, newComment]);
  }
}
