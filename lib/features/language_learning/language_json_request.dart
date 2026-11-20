import "dart:convert";

import "package:dio/dio.dart";
import "package:uuid/uuid.dart";

import "../../core/ai/ai_usage_store.dart";
import "../../core/ai/chat_provider.dart";
import "../../core/database/database.dart";
import "language_stream.dart";

Object? decodeLanguageJson(String raw) {
  final trimmed = raw.trim();
  final fence = RegExp(
    r"^\x60\x60\x60(?:json)?\s*([\s\S]+?)\s*\x60\x60\x60$",
    caseSensitive: false,
  ).firstMatch(trimmed);
  return jsonDecode(fence?.group(1) ?? trimmed);
}

/// Run one bounded direct request. The feature owns schema validation and storage.
Future<T> requestLanguageJson<T>({
  required ChatProvider provider,
  required ProviderConfig config,
  required AiUsageStore? usageStore,
  required String feature,
  required AiRequest request,
  required CancelToken cancel,
  required T Function(Object?) parse,
  int maxChars = 28000,
  String cancelledStatus = "cancelled",
  bool captureLocalBreakdown = true,
}) async {
  cancel.checkCancelled();
  final started = DateTime.now();
  final body = StringBuffer(), reasoning = StringBuffer();
  var complete = false;
  var breakdownComplete = captureLocalBreakdown;
  var status = "error";
  AiTokenUsage? usage;
  try {
    await for (final chunk in boundedLanguageStream(
      (transport) => provider.start(config).complete(request, transport),
      cancel,
    )) {
      cancel.checkCancelled();
      usage = chunk.usage ?? usage;
      if (chunk.calls.isNotEmpty ||
          (complete && (chunk.text.isNotEmpty || chunk.reasoning.isNotEmpty)) ||
          body.length + chunk.text.length > maxChars) {
        throw const FormatException("Invalid language generation reply");
      }
      complete |= chunk.completed;
      body.write(chunk.text);
      breakdownComplete &= reasoning.length + chunk.reasoning.length <= 32000;
      if (breakdownComplete) reasoning.write(chunk.reasoning);
    }
    cancel.checkCancelled();
    if (!complete) {
      status = "incomplete";
      throw const FormatException("Language generation reply was interrupted");
    }
    final value = parse(decodeLanguageJson(body.toString()));
    status = "complete";
    return value;
  } on DioException catch (error) {
    if (CancelToken.isCancel(error)) status = "cancelled";
    rethrow;
  } finally {
    if (usageStore != null && provider is! MockChatProvider) {
      try {
        await usageStore.record(
          AiUsageCapture(
            actionId: const Uuid().v4(),
            providerKind: config.kind,
            endpoint: config.baseUrl,
            model: config.model,
            feature: feature,
            status: cancel.isCancelled ? cancelledStatus : status,
            occurredAt: started,
            durationMs: DateTime.now().difference(started).inMilliseconds,
            usage: usage,
          ),
          request: breakdownComplete ? request : null,
          response: body.toString(),
          reasoning: reasoning.toString(),
        );
      } catch (_) {
        // Usage accounting must not block a validated result.
      }
    }
  }
}
