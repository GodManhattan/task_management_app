import 'dart:async';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A simplified service that handles Supabase realtime subscriptions with basic error handling
class RealtimeService {
  final SupabaseClient _supabaseClient;
  final Logger _logger = Logger();

  // Keep track of active subscriptions
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, StreamController> _streamControllers = {};

  // Basic retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  RealtimeService(this._supabaseClient);

  /// Create a subscription to a Supabase table with basic error handling
  Stream<List<T>> createTableSubscription<T>({
    required String table,
    required String primaryKey,
    required T Function(Map<String, dynamic>) fromJson,
    String? eq,
    dynamic eqValue,
  }) {
    final channelId = '${table}_${DateTime.now().millisecondsSinceEpoch}';
    final streamController = StreamController<List<T>>.broadcast(
      onCancel: () {
        // Clean up when no one is listening
        _activeSubscriptions[channelId]?.cancel();
        _activeSubscriptions.remove(channelId);
        _streamControllers.remove(channelId);
      },
    );

    _streamControllers[channelId] = streamController;

    // Do initial data fetch to populate right away
    _fetchData<T>(table: table, fromJson: fromJson, eq: eq, eqValue: eqValue)
        .then((items) {
          if (!streamController.isClosed) {
            streamController.add(items);
          }
        })
        .catchError((error) {
          _logger.e('Error in initial fetch for $table', error: error);
          // Don't propagate the error to avoid breaking the stream
        });

    // Set up the subscription with error handling
    _setupSubscription<T>(
      channelId: channelId,
      table: table,
      primaryKey: primaryKey,
      fromJson: fromJson,
      eq: eq,
      eqValue: eqValue,
    );

    return streamController.stream;
  }

  // Helper to fetch data directly (used for initial fetch and fallback)
  Future<List<T>> _fetchData<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    String? eq,
    dynamic eqValue,
  }) async {
    // Build the query
    var query = _supabaseClient.from(table).select();

    // Apply eq filter if provided
    if (eq != null && eqValue != null) {
      query = query.eq(eq, eqValue);
    }

    // Execute the query
    final data = await query;

    // Convert and return data
    return data.map<T>((item) => fromJson(item)).toList();
  }

  void _setupSubscription<T>({
    required String channelId,
    required String table,
    required String primaryKey,
    required T Function(Map<String, dynamic>) fromJson,
    String? eq,
    dynamic eqValue,
    int retryCount = 0,
  }) {
    // Cancel existing subscription if any
    _activeSubscriptions[channelId]?.cancel();

    try {
      // Build the subscription query
      SupabaseStreamBuilder query = _supabaseClient
          .from(table)
          .stream(primaryKey: [primaryKey]);
      // Apply eq filter if provided
      if (eq != null && eqValue != null) {
        query = _supabaseClient
            .from(table)
            .stream(primaryKey: [primaryKey]) // ✅ Streaming directly from table
            .eq(eq, eqValue); // Apply filters after calling .stream()
      }

      // Subscribe and handle the data with error handling
      final subscription = query.listen(
        (data) {
          final items = data.map<T>((item) => fromJson(item)).toList();
          if (_streamControllers.containsKey(channelId) &&
              !_streamControllers[channelId]!.isClosed) {
            _streamControllers[channelId]!.add(items);
          }
        },
        onError: (error) {
          _logger.e('Realtime subscription error for $table', error: error);

          // Only retry if not at max retries
          if (retryCount < _maxRetries) {
            // Schedule retry with a simple delay
            Future.delayed(_retryDelay, () {
              if (_streamControllers.containsKey(channelId) &&
                  !_streamControllers[channelId]!.isClosed) {
                _setupSubscription<T>(
                  channelId: channelId,
                  table: table,
                  primaryKey: primaryKey,
                  fromJson: fromJson,
                  eq: eq,
                  eqValue: eqValue,
                  retryCount: retryCount + 1,
                );
              }
            });
          } else {
            // At max retries, fall back to polling
            _startPolling<T>(
              channelId: channelId,
              table: table,
              fromJson: fromJson,
              eq: eq,
              eqValue: eqValue,
            );
          }
        },
      );

      // Store subscription for management
      _activeSubscriptions[channelId] = subscription;
    } catch (e) {
      _logger.e('Failed to set up subscription for $table', error: e);

      // Fall back to polling immediately on setup failure
      _startPolling<T>(
        channelId: channelId,
        table: table,
        fromJson: fromJson,
        eq: eq,
        eqValue: eqValue,
      );
    }
  }

  void _startPolling<T>({
    required String channelId,
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    String? eq,
    dynamic eqValue,
  }) {
    // Don't log any errors or implement complex backoff for simplicity
    // Just do basic polling every 30 seconds as a fallback

    Timer.periodic(const Duration(seconds: 30), (timer) async {
      // Stop if the stream controller is closed
      if (!_streamControllers.containsKey(channelId) ||
          _streamControllers[channelId]!.isClosed) {
        timer.cancel();
        return;
      }

      try {
        final items = await _fetchData<T>(
          table: table,
          fromJson: fromJson,
          eq: eq,
          eqValue: eqValue,
        );

        if (!_streamControllers[channelId]!.isClosed) {
          _streamControllers[channelId]!.add(items);
        }
      } catch (e) {
        // Just log the error but keep the timer running
        _logger.e('Error polling data for $table', error: e);
      }
    });
  }

  // In your RealtimeService.dart
  void checkRealtimeStatus() {
    final isConnected = _supabaseClient.realtime.isConnected;
    final channels = _supabaseClient.realtime.channels;

    print("Realtime connected: $isConnected");
    print("Active channels: ${channels.length}");

    for (final channel in channels) {
      print("Channel: ${channel.topic}, state: ${channel.presence.state}");
    }
  }

  /// Dispose all active subscriptions
  void dispose() {
    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();

    for (final controller in _streamControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _streamControllers.clear();
  }
}
