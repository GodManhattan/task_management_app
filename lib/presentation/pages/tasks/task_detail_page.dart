import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:task_management_app/cubits/auth/cubit/auth_cubit.dart';
import 'package:task_management_app/cubits/comment/cubit/comment_cubit.dart';
import 'package:task_management_app/cubits/task/cubit/task_cubit.dart';
import 'package:task_management_app/cubits/user/cubit/user_cubit.dart';
import 'package:task_management_app/domain/models/task.model.dart';
import 'package:task_management_app/domain/models/comment.model.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load the task on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskCubit>().loadTaskById(widget.taskId);
      // Load comments for this task
      context.read<CommentCubit>().getCommentsByTaskId(widget.taskId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showDeleteConfirmation(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: Text('Are you sure you want to delete "${task.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<TaskCubit>().deleteTask(task.id);
                  context.go('/tasks'); // Navigate back after deletion
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _showStatusChangeDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Change Status'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  TaskStatus.values.map((status) {
                    return ListTile(
                      title: Text(status.name),
                      selected: task.status == status,
                      onTap: () {
                        Navigator.pop(context);
                        if (task.status != status) {
                          context.read<TaskCubit>().changeTaskStatus(
                            task.id,
                            status,
                          );
                        }
                      },
                    );
                  }).toList(),
            ),
          ),
    );
  }

  void _addComment(Task task) {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated && _commentController.text.isNotEmpty) {
      final userId = authState.user.id;
      final content = _commentController.text.trim();

      // Create a new comment
      final newComment = Comment.create(
        taskId: task.id,
        userId: userId,
        content: content,
        attachments: [],
      );

      // Use CommentCubit to create the comment
      context.read<CommentCubit>().createComment(newComment);
      _commentController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          BlocBuilder<TaskCubit, TaskState>(
            builder: (context, state) {
              if (state is TaskDetailLoaded) {
                final task = state.task;
                final authState = context.read<AuthCubit>().state;

                // Only show edit/delete if user is the owner
                if (authState is AuthAuthenticated &&
                    authState.user.id == task.ownerId) {
                  return Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => context.go('/tasks/${task.id}/edit'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _showDeleteConfirmation(context, task),
                      ),
                    ],
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocListener<TaskCubit, TaskState>(
        listener: (context, state) {
          if (state is TaskOperationSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is TaskError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<TaskCubit, TaskState>(
          builder: (context, state) {
            if (state is TaskLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is TaskError) {
              return Center(
                child: Text(
                  state.message,
                  style: const TextStyle(color: Colors.red),
                ),
              );
            } else if (state is TaskDetailLoaded) {
              final task = state.task;
              return _buildTaskDetail(context, task);
            }
            return const Center(child: Text('Task not found'));
          },
        ),
      ),
    );
  }

  Widget _buildTaskDetail(BuildContext context, Task task) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task header with status
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showStatusChangeDialog(context, task),
                child: Chip(
                  label: Text(task.status.name),
                  backgroundColor: _getStatusColor(task.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Priority indicator
          Row(
            children: [
              Icon(
                _getPriorityIcon(task.priority),
                color: _getPriorityColor(task.priority),
              ),
              const SizedBox(width: 8),
              Text(
                'Priority: ${task.priority.name}',
                style: TextStyle(color: _getPriorityColor(task.priority)),
              ),
            ],
          ),

          // Due date
          if (task.dueDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Text(
                  'Due: ${DateFormat('MMM dd, yyyy - hh:mm a').format(task.dueDate!)}',
                  style:
                      task.isOverdue
                          ? const TextStyle(color: Colors.red)
                          : null,
                ),
                if (task.isOverdue) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    label: Text('OVERDUE'),
                    backgroundColor: Colors.red,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                ],
              ],
            ),
          ],

          // Dates info
          const SizedBox(height: 8),
          Text(
            'Created: ${DateFormat('MMM dd, yyyy').format(task.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Last updated: ${DateFormat('MMM dd, yyyy').format(task.updatedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          // Owner and assignee info
          const SizedBox(height: 16),
          _buildAssigneeSection(context, task),

          // Description
          const SizedBox(height: 16),
          const Text(
            'Description',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(task.description ?? 'No description provided'),
          ),

          // Tags
          if (task.tags != null && task.tags!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Tags',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  task.tags!.map((tag) => Chip(label: Text(tag))).toList(),
            ),
          ],

          // Comments section
          const SizedBox(height: 24),
          const Text(
            'Comments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildCommentsList(task),

          // Add comment
          const SizedBox(height: 16),
          _buildAddCommentSection(task),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAssigneeSection(BuildContext context, Task task) {
    final authState = context.read<AuthCubit>().state;
    final bool isOwner =
        authState is AuthAuthenticated && authState.user.id == task.ownerId;

    final userCubit = context.read<UserCubit>();

    // Load user data for owner and assignee
    userCubit.loadUserById(task.ownerId);
    if (task.assigneeId != null) {
      userCubit.loadUserById(task.assigneeId!);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person),
                const SizedBox(width: 8),
                const Text('Owner: '),
                Expanded(
                  child: BlocBuilder<UserCubit, UserState>(
                    buildWhen: (previous, current) {
                      // Only rebuild when the userCubit has loaded a user
                      return current is UserLoaded &&
                          current.user.id == task.ownerId;
                    },
                    builder: (context, state) {
                      // Get display name using the helper method
                      final ownerName = userCubit.getDisplayName(task.ownerId);

                      return Text(
                        ownerName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.assignment_ind),
                const SizedBox(width: 8),
                const Text('Assigned to: '),
                Expanded(
                  child:
                      task.assigneeId != null
                          ? BlocBuilder<UserCubit, UserState>(
                            buildWhen: (previous, current) {
                              return current is UserLoaded &&
                                  current.user.id == task.assigneeId;
                            },
                            builder: (context, state) {
                              final assigneeName = userCubit.getDisplayName(
                                task.assigneeId!,
                              );

                              return Text(
                                assigneeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          )
                          : const Text(
                            'Unassigned',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                ),
                if (isOwner)
                  TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Change'),
                    onPressed: () {
                      // Show the assignee dialog
                      _showAssignUserDialog(context, task);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsList(Task task) {
    return BlocBuilder<CommentCubit, CommentState>(
      builder: (context, state) {
        if (state is CommentLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is CommentLoaded) {
          final comments = state.comment;

          if (comments.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No comments yet'),
              ),
            );
          }

          // Load all user IDs from comments
          final userCubit = context.read<UserCubit>();
          final userIds = comments.map((c) => c.userId).toSet().toList();
          userCubit.loadUsersByIds(userIds);

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: comments.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final comment = comments[index];
              return _buildCommentItem(context, comment, task);
            },
          );
        } else if (state is CommentError) {
          return Center(
            child: Text(
              state.message,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Loading comments...'),
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(BuildContext context, Comment comment, Task task) {
    final authState = context.read<AuthCubit>().state;
    final userCubit = context.read<UserCubit>();
    final isTaskOwner =
        authState is AuthAuthenticated && authState.user.id == task.ownerId;
    final isCommentOwner =
        authState is AuthAuthenticated && authState.user.id == comment.userId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_circle),
                const SizedBox(width: 8),
                BlocBuilder<UserCubit, UserState>(
                  buildWhen: (previous, current) {
                    return current is UserLoaded &&
                        current.user.id == comment.userId;
                  },
                  builder: (context, state) {
                    final userName = userCubit.getDisplayName(comment.userId);
                    return Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    );
                  },
                ),
                const Spacer(),
                Text(
                  comment.formattedTimestamp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (comment.isEdited) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(edited)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(comment.content),
            if (comment.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children:
                    comment.attachments
                        .map(
                          (attachment) => Chip(
                            label: Text(attachment),
                            avatar: const Icon(Icons.attach_file, size: 16),
                          ),
                        )
                        .toList(),
              ),
            ],
            // Show delete option for task owner or comment owner
            if (isTaskOwner || isCommentOwner) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // if (isCommentOwner)
                  //   TextButton.icon(
                  //     icon: const Icon(Icons.edit, size: 16),
                  //     label: const Text('Edit'),
                  //     onPressed: () {
                  //       // Show edit dialog
                  //       _showEditCommentDialog(context, comment);
                  //     },
                  //   ),
                  if (isTaskOwner || isCommentOwner)
                    TextButton.icon(
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () {
                        // Show delete confirmation
                        _showDeleteCommentConfirmation(context, comment, task);
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Add a method to show delete confirmation
  void _showDeleteCommentConfirmation(
    BuildContext context,
    Comment comment,
    Task task,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Comment'),
            content: const Text(
              'Are you sure you want to delete this comment?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Use CommentCubit to delete
                  context.read<CommentCubit>().deleteComment(
                    comment.id,
                    task.id,
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  // Add a method to show edit dialog
  // void _showEditCommentDialog(BuildContext context, Comment comment) {
  //   final TextEditingController controller = TextEditingController(
  //     text: comment.content,
  //   );

  //   showDialog(
  //     context: context,
  //     builder:
  //         (context) => AlertDialog(
  //           title: const Text('Edit Comment'),
  //           content: TextField(
  //             controller: controller,
  //             decoration: const InputDecoration(
  //               hintText: 'Edit your comment...',
  //               border: OutlineInputBorder(),
  //             ),
  //             minLines: 3,
  //             maxLines: 5,
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: const Text('Cancel'),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 if (controller.text.isNotEmpty) {
  //                   Navigator.pop(context);
  //                   // Create updated comment
  //                   final updatedComment = comment.copyWith(
  //                     content: controller.text.trim(),
  //                   );
  //                   // Add method to CommentCubit to update
  //                   context.read<CommentCubit>().updateComment(updatedComment);
  //                 }
  //               },
  //               child: const Text('Save'),
  //             ),
  //           ],
  //         ),
  //   );
  // }

  Widget _buildAddCommentSection(Task task) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a comment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Write your comment here...',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Attachment'),
                  onPressed: () {
                    // Implement attachment functionality
                    // This would typically show a file picker
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _addComment(task),
                  child: const Text('Post Comment'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Add this helper method to show a dialog for user assignment
  void _showAssignUserDialog(BuildContext context, Task task) {
    // In a real app, you might want to fetch available users here
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text('Assign Task'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'User ID',
              hintText: 'Enter user ID to assign',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(context);
                  context.read<TaskCubit>().assignTask(
                    task.id,
                    controller.text.trim(),
                  );
                }
              },
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.grey.shade300;
      case TaskStatus.inProgress:
        return Colors.blue.shade100;
      case TaskStatus.underReview:
        return Colors.orange.shade100;
      case TaskStatus.completed:
        return Colors.green.shade100;
      case TaskStatus.canceled:
        return Colors.red.shade100;
      default:
        return Colors.grey.shade300;
    }
  }

  IconData _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Icons.arrow_downward;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.high:
        return Icons.arrow_upward;
      case TaskPriority.urgent:
        return Icons.priority_high;
      default:
        return Icons.remove;
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.urgent:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
