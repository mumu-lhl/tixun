import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/ai/model_tokenizer.dart";
import "package:tixun/core/ai/token_breakdown.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    "model tokenizers match official reference IDs across multilingual text",
    () async {
      final cases = jsonDecode(
        File("test/fixtures/tokenizer_reference.json").readAsStringSync(),
      ) as List;
      for (final name in ["deepseek_v4", "cl100k_base", "o200k_base"]) {
        final tokenizer = await ModelTokenizer.load(name);
        for (final row in cases) {
          expect(
            tokenizer.encode(row["text"] as String),
            (row[name] as List).cast<int>(),
            reason: '$name: ${row['text']}',
          );
        }
      }
    },
  );
  test("prompt counts use model vocabulary and leave unknown providers unsupported", () async {
    final row = (jsonDecode(
      File("test/fixtures/tokenizer_reference.json").readAsStringSync(),
    ) as List).first;
    expect(
      await countPromptTokens(
        provider: "deepseek",
        model: "deepseek-flash",
        endpoint: "https://api.deepseek.com",
        text: row["text"] as String,
      ),
      (row["deepseek_v4"] as List).length,
    );
    expect(
      await countPromptTokens(
        provider: "compatible",
        model: "unknown",
        endpoint: "https://example.org",
        text: "hello",
      ),
      isNull,
    );
  });
  test("only known models select their matching tokenizer", () {
    expect(
      ModelTokenizer.encodingFor("deepseek", "deepseek-v4-pro"),
      "deepseek_v4",
    );
    expect(ModelTokenizer.encodingFor("chatgpt", "gpt-5.1"), "o200k_base");
    expect(ModelTokenizer.encodingFor("chatgpt", "gpt-6"), "o200k_base");
    expect(ModelTokenizer.encodingFor("chatgpt", "gpt-6.1-sol"), "o200k_base");
    expect(ModelTokenizer.encodingFor("openai", "gpt-6.2-sol"), "o200k_base");
    expect(ModelTokenizer.encodingFor("chatgpt", "gpt-60"), isNull);
    expect(ModelTokenizer.encodingFor("chatgpt", "gpt-4-0613"), "cl100k_base");
    expect(
      ModelTokenizer.encodingFor(
        "compatible",
        "gpt-4o-mini",
        endpoint: "https://api.openai.com/v1",
      ),
      "o200k_base",
    );
    expect(
      ModelTokenizer.encodingFor(
        "compatible",
        "gpt-4o-mini",
        endpoint: "https://example.org/v1",
      ),
      isNull,
    );
    expect(ModelTokenizer.encodingFor("deepseek", "deepseek-chat"), isNull);
  });
}
