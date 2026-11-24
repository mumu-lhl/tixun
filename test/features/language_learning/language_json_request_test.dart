import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/features/language_learning/language_json_request.dart";

class _Reply implements ChatProvider {
  _Reply(this.chunks);
  final List<AiChunk> chunks;
  AiRequest? sent;
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        sent = request;
        yield* Stream.fromIterable(chunks);
      });
}

void main() {
  late AppDatabase db;
  late ProviderConfig config;
  setUp(() async {
    db = AppDatabase.memory();
    config = await db.config();
  });
  tearDown(() => db.close());

  Future<Object?> generate(_Reply provider, {String format = "json"}) =>
      requestLanguageText(
        provider: provider,
        config: config,
        usageStore: null,
        feature: "test",
        request: AiRequest(instructions: "Task", messages: []),
        cancel: CancelToken(),
        outputFormat: format,
        parse: (raw) => format == "json" ? decodeLanguageJson(raw) : raw,
      );

  test(
    "JSON tasks request compact output without altering string values",
    () async {
      final provider = _Reply([
        const AiChunk(
          text: '{"text":"two words\\nnext line"}',
          completed: true,
        ),
      ]);
      expect(await generate(provider), {"text": "two words\nnext line"});
      expect(provider.sent!.outputFormat, AiOutputFormat.jsonObject);
      expect(provider.sent!.instructions, contains("compact"));
      final text = _Reply([
        const AiChunk(text: "# Explanation", completed: true),
      ]);
      expect(await generate(text, format: "markdown"), "# Explanation");
      expect(text.sent!.outputFormat, AiOutputFormat.text);
      expect(text.sent!.instructions, "Task");
    },
  );

  test(
    "stop with whitespace fails rather than accepting an empty result",
    () async {
      await expectLater(
        generate(_Reply([const AiChunk(text: "  \n ", completed: true)])),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            "message",
            "Empty JSON generation reply",
          ),
        ),
      );
    },
  );

  test("invalid or incomplete JSON cannot be accepted", () async {
    for (final chunks in [
      [const AiChunk(text: '{"text":', completed: true)],
      [const AiChunk(text: '{"text":"valid but interrupted"}')],
    ]) {
      await expectLater(generate(_Reply(chunks)), throwsFormatException);
    }
  });
}
