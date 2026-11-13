/// Provider-reported token counts for one model request. Cached input is a
/// subset of [inputTokens], and reasoning is a subset of [outputTokens].
class AiTokenUsage {
  const AiTokenUsage({
    this.inputTokens,
    this.cachedInputTokens,
    this.outputTokens,
    this.reasoningTokens,
    this.reportedTotalTokens,
  });

  final int? inputTokens;
  final int? cachedInputTokens;
  final int? outputTokens;
  final int? reasoningTokens;
  final int? reportedTotalTokens;

  int? get totalTokens =>
      reportedTotalTokens ??
      (inputTokens != null && outputTokens != null
          ? inputTokens! + outputTokens!
          : null);
}

/// Normalizes OpenAI Chat Completions and compatible usage payloads.
AiTokenUsage parseChatCompletionsUsage(Map usage) {
  final promptDetails = usage['prompt_tokens_details'];
  final completionDetails = usage['completion_tokens_details'];
  return AiTokenUsage(
    inputTokens: _nonNegativeInt(usage['prompt_tokens']),
    cachedInputTokens: _firstNonNegativeInt([
      promptDetails is Map ? promptDetails['cached_tokens'] : null,
      usage['prompt_cache_hit_tokens'],
      usage['cache_read_input_tokens'],
    ]),
    outputTokens: _nonNegativeInt(usage['completion_tokens']),
    reasoningTokens: _firstNonNegativeInt([
      completionDetails is Map ? completionDetails['reasoning_tokens'] : null,
      usage['reasoning_tokens'],
    ]),
    reportedTotalTokens: _nonNegativeInt(usage['total_tokens']),
  );
}

/// Normalizes OpenAI Responses API usage payloads.
AiTokenUsage parseResponsesUsage(Map usage) {
  final inputDetails = usage['input_tokens_details'];
  final outputDetails = usage['output_tokens_details'];
  return AiTokenUsage(
    inputTokens: _nonNegativeInt(usage['input_tokens']),
    cachedInputTokens: _firstNonNegativeInt([
      inputDetails is Map ? inputDetails['cached_tokens'] : null,
    ]),
    outputTokens: _nonNegativeInt(usage['output_tokens']),
    reasoningTokens: _firstNonNegativeInt([
      outputDetails is Map ? outputDetails['reasoning_tokens'] : null,
    ]),
    reportedTotalTokens: _nonNegativeInt(usage['total_tokens']),
  );
}

int? _firstNonNegativeInt(Iterable<Object?> values) {
  for (final value in values) {
    final parsed = _nonNegativeInt(value);
    if (parsed != null) return parsed;
  }
  return null;
}

int? _nonNegativeInt(Object? value) =>
    value is int && value >= 0 ? value : null;
