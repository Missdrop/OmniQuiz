// Carries retry decisions across layers without exposing transport or credential details.

/// A user-facing failure with an explicit retry policy for remote operations.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.retryable = false, this.retryAfter});
  final Duration? retryAfter;
  final String message;
  final bool retryable;
  @override
  String toString() => message;
}
