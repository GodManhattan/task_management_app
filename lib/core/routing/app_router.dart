import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:task_management_app/core/routing/global_route_observer.dart';
import 'package:task_management_app/presentation/pages/home/team_page.dart';
import 'package:task_management_app/presentation/pages/tasks/task_history.page.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/auth/register_page.dart';
import '../../presentation/pages/auth/forgot_password_page.dart';
import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/tasks/task_detail_page.dart';
import '../../presentation/pages/tasks/task_create_page.dart';
import '../../presentation/pages/settings/profile_page.dart';
import '../../presentation/pages/splash_page.dart';
import '../../presentation/pages/tasks/tasks_page.dart';
import '../di/service_locator.dart';
import '../../domain/repositories/auth.repository.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: _handleRedirect,
    observers: [appRouteObserver],
    routes: [
      // Splash screen
      GoRoute(path: '/', builder: (context, state) => const SplashPage()),

      // Authentication routes
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      // Main app shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => HomePage(child: child),
        // Add this property to preserve state
        restorationScopeId: 'shell',
        routes: [
          // Tasks tab
          GoRoute(
            path: '/tasks',
            pageBuilder:
                (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  restorationId: 'tasks-page',
                  child: const TasksPage(),
                ),
            routes: [
              GoRoute(
                path: 'create',
                pageBuilder:
                    (context, state) => MaterialPage(
                      key: state.pageKey,
                      child: const TaskCreatePage(),
                    ),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final taskId = state.pathParameters['id']!;
                  return MaterialPage(
                    key: state.pageKey,
                    child: TaskDetailPage(taskId: taskId),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/history',
            pageBuilder:
                (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  restorationId: 'history-page',
                  child: const TaskHistoryPage(),
                ),
          ),
          // Team tab
          GoRoute(path: '/team', builder: (context, state) => const TeamPage()),

          // Profile tab
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
    errorBuilder:
        (context, state) => Scaffold(
          body: Center(child: Text('Route not found: ${state.uri}')),
        ),
  );

  // // Getter to expose the observer to the rest of the app
  // static RouteObserver<PageRoute> get routeObserver => appRouteObserver;
  // Handle authentication redirects
  static Future<String?> _handleRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    final authRepository = serviceLocator<AuthRepository>();
    final isAuthenticated = await authRepository.isAuthenticated();

    // Skip auth check for splash/loading screens
    if (state.matchedLocation == '/') return null;

    final isAuthRoute =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register' ||
        state.matchedLocation == '/reset-password';

    // Perform a fresh session validation
    final isValid = await authRepository.isSessionValid();

    if (!isValid && !isAuthRoute) {
      // Update the auth state in the cubit
      authRepository.signOut();
      return '/login';
    }

    // If splash screen, no redirect
    if (state.matchedLocation == '/') {
      return null;
    }

    // If user is not authenticated and not on an auth route, redirect to login
    if (!isAuthenticated && !isAuthRoute) {
      return '/login';
    }

    // If user is authenticated and on an auth route, redirect to home
    if (isAuthenticated && isAuthRoute) {
      return '/tasks';
    }

    // No redirect needed
    return null;
  }
}
