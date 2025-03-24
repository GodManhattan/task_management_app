// lib/core/utils/file_cache_manager.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileCacheManager {
  static const String _cacheKeyPrefix = 'file_cache_';
  static final Map<String, String> _activeDownloads = {};

  // Get a file from cache or download it
  static Future<File> getFile(String url, String fileName) async {
    // Generate cache key and path
    final cacheKey = _getCacheKey(url);
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);

    // Check if file exists in cache and is recent
    if (await _isFileInCache(cacheKey, file)) {
      return file;
    }

    // File doesn't exist or is outdated, download it
    await _downloadFile(url, filePath);

    // Register in cache
    await _registerInCache(cacheKey, filePath);

    return file;
  }

  // Check if file exists in cache and is not expired
  static Future<bool> _isFileInCache(String cacheKey, File file) async {
    if (!await file.exists()) return false;

    // Check if registered in cache preferences
    final prefs = await SharedPreferences.getInstance();
    final cachedTime = prefs.getInt(cacheKey);

    if (cachedTime == null) return false;

    // Check if cache is expired (24 hours)
    final cachedDateTime = DateTime.fromMillisecondsSinceEpoch(cachedTime);
    final now = DateTime.now();
    return now.difference(cachedDateTime).inHours < 24;
  }

  // Download a file
  static Future<void> _downloadFile(String url, String filePath) async {
    if (_activeDownloads.containsKey(url)) {
      // Wait for existing download to complete
      final existingPath = _activeDownloads[url]!;
      if (existingPath == filePath) {
        while (_activeDownloads.containsKey(url)) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return;
      }
    }

    _activeDownloads[url] = filePath;

    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();
      await dio.download(url, filePath);
    } finally {
      _activeDownloads.remove(url);
    }
  }

  // Register file in cache with current timestamp
  static Future<void> _registerInCache(String cacheKey, String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(cacheKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Generate a consistent cache key for a URL
  static String _getCacheKey(String url) {
    return '$_cacheKeyPrefix${url.hashCode}';
  }

  // Clean expired cache files
  static Future<void> cleanupCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final now = DateTime.now();
    final dir = await getTemporaryDirectory();

    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix)) {
        final cachedTime = prefs.getInt(key) ?? 0;
        final cachedDateTime = DateTime.fromMillisecondsSinceEpoch(cachedTime);

        // If older than 24 hours, clean up
        if (now.difference(cachedDateTime).inHours >= 24) {
          // Get file path from key
          try {
            final filePath =
                '${dir.path}/${key.substring(_cacheKeyPrefix.length)}';
            final file = File(filePath);
            if (await file.exists()) {
              await file.delete();
            }
            await prefs.remove(key);
          } catch (e) {
            // Just remove the key if file doesn't exist
            await prefs.remove(key);
          }
        }
      }
    }
  }
}
