import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_management_app/core/dependency%20injection/service_locator.dart';
import 'package:task_management_app/core/helpers/file_cache_manager.dart';

import 'package:task_management_app/core/routing/app_router.dart';

import 'package:task_management_app/cubits/auth/cubit/auth_cubit.dart'
    as authCubit;
import 'package:task_management_app/cubits/auth/cubit/auth_cubit.dart';
import 'package:task_management_app/cubits/comment/cubit/comment_cubit.dart';
import 'package:task_management_app/cubits/task/cubit/task_cubit.dart';
import 'package:task_management_app/cubits/team/cubit/team_cubit.dart';
import 'package:task_management_app/cubits/user/cubit/user_cubit.dart';

import 'package:task_management_app/data/secure_local_storage.dart';
import 'package:task_management_app/domain/repositories/auth.repository.dart';
import 'package:task_management_app/domain/repositories/task.repository.dart';
import 'package:task_management_app/handlers/handlers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:task_management_app/presentation/pages/error/error_page.dart';
import 'package:task_management_app/core/config/app_config.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  try {
    // First load environment variables
    await dotenv.load(fileName: ".env");

    // Initialize Supabase
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage:
            SecureLocalStorage(), // Custom secure storage implementation
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10, // Limit events per second to avoid overwhelming
      ),
    );

    // Initialize deep links before running the app
    await initDeepLinks();

    // Setup service locator
    await setupServiceLocator();

    // Clean up expired cached files
    await FileCacheManager.cleanupCache();

    // Periodic session verification
    Timer.periodic(Duration(minutes: 30), (_) {
      serviceLocator<AuthCubit>().verifySession();
    });

    // Remove the splash screen when initialization is done
    FlutterNativeSplash.remove();
    runApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<authCubit.AuthCubit>(
            create:
                (context) =>
                    authCubit.AuthCubit(serviceLocator<AuthRepository>()),
          ),
          BlocProvider<TaskCubit>(
            create: (context) => TaskCubit(serviceLocator<TaskRepository>()),
          ),
          BlocProvider<UserCubit>(
            create: (context) => serviceLocator<UserCubit>(),
          ),
          BlocProvider<CommentCubit>(
            create: (context) => serviceLocator<CommentCubit>(),
          ),
          BlocProvider<TeamCubit>(
            create: (context) => serviceLocator<TeamCubit>(),
          ),
        ],
        child: const MainApp(),
      ),
    );
  } catch (e) {
    // If there's an error during initialization, still remove the splash screen
    // and show the app with appropriate error handling
    FlutterNativeSplash.remove();
    runApp(ErrorPage(errorMessage: e.toString()));
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Task Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: AppRouter.router,
    );
  }

  @override
  void dispose() {
    // Clean up resources when app is terminated
    disposeServiceLocator();
    super.dispose();
  }
}
