import "dart:isolate";

import "package:dio/dio.dart";

import "a2ui_catalog.dart";

Future<SendPort>? _worker;

Future<String> compileInlineSurface(
  String source,
  String id, {
  required bool drawingEnabled,
  required CancelToken cancel,
}) async {
  final worker = await (_worker ??= _start());
  if (cancel.cancelError case final error?) throw error;
  final reply = ReceivePort();
  try {
    worker.send((source, id, drawingEnabled, reply.sendPort));
    final result = await Future.any([
      reply.first,
      cancel.whenCancel.then<Never>((error) => throw error),
    ]);
    if (result is! String) {
      throw const FormatException("Invalid Express surface.");
    }
    return result;
  } finally {
    reply.close();
  }
}

Future<SendPort> _start() async {
  final ready = ReceivePort();
  try {
    await Isolate.spawn(_compile, ready.sendPort, debugName: "a2ui-compiler");
    return await ready.first as SendPort;
  } finally {
    ready.close();
  }
}

void _compile(SendPort parent) {
  final requests = ReceivePort();
  parent.send(requests.sendPort);
  requests.listen((payload) {
    final (source, id, drawingEnabled, reply) =
        payload as (String, String, bool, SendPort);
    try {
      reply.send(compileChatA2ui(source, id, drawingEnabled: drawingEnabled));
    } catch (_) {
      reply.send(null);
    }
  });
}
