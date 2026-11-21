/// Typed failures returned or thrown by repositories.
sealed class Failure implements Exception {
  const Failure(this.message);

  final String message;

  @override
  String toString() => 'Failure: $message';
}

/// The device cannot reach the server right now.
final class OfflineFailure extends Failure {
  const OfflineFailure([super.message = 'offline']);
}

/// Anything unexpected.
final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'unknown']);
}
