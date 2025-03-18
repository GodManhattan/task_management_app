import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_management_app/cubits/task/cubit/task_cubit.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Load tasks when the page is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskCubit>().loadTasks();
    });

    return SafeArea(
      child: BlocBuilder<TaskCubit, TaskState>(
        builder: (context, state) {
          if (state is TaskLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is TasksLoaded) {
            return state.tasks.isEmpty
                ? const Center(child: Text('No tasks found'))
                : ListView.builder(
                  itemCount: state.tasks.length,
                  itemBuilder: (context, index) {
                    final task = state.tasks[index];
                    return ListTile(
                      title: Text(task.title),
                      subtitle: Text(task.description ?? ''),
                      trailing: Text(task.status.name),
                    );
                  },
                );
          } else if (state is TaskError) {
            return Center(
              child: Text(state.message, style: TextStyle(color: Colors.red)),
            );
          }
          return const Center(child: Text('No tasks yet'));
        },
      ),
    );
  }
}
