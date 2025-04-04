import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:task_management_app/presentation/pages/team/team_page.dart';

/// Extension methods for GoRouter navigation
extension GoRouterNavigation on BuildContext {
  /// Navigate to a route
  void goTo(String route) => GoRouter.of(this).go(route);

  /// Push a route onto the navigation stack
  void pushTo(String route) => GoRouter.of(this).push(route);

  /// Replace the current route
  void replaceTo(String route) => GoRouter.of(this).replace(route);

  /// Go back to the previous route
  void goBack() => GoRouter.of(this).pop();

  /// Navigate to the tasks list
  void goToTasks() => GoRouter.of(this).go('/tasks');

  /// Navigate to task detail
  void goToTaskDetail(String taskId) => GoRouter.of(this).go('/tasks/$taskId');

  /// Navigate to create task
  void goToCreateTask() => GoRouter.of(this).push('/tasks/create');

  /// Navigate to profile
  void goToProfile() => GoRouter.of(this).go('/profile');

  /// Navigate to team
  void goToTeam() => GoRouter.of(this).go('/team');

  /// Navigate to login
  void goToLogin() => GoRouter.of(this).go('/login');

  /// Navigate to register
  void goToRegister() => GoRouter.of(this).go('/register');

  /// Navigate to forgot password
  void goToForgotPassword() => GoRouter.of(this).go('/forgot-password');

  /// Sign out and navigate to login
  void signOut() => GoRouter.of(this).go('/login');

  /// Navigate to history
  void goToHistory() => GoRouter.of(this).go('/history');

   /// Navigate to team detail
  void goToTeamDetail(String teamId) => GoRouter.of(this).go('/team/$teamId');

  /// Navigate to create team
  void showCreateTeamDialog() {
    showDialog(context: this, builder: (context) => const CreateTeamDialog());
  }
}
