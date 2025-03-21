import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:task_management_app/domain/models/task.model.dart';

class TaskHistoryTable extends StatefulWidget {
  final List<Task> tasks;

  const TaskHistoryTable({super.key, required this.tasks});

  @override
  State<TaskHistoryTable> createState() => _TaskHistoryTableState();
}

class _TaskHistoryTableState extends State<TaskHistoryTable> {
  int _sortColumnIndex = 2; // Default sort by date
  bool _sortAscending = false;
  List<Task> _sortedTasks = [];

  @override
  void initState() {
    super.initState();
    _sortedTasks = List.from(widget.tasks);
    _sortData();
  }

  @override
  void didUpdateWidget(TaskHistoryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tasks != oldWidget.tasks) {
      _sortedTasks = List.from(widget.tasks);
      _sortData();
    }
  }

  void _sortData() {
    setState(() {
      switch (_sortColumnIndex) {
        case 0: // Title
          _sortedTasks.sort(
            (a, b) =>
                _sortAscending
                    ? a.title.compareTo(b.title)
                    : b.title.compareTo(a.title),
          );
          break;
        case 1: // Status
          _sortedTasks.sort(
            (a, b) =>
                _sortAscending
                    ? a.status.name.compareTo(b.status.name)
                    : b.status.name.compareTo(a.status.name),
          );
          break;
        case 2: // Date
          _sortedTasks.sort(
            (a, b) =>
                _sortAscending
                    ? a.updatedAt.compareTo(b.updatedAt)
                    : b.updatedAt.compareTo(a.updatedAt),
          );
          break;
        case 3: // Priority
          _sortedTasks.sort(
            (a, b) =>
                _sortAscending
                    ? a.priority.index.compareTo(b.priority.index)
                    : b.priority.index.compareTo(a.priority.index),
          );
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          columns: [
            DataColumn(
              label: const Text('Title'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                  _sortData();
                });
              },
            ),
            DataColumn(
              label: const Text('Status'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                  _sortData();
                });
              },
            ),
            DataColumn(
              label: const Text('Completion Date'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                  _sortData();
                });
              },
            ),
            DataColumn(
              label: const Text('Priority'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                  _sortData();
                });
              },
            ),
          ],
          rows:
              _sortedTasks
                  .map(
                    (task) => DataRow(
                      cells: [
                        DataCell(
                          Text(
                            task.title,
                            style: TextStyle(
                              decoration:
                                  task.status == TaskStatus.canceled
                                      ? TextDecoration.lineThrough
                                      : null,
                            ),
                          ),
                          onTap: () => context.go('/tasks/${task.id}'),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  task.status == TaskStatus.completed
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.status.name,
                              style: TextStyle(
                                color:
                                    task.status == TaskStatus.completed
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            DateFormat('MMM dd, yyyy').format(task.updatedAt),
                          ),
                        ),
                        DataCell(
                          Text(
                            task.priority.name,
                            style: TextStyle(
                              color: _getPriorityColor(task.priority),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
        ),
      ),
    );
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
