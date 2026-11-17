import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/bidi_rich_text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/ui/learning_markdown.dart';

void main() {
  testWidgets(
    'streaming reveals new text and completed messages appear immediately',
    (tester) async {
      const full = 'Begin 12345678901234567890';
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
      await tester.pumpWidget(app('Begin', true));
      await tester.pumpWidget(app(full, true));
      expect(visible(), 'Begin');
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
}
