import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/ai_usage.dart';

void main() {
  test('normalizes OpenAI-compatible input, cache and output usage', () {
    final usage = parseChatCompletionsUsage({
      'prompt_tokens': 120,
      'completion_tokens': 30,
      'total_tokens': 150,
      'prompt_tokens_details': {'cached_tokens': 60},
      'completion_tokens_details': {'reasoning_tokens': 5},
    });

    expect(usage.inputTokens, 120);
    expect(usage.cachedInputTokens, 60);
    expect(usage.outputTokens, 30);
    expect(usage.reasoningTokens, 5);
    expect(usage.totalTokens, 150);
  });

  test('normalizes DeepSeek cache fields without double-counting input', () {
    final usage = parseChatCompletionsUsage({
      'prompt_tokens': 120,
      'completion_tokens': 30,
      'total_tokens': 150,
      'prompt_cache_hit_tokens': 60,
      'prompt_cache_miss_tokens': 60,
    });

    expect(usage.inputTokens, 120);
    expect(usage.cachedInputTokens, 60);
    expect(usage.totalTokens, 150);
  });

  test('normalizes Responses API usage and tolerates absent detail fields', () {
    final usage = parseResponsesUsage({
      'input_tokens': 80,
      'output_tokens': 22,
      'total_tokens': 102,
      'input_tokens_details': {'cached_tokens': 20},
      'output_tokens_details': {'reasoning_tokens': 7},
    });

    expect(usage.inputTokens, 80);
    expect(usage.cachedInputTokens, 20);
    expect(usage.outputTokens, 22);
    expect(usage.reasoningTokens, 7);
    expect(parseResponsesUsage({'total_tokens': 9}).totalTokens, 9);
  });
}
