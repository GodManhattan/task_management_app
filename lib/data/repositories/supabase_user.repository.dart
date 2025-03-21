import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/user.model.dart' as usermodel;
import '../../domain/repositories/user.repository.dart';

class SupabaseUserRepository implements UserRepository {
  final SupabaseClient _supabaseClient;

  SupabaseUserRepository(this._supabaseClient);

  @override
  Future<usermodel.User> getUserById(String id) async {
    final data =
        await _supabaseClient.from('profiles').select().eq('id', id).single();

    return usermodel.User.fromJson(data);
  }

  @override
  Future<List<usermodel.User>> getUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final data = await _supabaseClient
        .from('profiles')
        .select()
        .inFilter('id', ids);

    return data
        .map<usermodel.User>((json) => usermodel.User.fromJson(json))
        .toList();
  }

  @override
  Future<usermodel.User> getCurrentUser() async {
    final currentUser = _supabaseClient.auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final data =
        await _supabaseClient
            .from('profiles')
            .select()
            .eq('id', currentUser.id)
            .single();

    return usermodel.User.fromJson(data);
  }
  
}
