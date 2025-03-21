import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_management_app/cubits/auth/cubit/auth_cubit.dart';
import 'package:task_management_app/cubits/comment/cubit/comment_cubit.dart';
import 'package:task_management_app/cubits/task/cubit/task_cubit.dart';
import 'package:task_management_app/cubits/user/cubit/user_cubit.dart';
import 'package:task_management_app/domain/models/task.model.dart';
import 'package:task_management_app/domain/models/comment.model.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;

class TaskDetailPage extends StatefulWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _commentController = TextEditingController();
  List<File> _selectedFiles = [];
  bool _isUploading = false;
  Task? _loadedTask;
  bool _hasInitiallyLoaded = false;
  @override
  void initState() {
    super.initState();
    // Load the task on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskCubit>().loadTaskById(widget.taskId);
      // Load comments for this task
      context.read<CommentCubit>().getCommentsByTaskId(widget.taskId);
      _loadTaskAndComments();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // handle reloading after returning from file picker
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If the task is not loaded, try to reload it
    final state = context.read<TaskCubit>().state;
    if (!_hasInitiallyLoaded &&
        (state is! TaskDetailLoaded || _loadedTask == null)) {
      _loadTaskAndComments();
    }
  }

  void _loadTaskAndComments() {
    if (mounted) {
      context.read<TaskCubit>().loadTaskById(widget.taskId);
      context.read<CommentCubit>().getCommentsByTaskId(widget.taskId);
    }
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
                  context.read<TaskCubit>().deleteTask(task.id).then((_) {
                    context.go('/tasks'); // Navigate back after deletion
                  });
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

  String extractOriginalFileName(String url) {
    final fileName =
        url.split('/').last.split('?').first; // Remove query params
    // Remove timestamp prefix (format: 1234567890_filename.ext)
    final parts = fileName.split('_');
    if (parts.length > 1 && parts[0].length > 8) {
      return parts.sublist(1).join('_');
    }
    return fileName;
  }

  Future<void> _openDocument(String url) async {
    try {
      String file = extractOriginalFileName(url);
      if (file.toLowerCase().endsWith('.pdf')) {
        // Open the PDF directly in the browser
        final Uri uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw Exception('Could not launch $url');
        }
      } else {
        // Handle other file types (download & open)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Downloading file...')));

        // Extract file name from URL
        final fileName = extractOriginalFileName(url);

        // Get temporary directory
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/$fileName';

        // Download the file using Dio
        final dio = Dio();
        await dio.download(url, filePath);

        // Open the file with the default app
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${result.message}')));
        }
        Future.delayed(const Duration(minutes: 30), () {
          try {
            File(filePath).delete();
          } catch (_) {}
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open file: $e')));
    }
  }

  void _addComment(Task task) async {
    final authState = context.read<AuthCubit>().state;
    final content = _commentController.text.trim();
    if (authState is AuthAuthenticated &&
        (content.isNotEmpty || _selectedFiles.isNotEmpty)) {
      final userId = authState.user.id;
      final content = _commentController.text.trim();

      // Show loading indicator
      setState(() {
        _isUploading = true;
      });

      try {
        // Upload files and get URLs
        List<String> attachmentUrls = [];

        for (File file in _selectedFiles) {
          final originalFileName = file.path.split('/').last;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = 'images/${timestamp}_$originalFileName';

          final fileBytes = await file.readAsBytes();
          // Upload to Supabase Storage
          await Supabase.instance.client.storage
              .from('attachments')
              .uploadBinary(filePath, fileBytes);

          // Get signed URL with expiration (e.g., 1 week)
          final signedUrl = await Supabase.instance.client.storage
              .from('attachments')
              .createSignedUrl(filePath, 60 * 60 * 24 * 7); // 7 days in seconds

          print("Generated signed URL: $signedUrl");
          attachmentUrls.add(signedUrl);
        }

        // Create a new comment with attachments
        final newComment = Comment.create(
          taskId: task.id,
          userId: userId,
          content: content,
          attachments: attachmentUrls,
        );

        // Use CommentCubit to create the comment
        context.read<CommentCubit>().createComment(newComment);

        // Clear form
        _commentController.clear();
        setState(() {
          _selectedFiles = [];
          _isUploading = false;
        });
      } catch (e) {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload attachments: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isUploading = false;
        });
      }
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
      body: BlocConsumer<TaskCubit, TaskState>(
        listener: (context, state) {
          if (state is TaskDetailLoaded) {
            // Store the loaded task for backup
            _loadedTask = state.task;
            _hasInitiallyLoaded = true;
          }

          // Existing listener code
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
        builder: (context, state) {
          if (state is TaskLoading && !_hasInitiallyLoaded) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is TaskDetailLoaded) {
            _loadedTask = state.task; // Keep the cached task updated
            return _buildTaskDetail(context, state.task);
          } else if (_loadedTask != null) {
            // Use the cached task if available
            return _buildTaskDetail(context, _loadedTask!);
          } else if (state is TaskError) {
            return Center(
              child: Text(
                state.message,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // If we get here, reload the task
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadTaskAndComments();
          });

          return const Center(child: CircularProgressIndicator());
        },
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
    if (!userCubit.isUserLoaded(task.ownerId)) {
      userCubit.loadUserById(task.ownerId);
    }
    if (task.assigneeId != null && !userCubit.isUserLoaded(task.assigneeId!)) {
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

          if (userIds.isNotEmpty) {
            userCubit.loadUsersByIds(userIds);
          }

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
                Expanded(
                  // Prevents overflow
                  child: BlocBuilder<UserCubit, UserState>(
                    buildWhen: (previous, current) {
                      return current is UserLoaded &&
                          current.user.id == comment.userId;
                    },
                    builder: (context, state) {
                      final userName = userCubit.getDisplayName(comment.userId);
                      return Text(
                        userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow:
                            TextOverflow
                                .ellipsis, // Avoids text breaking layout
                        maxLines: 1, // Ensures single-line display
                      );
                    },
                  ),
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
                    comment.attachments.map((attachment) {
                      // Extract just the filename from the URL
                      final fileName =
                          attachment.split('/').last.split('?').first;
                      final displayName = extractOriginalFileName(fileName);
                      final trimmedName =
                          displayName.length > 25
                              ? '${displayName.substring(0, 20)}...'
                              : displayName;

                      bool isImageFile(String url) {
                        final mimeType = lookupMimeType(
                          url.split('?').first,
                        ); // Ignore query params
                        return mimeType != null &&
                            mimeType.startsWith('image/');
                      }

                      // Check if it's an image file
                      final isImage =
                          fileName.toLowerCase().endsWith('.jpg') ||
                          fileName.toLowerCase().endsWith('.jpeg') ||
                          fileName.toLowerCase().endsWith('.png') ||
                          fileName.toLowerCase().endsWith('.gif');

                      return InkWell(
                        onTap: () {
                          if (isImageFile(attachment)) {
                            // Show image dialog if it's an image
                            showDialog(
                              context: context,
                              builder:
                                  (context) => Dialog(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AppBar(
                                          title: Text(fileName),
                                          automaticallyImplyLeading: false,
                                          actions: [
                                            IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed:
                                                  () => Navigator.pop(context),
                                            ),
                                          ],
                                        ),
                                        Flexible(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Image.network(
                                              attachment,
                                              fit: BoxFit.contain,
                                              loadingBuilder: (
                                                context,
                                                child,
                                                loadingProgress,
                                              ) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    value:
                                                        loadingProgress
                                                                    .expectedTotalBytes !=
                                                                null
                                                            ? loadingProgress
                                                                    .cumulativeBytesLoaded /
                                                                loadingProgress
                                                                    .expectedTotalBytes!
                                                            : null,
                                                  ),
                                                );
                                              },
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                print(
                                                  "Image error: $error for URL: $attachment",
                                                );
                                                return Padding(
                                                  padding: const EdgeInsets.all(
                                                    16.0,
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Icon(
                                                        Icons.broken_image,
                                                        size: 64,
                                                        color: Colors.red,
                                                      ),
                                                      Text(
                                                        'Failed to load image',
                                                      ),
                                                      SizedBox(height: 8),
                                                      SelectableText(
                                                        attachment,
                                                      ), // Allow copying URL
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            );
                          } else {
                            // Open document with url_launcher
                            _openDocument(attachment);
                          }
                        },
                        child: Chip(
                          label: Text(trimmedName),
                          avatar: Icon(
                            isImage ? Icons.image : getFileTypeIcon(fileName),
                            size: 16,
                          ),
                        ),
                      );
                    }).toList(),
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

            // Display selected files preview
            if (_selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Selected files (${_selectedFiles.length})'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _selectedFiles.map((file) {
                      final fileName = file.path.split('/').last;
                      return Chip(
                        label: Text(
                          fileName.length > 15
                              ? '${fileName.substring(0, 15)}...'
                              : fileName,
                        ),
                        avatar: const Icon(Icons.attach_file, size: 16),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _selectedFiles.remove(file);
                          });
                        },
                      );
                    }).toList(),
              ),
            ],

            const SizedBox(height: 8),
            // Separate buttons into two rows
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Attachment'),
                    onPressed: () async {
                      // Show file picker
                      FilePickerResult? result = await FilePicker.platform
                          .pickFiles(
                            type: FileType.any,
                            allowMultiple: true,
                            // This might help with navigation issues
                            lockParentWindow: true,
                          );

                      // Only update state if the widget is still mounted
                      if (result != null && mounted) {
                        List<File> files =
                            result.paths
                                .where((path) => path != null)
                                .map((path) => File(path!))
                                .toList();

                        setState(() {
                          _selectedFiles = files;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isUploading ? null : () => _addComment(task),
                    child:
                        _isUploading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Post Comment'),
                  ),
                ],
              ),
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

  IconData getFileTypeIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
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
