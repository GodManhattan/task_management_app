import 'dart:math';

class RetryStrategy {
  final int maxRetries;
  final Duration initialDelay;
  final double multiplier;
  final Duration maxDelay;
  final bool useJitter;

  const RetryStrategy({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 1),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(minutes: 2),
    this.useJitter = true,
  });

  Duration getDelayForAttempt(int attempt) {
    if (attempt < 0 || attempt >= maxRetries) {
      return const Duration(seconds: 0);
    }

    // Calculate exponential backoff
    final exponentialDelay =
        initialDelay.inMilliseconds * pow(multiplier, attempt);

    // Cap at max delay
    final cappedDelay = min(exponentialDelay, maxDelay.inMilliseconds);

    // Apply jitter if enabled (random variation to prevent thundering herd)
    if (useJitter) {
      final random = Random();
      // Add up to 30% random jitter
      final jitter = random.nextDouble() * 0.3 + 0.85; // 0.85-1.15 range
      return Duration(milliseconds: (cappedDelay * jitter).toInt());
    }

    return Duration(milliseconds: cappedDelay.toInt());
  }

  /// Returns true if another retry should be attempted
  bool shouldRetry(int attempt) {
    return attempt < maxRetries;
  }
}

/// Different strategies for different scenarios
class RetryStrategies {
  /// Quick reconnection strategy for active user interactions
  static RetryStrategy get activeInteraction => RetryStrategy(
    maxRetries: 3,
    initialDelay: const Duration(milliseconds: 500),
    multiplier: 1.5,
    maxDelay: const Duration(seconds: 5),
    useJitter: true,
  );

  /// Medium backoff for background operations
  static RetryStrategy get background => RetryStrategy(
    maxRetries: 5,
    initialDelay: const Duration(seconds: 2),
    multiplier: 2.0,
    maxDelay: const Duration(minutes: 1),
    useJitter: true,
  );

  /// Longer backoff for non-critical operations
  static RetryStrategy get nonCritical => RetryStrategy(
    maxRetries: 8,
    initialDelay: const Duration(seconds: 5),
    multiplier: 2.0,
    maxDelay: const Duration(minutes: 5),
    useJitter: true,
  );
}
