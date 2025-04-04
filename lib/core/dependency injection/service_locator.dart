import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_management_app/cubits/auth/cubit/auth_cubit.dart';
import 'package:task_management_app/cubits/comment/cubit/comment_cubit.dart';
import 'package:task_management_app/cubits/task/cubit/task_cubit.dart';
import 'package:task_management_app/cubits/team/cubit/team_cubit.dart';
import 'package:task_management_app/cubits/user/cubit/user_cubit.dart';
import 'package:task_management_app/data/repositories/supabase_team.repository.dart';
import 'package:task_management_app/data/repositories/supabase_user.repository.dart';
import 'package:task_management_app/domain/repositories/team.repository.dart';
import 'package:task_management_app/domain/repositories/user.repository.dart';
import '../../data/repositories/supabase_auth.repository.dart';
import '../../data/repositories/supabase_task.repository.dart';
import '../../data/repositories/supabase_comment.repository.dart';
import '../../domain/repositories/auth.repository.dart';
import '../../domain/repositories/task.repository.dart';
import '../../domain/repositories/comment.repository.dart';

final serviceLocator = GetIt.instance;

Future<void> setupServiceLocator() async {
  // External dependencies
  final supabase = Supabase.instance.client;
  serviceLocator.registerLazySingleton<SupabaseClient>(() => supabase);

  // Repositories
  serviceLocator.registerLazySingleton<AuthRepository>(
    () => SupabaseAuthRepository(serviceLocator()),
  );

  // Register task repository with proper disposal
  serviceLocator.registerLazySingleton<TaskRepository>(
    () => SupabaseTaskRepository(serviceLocator()),
    dispose: (repo) {
      if (repo is SupabaseTaskRepository) {
        repo.dispose();
      }
    },
  );

  // Register comment repository with proper disposal
  serviceLocator.registerLazySingleton<CommentRepository>(
    () => SupabaseCommentRepository(serviceLocator()),
    dispose: (repo) {
      if (repo is SupabaseCommentRepository) {
        repo.dispose();
      }
    },
  );

  serviceLocator.registerLazySingleton<AuthCubit>(
    () => AuthCubit(serviceLocator<AuthRepository>()),
  );

  serviceLocator.registerLazySingleton<UserRepository>(
    () => SupabaseUserRepository(serviceLocator<SupabaseClient>()),
  );

  serviceLocator.registerFactory<UserCubit>(
    () => UserCubit(serviceLocator<UserRepository>()),
  );

  serviceLocator.registerFactory<CommentCubit>(
    () => CommentCubit(serviceLocator<CommentRepository>()),
  );

  serviceLocator.registerFactory<TaskCubit>(
    () => TaskCubit(serviceLocator<TaskRepository>()),
  );

  serviceLocator.registerFactory<TeamRepository>(
    () => SupabaseTeamRepository(serviceLocator<SupabaseClient>()),
  );

  serviceLocator.registerFactory<TeamCubit>(
    () => TeamCubit(serviceLocator<TeamRepository>()),
  );
}

// Call this method when the app is being terminated
void disposeServiceLocator() {
  serviceLocator.reset();
}
