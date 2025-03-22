import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:task_management_app/core/routing/global_route_observer.dart';
import 'package:task_management_app/cubits/task/cubit/task_cubit.dart';
import 'package:task_management_app/domain/models/task.model.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with RouteAware {
  // Local cache of tasks to prevent UI flashing
  List<Task> _displayedTasks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Load active tasks on initial load
    _loadActiveTasks();
  }

  Future<void> _loadActiveTasks() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load tasks directly from repository via cubit
      final taskCubit = context.read<TaskCubit>();
      await taskCubit.loadTasks(forceRefresh: true);

      if (!mounted) return;

      setState(() {
        // Maintain local state for UI stability
        final state = taskCubit.state;
        if (state is TasksLoaded && !state.isHistoryView) {
          _displayedTasks = state.tasks;
        } else {
          _displayedTasks = taskCubit.getActiveTasks();
        }
        _isLoading = false;
      });

      // Setup subscription after initial load
      taskCubit.subscribeToTasks();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load tasks: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // When returning to this page, refresh tasks
    _loadActiveTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActiveTasks,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed:
                () => showModalBottomSheet(
                  context: context,
                  builder: (context) => _buildFilterOptions(context),
                ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.go('/tasks/history'),
            tooltip: 'History',
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
              : ListView.builder(
                itemCount: _displayedTasks.length,
                itemBuilder: (context, index) {
                  final task = _displayedTasks[index];
                  return ListTile(
                    title: Text(task.title),
                    subtitle: Text(task.description ?? ''),
                    trailing: Chip(
                      label: Text(task.status.name),
                      backgroundColor: _getStatusColor(task.status),
                    ),
                    onTap: () => context.go('/tasks/${task.id}'),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/tasks/create'),
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
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
            onPressed: _loadActiveTasks,
            child: const Text('Retry'),
          ),
        ],
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
            'No active tasks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to create a new task',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadActiveTasks,
            child: const Text('Reload'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOptions(BuildContext context) {
    final activeStatuses = [
      TaskStatus.pending,
      TaskStatus.inProgress,
      TaskStatus.underReview,
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Tasks',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('Status'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  activeStatuses.map((status) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(status.name),
                        onSelected: (selected) async {
                          Navigator.pop(context);

                          setState(() {
                            _isLoading = true;
                          });

                          if (selected) {
                            await context.read<TaskCubit>().loadTasksByStatus(
                              status,
                            );
                          } else {
                            await context.read<TaskCubit>().loadTasks();
                          }

                          if (!mounted) return;

                          final state = context.read<TaskCubit>().state;
                          setState(() {
                            if (state is TasksLoaded) {
                              _displayedTasks = state.tasks;
                            }
                            _isLoading = false;
                          });
                        },
                        selected: false,
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadActiveTasks();
            },
            child: const Text('Clear Filters'),
          ),
        ],
      ),
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
}
