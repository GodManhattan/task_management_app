import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

/// Callback for connectivity change notifications
typedef ConnectivityChangeCallback = void Function(bool isConnected);

/// A service that monitors network connectivity and notifies subscribers
/// of changes.
class NetworkMonitor {
  final Connectivity _connectivity = Connectivity();
  final Logger _logger = Logger();

  // Stream subscription for connectivity events
  StreamSubscription? _connectivitySubscription;

  // Current connectivity state
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  // Subscribers to connectivity changes
  final List<ConnectivityChangeCallback> _subscribers = [];

  // Singleton pattern
  static NetworkMonitor? _instance;

  factory NetworkMonitor() {
    _instance ??= NetworkMonitor._internal();
    return _instance!;
  }

  NetworkMonitor._internal();

  /// Initialize the network monitor
  Future<void> initialize() async {
    // Check initial connectivity
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result as ConnectivityResult);
    } catch (e) {
      _logger.e('Failed to check initial connectivity', error: e);
      // Default to assuming we're connected
      _isConnected = true;
    }

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus as void Function(List<ConnectivityResult> event)?,
    );

    _logger.d('NetworkMonitor initialized, connected: $_isConnected');
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;

    _logger.d('Connectivity changed: $result, connected: $_isConnected');

    // Only notify if there was an actual change
    if (wasConnected != _isConnected) {
      _notifySubscribers();
    }
  }

  void _notifySubscribers() {
    for (final subscriber in _subscribers) {
      try {
        subscriber(_isConnected);
      } catch (e) {
        _logger.e('Error notifying subscriber', error: e);
      }
    }
  }

  /// Subscribe to connectivity change notifications
  void subscribe(ConnectivityChangeCallback callback) {
    if (!_subscribers.contains(callback)) {
      _subscribers.add(callback);

      // Immediately notify of current state
      try {
        callback(_isConnected);
      } catch (e) {
        _logger.e('Error in immediate notification to subscriber', error: e);
      }
    }
  }

  /// Unsubscribe from connectivity change notifications
  void unsubscribe(ConnectivityChangeCallback callback) {
    _subscribers.remove(callback);
  }

  /// Dispose the network monitor
  void dispose() {
    _connectivitySubscription?.cancel();
    _subscribers.clear();
    _instance = null;
  }
}
