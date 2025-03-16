import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_management_app/core/di/service_locator.dart';
import 'package:task_management_app/core/routing/app_router.dart';
import 'package:task_management_app/core/routing/navigation_helpers.dart';
import 'package:task_management_app/cubits/auth/auth_cubit.dart' as authCubit;
import 'package:task_management_app/cubits/auth/auth_cubit.dart';
import 'package:task_management_app/data/secure_local_storage.dart';
import 'package:task_management_app/domain/repositories/auth.repository.dart';
import 'package:task_management_app/handlers/handlers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:task_management_app/presentation/pages/error/error_page.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: 'https://chwswwssmegejiknagqz.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNod3N3d3NzbWVnZWppa25hZ3F6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1NTAyOTQsImV4cCI6MjA1NzEyNjI5NH0.SByMYeavX2FLcseCL9xWv8nZkdKednpsYnEYrNVqI00',
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
          // Other providers
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
      builder: (context, child) {
        return BlocListener<AuthCubit, authCubit.AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              // Navigate with GoRouter directly instead of context extension
              AppRouter.router.go('/tasks');
            } else if (state is AuthUnauthenticated) {
              AppRouter.router.go('/login');
            }
          },
          child: child!,
        );
      },
    );
  }
}
