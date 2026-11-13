import 'package:dio/dio.dart';

import '../database/database.dart';
import '../l10n/app_error.dart';

class AiFailure implements Exception, LocalizedAppFailure {
  const AiFailure(this.message) : code = null, arguments = const [];
  const AiFailure.localized(
    this.code,
    this.message, [
    this.arguments = const [],
  ]);
  AiFailure.fromFormatException(FormatException error)
    : message = error.message,
      code = error is LocalizedAppFailure
          ? (error as LocalizedAppFailure).code
          : null,
      arguments = error is LocalizedAppFailure
          ? (error as LocalizedAppFailure).arguments
          : const [];
  @override
  final AppErrorCode? code;
  @override
  final String message;
  @override
  final List<String> arguments;
  @override
  String toString() => message;
}

class ToolCall {
  const ToolCall(this.id, this.name, this.arguments);
  final String id, name, arguments;
}

class AiTool {
  const AiTool({
    required this.name,
    required this.description,
    required this.parameters,
  });
  final String name, description;
  final Map<String, dynamic> parameters;
}

enum AiRole { user, assistant, tool }

class AiImage {
  const AiImage(this.dataUrl);
  final String dataUrl;
}

class AiMessage {
  const AiMessage.user(
    this.text, {
    this.images = const [],
    this.reasoningContent,
  }) : role = AiRole.user,
       calls = const [],
       callId = null;
  const AiMessage.assistant(
    this.text, {
    this.calls = const [],
    this.reasoningContent,
  }) : role = AiRole.assistant,
       images = const [],
       callId = null;
  const AiMessage.tool(String this.callId, this.text, {this.reasoningContent})
    : role = AiRole.tool,
      images = const [],
      calls = const [];
  final AiRole role;
  final String text;
  final List<AiImage> images;
  final List<ToolCall> calls;
  final String? callId;

  /// The model's reasoning for this turn, when the provider returned one.
  /// Passed back verbatim on later requests that carry tools.
  final String? reasoningContent;
  AiMessage withText(String value) => switch (role) {
    AiRole.user => AiMessage.user(
      value,
      images: images,
      reasoningContent: reasoningContent,
    ),
    AiRole.assistant => AiMessage.assistant(
      value,
      calls: calls,
      reasoningContent: reasoningContent,
    ),
    AiRole.tool => AiMessage.tool(
      callId!,
      value,
      reasoningContent: reasoningContent,
    ),
  };
}

/// Protocol-neutral input. Provider-specific state belongs to AiConversation.
class AiRequest {
  AiRequest({
    required this.instructions,
    required List<AiMessage> messages,
    List<AiTool> tools = const [],
    this.maxOutputTokens,
  }) : messages = List.unmodifiable(messages),
       tools = List.unmodifiable(tools);
  final String instructions;
  final List<AiMessage> messages;
  final List<AiTool> tools;

  /// Null means no app-side cap: the provider's own model limit decides.
  final int? maxOutputTokens;
  AiRequest copyWith({
    String? instructions,
    List<AiMessage>? messages,
    List<AiTool>? tools,
    int? maxOutputTokens,
  }) => AiRequest(
    instructions: instructions ?? this.instructions,
    messages: messages ?? this.messages,
    tools: tools ?? this.tools,
    maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
  );
}

/// Tool calls are complete and validated, never vendor-specific delta fragments.
/// A completed event is required before callers may execute any tool call.
class AiChunk {
  const AiChunk({
    this.text = '',
    this.reasoning = '',
    this.tokens,
    this.completed = false,
    this.calls = const [],
  });
  final String text;

  /// Reasoning delta for this event, if the provider streams one.
  final String reasoning;

  /// Cumulative usage for this turn; later events replace earlier estimates.
  final int? tokens;
  final bool completed;
  final List<ToolCall> calls;
}

abstract interface class ChatProvider {
  /// One instance per learning request, including its bounded tool rounds.
  /// The override is for testing an unsaved API-key form, never OAuth inference.
  AiConversation start(ProviderConfig config, {String? apiKeyOverride});
}

class AiConversation {
  AiConversation(this._complete);
  final Stream<AiChunk> Function(AiRequest, CancelToken) _complete;
  Stream<AiChunk> complete(AiRequest request, CancelToken cancel) =>
      _complete(request, cancel);
}

extension CancelGuard on CancelToken {
  void checkCancelled() {
    if (isCancelled) throw cancelError!;
  }
}

void validateToolCalls(List<ToolCall> calls) {
  final ids = <String>{};
  if (calls.length > 8) {
    throw const AiFailure.localized(
      AppErrorCode.errorAtMost8ToolCallsAre,
      '一次最多允许 8 个工具调用。',
    );
  }
  for (final c in calls) {
    if (c.id.isEmpty || c.name.isEmpty || !ids.add(c.id)) {
      throw const AiFailure.localized(
        AppErrorCode.errorToolCallsAreIncompleteOrHave,
        '工具调用不完整或 ID 重复。',
      );
    }
    if (c.arguments.length > 64000 ||
        c.name.length > 100 ||
        c.id.length > 200) {
      throw const AiFailure.localized(
        AppErrorCode.errorToolCallDataIsTooLong,
        '工具调用数据过长。',
      );
    }
  }
}
