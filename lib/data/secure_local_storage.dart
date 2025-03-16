import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureLocalStorage extends LocalStorage {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const _accessTokenKey = 'supabase_access_token';
  static const _refreshTokenKey = 'supabase_refresh_token';
  static const _sessionKey = 'supabase_session';

  @override
  Future<String?> getItem({required String key}) async {
    return await _secureStorage.read(key: key);
  }

  @override
  Future<void> removeItem({required String key}) async {
    await _secureStorage.delete(key: key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    await _secureStorage.write(key: key, value: value);
  }

  @override
  Future<String?> accessToken() async {
    return await getItem(key: _accessTokenKey);
  }

  @override
  Future<bool> hasAccessToken() async {
    final token = await accessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> initialize() async {
    // No additional initialization needed for secure storage
    return;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await setItem(key: _sessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await removeItem(key: _accessTokenKey);
    await removeItem(key: _refreshTokenKey);
    await removeItem(key: _sessionKey);
  }
}
