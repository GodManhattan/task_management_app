import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_management_app/core/di/service_locator.dart';
import 'package:task_management_app/core/routing/app_router.dart';

import 'package:task_management_app/cubits/auth/cubit/auth_cubit.dart'
    as authCubit;
import 'package:task_management_app/cubits/auth/cubit/auth_cubit.dart';
import 'package:task_management_app/cubits/comment/cubit/comment_cubit.dart';
import 'package:task_management_app/cubits/task/cubit/task_cubit.dart';
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
    );
    // Initialize deep links before running the app
    await initDeepLinks();

    // Setup service locator
    await setupServiceLocator();

    // In your app initialization
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
        ],
        child: const MainApp(),
      ),
    );
  } catch (e) {
    // If there's an error during initialization, still remove the splash screen
    // and show the app with appropriate error handling
    FlutterNativeSplash.remove();
    runApp(const ErrorPage());
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

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
}
