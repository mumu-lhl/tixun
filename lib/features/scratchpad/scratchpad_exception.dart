/// Stable failure categories for application-generated scratchpad errors.
enum ScratchpadError {
  unreadable,
  saveFailed,
  tooManyPages,
  tooLarge,
  invalidContext,
}

/// Retains the source message for logs and existing FormatException handlers.
class ScratchpadException extends FormatException {
  const ScratchpadException(this.code, super.message);
  final ScratchpadError code;
}
