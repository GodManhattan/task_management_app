import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:task_management_app/cubits/task/cubit/task_cubit.dart';
import 'package:task_management_app/domain/models/task.model.dart';

class TaskHistoryPage extends StatefulWidget {
  const TaskHistoryPage({super.key});

  @override
  State<TaskHistoryPage> createState() => _TaskHistoryPageState();
}

class _TaskHistoryPageState extends State<TaskHistoryPage> {
  final List<TaskStatus> _historyStatuses = [
    TaskStatus.completed,
    TaskStatus.canceled,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskCubit>().loadTasksHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<TaskCubit, TaskState>(
        builder: (context, state) {
          if (state is TaskLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is TasksLoaded) {
            final historyTasks =
                state.tasks
                    .where((task) => _historyStatuses.contains(task.status))
                    .toList();

            return historyTasks.isEmpty
                ? _buildEmptyState()
                : _buildHistoryList(historyTasks);
          }
          return const Center(child: Text('No history available'));
        },
      ),
    );
  }

  Widget _buildHistoryList(List<Task> tasks) {
    // Sort by completion date (newest first)
    tasks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final completedDate = DateFormat('MMM dd, yyyy').format(task.updatedAt);

        // Add headers for month groups
        Widget? header;
        if (index == 0 ||
            !_isSameMonth(tasks[index - 1].updatedAt, task.updatedAt)) {
          header = Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              DateFormat('MMMM yyyy').format(task.updatedAt),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null) header,
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(
                  task.title,
                  style: TextStyle(
                    decoration:
                        task.status == TaskStatus.canceled
                            ? TextDecoration.lineThrough
                            : null,
                  ),
                ),
                subtitle: Text(
                  '${task.status == TaskStatus.completed ? "Completed" : "Canceled"} on $completedDate',
                  style: TextStyle(
                    color:
                        task.status == TaskStatus.completed
                            ? Colors.green
                            : Colors.red,
                  ),
                ),
                leading: _buildStatusIcon(task.status),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/tasks/${task.id}'),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  Widget _buildStatusIcon(TaskStatus status) {
    return CircleAvatar(
      backgroundColor:
          status == TaskStatus.completed
              ? Colors.green.withOpacity(0.2)
              : Colors.red.withOpacity(0.2),
      child: Icon(
        status == TaskStatus.completed ? Icons.check_circle : Icons.cancel,
        color: status == TaskStatus.completed ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No task history yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Completed or canceled tasks will appear here',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Filter History',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Completed'),
                      onPressed: () {
                        context.read<TaskCubit>().loadTasksByStatus(
                          TaskStatus.completed,
                        );
                        Navigator.pop(context);
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Canceled'),
                      onPressed: () {
                        context.read<TaskCubit>().loadTasksByStatus(
                          TaskStatus.canceled,
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    context.read<TaskCubit>().loadTasksHistory();
                    Navigator.pop(context);
                  },
                  child: const Text('Show All'),
                ),
              ],
            ),
          ),
    );
  }
}
