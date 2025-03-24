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
  // Local cache of tasks to prevent UI flashing
  List<Task> _displayedTasks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Load history tasks once
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load tasks directly from repository via cubit
      final taskCubit = context.read<TaskCubit>();
      await taskCubit.loadTasks(isHistory: true);

      if (!mounted) return;

      setState(() {
        // Maintain local state for UI stability
        final state = taskCubit.state;
        if (state is TasksLoaded && state.isHistoryView) {
          _displayedTasks = state.tasks;
        } else {
          _displayedTasks = taskCubit.getHistoryTasks();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load history: $e';
        _isLoading = false;
      });
    }
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoryData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildErrorState(_errorMessage!)
              : _displayedTasks.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(_displayedTasks),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadHistoryData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<Task> tasks) {
    // Sort by completion date (newest first)
    final sortedTasks = List<Task>.from(tasks);
    sortedTasks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return ListView.builder(
      itemCount: sortedTasks.length,
      itemBuilder: (context, index) {
        final task = sortedTasks[index];
        final completedDate = DateFormat('MMM dd, yyyy').format(task.updatedAt);

        // Add headers for month groups
        Widget? header;
        if (index == 0 ||
            !_isSameMonth(sortedTasks[index - 1].updatedAt, task.updatedAt)) {
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadHistoryData,
            child: const Text('Refresh'),
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
                      onPressed: () async {
                        Navigator.pop(context);

                        setState(() {
                          _isLoading = true;
                        });

                        await context.read<TaskCubit>().loadTasks(
                          status: TaskStatus.completed,
                        );

                        if (!mounted) return;

                        final state = context.read<TaskCubit>().state;
                        setState(() {
                          if (state is TasksLoaded) {
                            _displayedTasks = state.tasks;
                          }
                          _isLoading = false;
                        });
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Canceled'),
                      onPressed: () async {
                        Navigator.pop(context);

                        setState(() {
                          _isLoading = true;
                        });

                        await context.read<TaskCubit>().loadTasks(
                          status: TaskStatus.canceled,
                        );

                        if (!mounted) return;

                        final state = context.read<TaskCubit>().state;
                        setState(() {
                          if (state is TasksLoaded) {
                            _displayedTasks = state.tasks;
                          }
                          _isLoading = false;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadHistoryData();
                  },
                  child: const Text('Show All History'),
                ),
              ],
            ),
          ),
    );
  }
}
