/// Represents an expected, user-facing app error (not a crash).
/// These errors should be displayed to the user via a snackbar or dialog,
/// never silently swallowed or allowed to crash the app.
class AppException implements Exception {
  final String userMessage;
  final String? developerMessage;
  final Object? originalError;

  const AppException(
    this.userMessage, {
    this.developerMessage,
    this.originalError,
  });

  @override
  String toString() {
    final buffer = StringBuffer('AppException: $userMessage');
    if (developerMessage != null) {
      buffer.write(' | $developerMessage');
    }
    if (originalError != null) {
      buffer.write(' | Original: $originalError');
    }
    return buffer.toString();
  }
}

/// Database-specific exception with clear user-facing messages.
class AppDatabaseException extends AppException {
  const AppDatabaseException({
    required String userMessage,
    String? developerMessage,
    Object? originalError,
  }) : super(
          userMessage,
          developerMessage: developerMessage,
          originalError: originalError,
        );
}