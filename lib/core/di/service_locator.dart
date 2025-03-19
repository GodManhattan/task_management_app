import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_management_app/cubits/auth/cubit/auth_cubit.dart';
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

  serviceLocator.registerLazySingleton<TaskRepository>(
    () => SupabaseTaskRepository(serviceLocator()),
  );

  serviceLocator.registerLazySingleton<CommentRepository>(
    () => SupabaseCommentRepository(serviceLocator()),
  );

  serviceLocator.registerLazySingleton<AuthCubit>(
    () => AuthCubit(serviceLocator<AuthRepository>()),
  );
}
