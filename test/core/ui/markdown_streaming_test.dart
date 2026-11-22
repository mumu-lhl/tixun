import "package:flutter_test/flutter_test.dart";
import "package:gpt_markdown/custom_widgets/bidi_rich_text.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/ui/learning_markdown.dart";

void main() {
  testWidgets(
    "streaming reveals new text and completed messages appear immediately",
    (tester) async {
      const full = "Begin 12345678901234567890";
      Widget app(String text, bool streaming) => MaterialApp(
        home: Scaffold(body: LearningMarkdown(text, streaming: streaming)),
      );
      String visible() => [
        ...tester
            .widgetList<RichText>(find.byType(RichText))
            .map((w) => w.text.toPlainText()),
        ...tester
            .widgetList<BidiText>(find.byType(BidiText))
            .map((w) => w.textSpan.toPlainText()),
      ].join();
      await tester.pumpWidget(app("Begin", true));
      await tester.pumpWidget(app(full, true));
      expect(visible(), "Begin");
      await tester.pump(const Duration(milliseconds: 150));
      expect(visible().length, greaterThan(5));
      expect(visible().length, lessThan(full.length));
      await tester.pumpWidget(app(full, false));
      await tester.pumpAndSettle();
      expect(visible(), full);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app(full, false));
      expect(visible(), full);
    },
  );
  testWidgets(
    "Chinese streaming text has a brief visible entrance and respects reduced motion",
    (tester) async {
      const initial = "正在";
      const full = "正在逐字解释二次函数的顶点和配方过程以及如何检查答案是否正确。";
      Widget app(String text, {bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(body: LearningMarkdown(text, streaming: true)),
        ),
      );
      await tester.pumpWidget(app(initial));
      await tester.pumpWidget(app(full));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 35));
      final spans = <InlineSpan>[
        ...tester
            .widgetList<RichText>(find.byType(RichText))
            .map((w) => w.text),
        ...tester
            .widgetList<BidiText>(find.byType(BidiText))
            .map((w) => w.textSpan),
      ];
      var partiallyVisible = false;
      for (final root in spans) {
        root.visitChildren((span) {
          if (span is TextSpan && span.text != null && span.text!.isNotEmpty) {
            final alpha = span.style?.color?.a;
            if (alpha != null && alpha > 0 && alpha < 1) {
              partiallyVisible = true;
            }
          }
          return true;
        });
      }
      expect(partiallyVisible, isTrue);
      await tester.pumpWidget(app(full, reduced: true));
      await tester.pumpAndSettle();
      final visible = [
        ...tester
            .widgetList<RichText>(find.byType(RichText))
            .map((w) => w.text.toPlainText()),
        ...tester
            .widgetList<BidiText>(find.byType(BidiText))
            .map((w) => w.textSpan.toPlainText()),
      ].join();
      expect(visible, full);
    },
  );
}
