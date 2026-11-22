import "dart:convert";
import "dart:isolate";

import "package:flutter/services.dart";

import "ai_types.dart";
import "model_tokenizer.dart";

/// Counts only text visible to the app, separately from provider usage.
/// Each field is tokenized independently; wire framing and images are excluded.
Future<String?> countRequestBreakdown({
  required String provider,
  required String model,
  required String endpoint,
  required AiRequest request,
  required String response,
  required String reasoning,
  required List<ToolCall> calls,
}) async {
  final encoding = ModelTokenizer.encodingFor(
    provider,
    model,
    endpoint: endpoint,
  );
  if (encoding == null || RootIsolateToken.instance == null) return null;
  // Image data is deliberately not passed to the worker or persisted.
  final fragments = <String, List<String>>{
    "system": [request.instructions],
    "user": [],
    "toolDefinitions": [
      for (final tool in request.tools)
        jsonEncode({
          "name": tool.name,
          "description": tool.description,
          "parameters": tool.parameters,
        }),
    ],
    "toolCalls": [],
    "toolResults": [],
    "reasoning": [reasoning],
    "reply": [response],
  };
  void addCalls(List<ToolCall> calls) {
    for (final call in calls) {
      fragments["toolCalls"]!.add(
        jsonEncode({
          "id": call.id,
          "name": call.name,
          "arguments": call.arguments,
        }),
      );
    }
  }

  for (final message in request.messages) {
    final key = switch (message.role) {
      AiRole.user => "user",
      AiRole.assistant => "reply",
      AiRole.tool => "toolResults",
    };
    fragments[key]!.add(message.text);
    if (message.reasoningContent != null) {
      fragments["reasoning"]!.add(message.reasoningContent!);
    }
    addCalls(message.calls);
  }
  addCalls(calls);
  return _countFragments(encoding, fragments);
}

Future<int?> countPromptTokens({
  required String provider,
  required String model,
  required String endpoint,
  required String text,
}) async {
  final encoding = ModelTokenizer.encodingFor(
    provider,
    model,
    endpoint: endpoint,
  );
  if (encoding == null || RootIsolateToken.instance == null) return null;
  final result = jsonDecode(
    await _countFragments(encoding, {
      "prompt": [text],
    }),
  ) as Map<String, dynamic>;
  return (result["counts"] as Map<String, dynamic>)["prompt"] as int;
}

Future<String> _countFragments(
  String encoding,
  Map<String, List<String>> fragments,
) async {
  final worker = await (_worker ??= _startWorker());
  await _loaded.putIfAbsent(encoding, () async {
    final asset = await rootBundle.loadString(
      ModelTokenizer.assetFor(encoding),
      cache: false,
    );
    await _ask(worker, encoding, asset);
  });
  return await _ask(worker, encoding, fragments) as String;
}

// Keep one parsed vocabulary per encoding off the UI isolate. Chat often
// emits several requests in one turn, so reparsing it per round is costly.
Future<SendPort>? _worker;
final _loaded = <String, Future<void>>{};

Future<SendPort> _startWorker() async {
  final ready = ReceivePort();
  try {
    await Isolate.spawn(_serve, ready.sendPort, debugName: "text-tokenizer");
    return await ready.first as SendPort;
  } finally {
    ready.close();
  }
}

Future<Object?> _ask(SendPort worker, String encoding, Object data) async {
  final result = ReceivePort();
  try {
    worker.send((encoding, data, result.sendPort));
    final value = await result.first;
    if (value == false) throw StateError("Local tokenization failed");
    return value;
  } finally {
    result.close();
  }
}

void _serve(SendPort parent) {
  final requests = ReceivePort();
  final models = <String, ModelTokenizer>{};
  parent.send(requests.sendPort);
  requests.listen((message) {
    final (encoding, data, reply) = message as (String, Object, SendPort);
    try {
      if (data is String) {
        models[encoding] = ModelTokenizer.fromAsset(encoding, data);
        reply.send(null);
      } else {
        final tokenizer = models[encoding]!;
        final fragments = data as Map<String, List<String>>;
        reply.send(
          jsonEncode({
            "encoding": encoding,
            "counts": fragments.map(
              (key, value) => MapEntry(
                key,
                value.fold<int>(0, (sum, text) => sum + tokenizer.count(text)),
              ),
            ),
          }),
        );
      }
    } catch (_) {
      reply.send(false);
    }
  });
}
