class AppFailure implements Exception {
  final String message;
  final Object? cause;

  const AppFailure(this.message, {this.cause});

  @override
  String toString() => 'AppFailure: $message${cause != null ? ' ($cause)' : ''}';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.cause});
}

class DatabaseFailure extends AppFailure {
  const DatabaseFailure(super.message, {super.cause});
}

class TransferFailure extends AppFailure {
  const TransferFailure(super.message, {super.cause});
}
