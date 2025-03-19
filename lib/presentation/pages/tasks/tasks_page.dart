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
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    // Load tasks when the page is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskCubit = context.read<TaskCubit>();
      taskCubit.loadTasks();
      taskCubit.subscribeToTasks(); // Enable real-time updates
    });
  }

  void _loadTasks() {
    final taskCubit = context.read<TaskCubit>();
    // Force refresh on first load, use cache on subsequent loads
    taskCubit.loadTasks(forceRefresh: _isFirstLoad);
    if (_isFirstLoad) {
      _isFirstLoad = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register with RouteObserver
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

  // Called when returning to this route
  @override
  void didPopNext() {
    debugPrint('TasksPage didPopNext called');
    // Reload tasks when returning to this page
    _loadTasks();
  }

  @override
  void activate() {
    super.activate();
    // This is called when the widget is re-inserted into the widget tree
    debugPrint('TasksPage activate called');
    _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    // Check the current state on each build
    final currentState = context.read<TaskCubit>().state;
    if (currentState is! TasksLoaded && currentState is! TaskLoading) {
      debugPrint(
        'TasksPage build detected non-loaded state: ${currentState.runtimeType}',
      );
      // Schedule a reload if we don't have tasks and aren't already loading
      Future.microtask(() => _loadTasks());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          // Add a manual refresh button for testing
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                () => context.read<TaskCubit>().loadTasks(forceRefresh: true),
            tooltip: 'Force Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Show filter options in a modal bottom sheet
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildFilterOptions(context),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<TaskCubit, TaskState>(
        // Listen for state changes and log them for debugging
        listener: (context, state) {
          debugPrint('TasksPage state changed to: ${state.runtimeType}');
          if (state is TasksLoaded) {
            debugPrint('Tasks loaded: ${state.tasks.length} tasks');
          }
        },
        builder: (context, state) {
          if (state is TaskLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is TasksLoaded) {
            return state.tasks.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                  onRefresh:
                      () => context.read<TaskCubit>().loadTasks(
                        forceRefresh: true,
                      ),
                  child: ListView.builder(
                    itemCount: state.tasks.length,
                    itemBuilder: (context, index) {
                      final task = state.tasks[index];
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
                );
          } else if (state is TaskError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.message,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed:
                        () => context.read<TaskCubit>().loadTasks(
                          forceRefresh: true,
                        ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return const Center(child: Text('No tasks yet'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/tasks/create'),
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
            'No tasks yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to create a new task',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed:
                () => context.read<TaskCubit>().loadTasks(forceRefresh: true),
            child: const Text('Reload'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOptions(BuildContext context) {
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
                  TaskStatus.values.map((status) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(status.name),
                        onSelected: (selected) {
                          if (selected) {
                            context.read<TaskCubit>().loadTasksByStatus(status);
                          } else {
                            context.read<TaskCubit>().loadTasks();
                          }
                          Navigator.pop(context);
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
              context.read<TaskCubit>().loadTasks();
              Navigator.pop(context);
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
