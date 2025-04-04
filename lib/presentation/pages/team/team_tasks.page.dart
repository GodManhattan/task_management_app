// lib/presentation/pages/team/team_tasks_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:task_management_app/cubits/task/cubit/task_cubit.dart';
import 'package:task_management_app/cubits/team/cubit/team_cubit.dart';
import 'package:task_management_app/domain/models/task.model.dart';
import 'package:task_management_app/domain/models/team.model.dart';

class TeamTasksPage extends StatefulWidget {
  final String teamId;

  const TeamTasksPage({super.key, required this.teamId});

  @override
  State<TeamTasksPage> createState() => _TeamTasksPageState();
}

class _TeamTasksPageState extends State<TeamTasksPage> {
  bool _isLoading = true;
  Team? _team;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load team details
      final teamCubit = context.read<TeamCubit>();
      await teamCubit.loadTeamById(widget.teamId);

      // Load team tasks
      await context.read<TaskCubit>().loadTeamTasks(widget.teamId);

      setState(() {
        _isLoading = false;
        if (teamCubit.state is TeamDetailLoaded) {
          _team = (teamCubit.state as TeamDetailLoaded).team;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_team?.name ?? 'Team Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : BlocBuilder<TaskCubit, TaskState>(
                builder: (context, state) {
                  if (state is TasksLoaded) {
                    final tasks = state.tasks;

                    if (tasks.isEmpty) {
                      return _buildEmptyState();
                    }

                    return _buildTasksList(tasks);
                  } else if (state is TaskError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  return const Center(child: CircularProgressIndicator());
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateTask(context),
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.task_alt, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No team tasks yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to create a task for this team',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _navigateToCreateTask(context),
            child: const Text('Create Team Task'),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList(List<Task> tasks) {
    // Sort tasks by status and due date
    final sortedTasks = List<Task>.from(tasks);
    sortedTasks.sort((a, b) {
      // First sort by status (active tasks first)
      final aCompleted =
          a.status == TaskStatus.completed || a.status == TaskStatus.canceled;
      final bCompleted =
          b.status == TaskStatus.completed || b.status == TaskStatus.canceled;

      if (aCompleted != bCompleted) {
        return aCompleted ? 1 : -1;
      }

      // Then by due date (if present)
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      } else if (a.dueDate != null) {
        return -1;
      } else if (b.dueDate != null) {
        return 1;
      }

      // Finally by creation date
      return b.createdAt.compareTo(a.createdAt);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedTasks.length,
      itemBuilder: (context, index) {
        final task = sortedTasks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text(
              task.title,
              style: TextStyle(
                decoration:
                    task.status == TaskStatus.completed ||
                            task.status == TaskStatus.canceled
                        ? TextDecoration.lineThrough
                        : null,
              ),
            ),
            subtitle: Text(task.description ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.isOverdue && task.status != TaskStatus.completed) ...[
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                ],
                Chip(
                  label: Text(task.status.name),
                  backgroundColor: _getStatusColor(task.status),
                ),
              ],
            ),
            onTap: () => context.go('/tasks/${task.id}'),
          ),
        );
      },
    );
  }

  void _navigateToCreateTask(BuildContext context) {
    // In a real implementation, you would navigate to a task creation page
    // with the team ID pre-populated
    context.push('/tasks/create?teamId=${widget.teamId}');
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
    }
  }
}
