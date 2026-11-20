import "dart:async";

import "package:dio/dio.dart";

import "../../core/ai/chat_provider.dart";

/// Give direct tasks a total deadline, including streams that keep sending
/// heartbeats. Late replies from an adapter that ignores cancellation are
/// detached and cannot reach the parser or persistence.
Stream<AiChunk> boundedLanguageStream(
  Stream<AiChunk> Function(CancelToken) start,
  CancelToken cancel, {
  Duration deadline = const Duration(minutes: 2),
}) {
  final transport = CancelToken();
  StreamSubscription<AiChunk>? subscription;
  Timer? timer;
  late final StreamController<AiChunk> output;

  void finish() {
    timer?.cancel();
    transport.cancel();
    unawaited(subscription?.cancel().catchError((Object _) {}));
  }

  output = StreamController<AiChunk>(
    onListen: () {
      if (cancel.isCancelled) {
        output.addError(cancel.cancelError!);
        unawaited(output.close());
        return;
      }
      unawaited(
        cancel.whenCancel.then((error) {
          if (output.isClosed) return;
          output.addError(error);
          unawaited(output.close());
          finish();
        }),
      );
      unawaited(
        transport.whenCancel.then((error) {
          if (output.isClosed) return;
          output.addError(error);
          unawaited(output.close());
          finish();
        }),
      );
      timer = Timer(deadline, () {
        if (output.isClosed) return;
        output.addError(
          TimeoutException("Language response timed out", deadline),
        );
        unawaited(output.close());
        finish();
      });
      try {
        subscription = start(transport).listen(
          (event) {
            if (!output.isClosed) output.add(event);
          },
          onError: (Object error, StackTrace stack) {
            if (output.isClosed) return;
            output.addError(error, stack);
            unawaited(output.close());
            finish();
          },
          onDone: () {
            timer?.cancel();
            unawaited(output.close());
          },
        );
      } catch (error, stack) {
        output.addError(error, stack);
        unawaited(output.close());
        finish();
      }
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: finish,
  );
  return output.stream;
}
