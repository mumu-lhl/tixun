import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/theme.dart';
import 'package:tixun/core/ui/learning_markdown.dart';

void main() {
  testWidgets(
    'Wide tables keep long cells readable and scroll to the last column',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final explanation = '这里需要解释公式的适用条件与推导步骤，避免把长段文字挤成一条很细的竖列。' * 5;
      final content =
          '| 考点 | 公式 | 条件 | 详细解释 | 例子 | 补充 |\n| --- | --- | --- | --- | --- | --- |\n| 顶点 | x² | a≠0 | $explanation | 配方 | 最后一列的完整内容 |';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: LearningMarkdown(content)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paragraph = find.textContaining(explanation, findRichText: true);
      expect(tester.getSize(paragraph).width, greaterThan(140));
      final horizontal = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      expect(horizontal, findsOneWidget);
      await tester.dragFrom(const Offset(180, 25), const Offset(-1500, 0));
      await tester.pumpAndSettle();
      final last = find.text('最后一列的完整内容', findRichText: true);
      expect(tester.getCenter(last).dx, inInclusiveRange(0, 390));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Inline code renders as a chip; fenced blocks keep block rendering',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const content = 'Use `foo()` here.\n\n```dart\nint x = 1;\n```\n';
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: LearningMarkdown(content)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final surfaceContainer = appTheme(Brightness.light)
          .colorScheme
          .surfaceContainer;
      var inlineChip = false;
      var fencedBlock = false;
      for (final container in tester.widgetList<Container>(
        find.byType(Container),
      )) {
        final decoration = container.decoration;
        if (decoration is! BoxDecoration) continue;
        if (decoration.color != surfaceContainer) continue;
        if (decoration.borderRadius == BorderRadius.circular(6)) {
          inlineChip = true;
        }
        if (decoration.borderRadius == BorderRadius.circular(10)) {
          fencedBlock = true;
        }
      }
      expect(inlineChip, isTrue, reason: 'inline code chip missing');
      expect(fencedBlock, isTrue, reason: 'fenced block decoration missing');
      expect(find.text('foo()'), findsOneWidget);
      expect(find.text('int x = 1;'), findsOneWidget);
    },
  );

  testWidgets('Dollar amounts stay literal text, formulas still render', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const content =
        r'价格是 $5 and $10，总计 $15。点 $(2,-1)$ 与 $x$、$x^2$、$-1$、$0$、$3.14$。';
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: LearningMarkdown(content)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The amounts survive with their `$` signs instead of being parsed
    // as a formula and dropped by the fallback.
    expect(find.textContaining('\$5'), findsWidgets);
    expect(find.textContaining('\$10'), findsWidgets);
    // Formulas and explicitly delimited numbers render as math, not currency.
    expect(
      find.byWidgetPredicate((w) => w is Tooltip && w.message == '长按复制 LaTeX'),
      findsNWidgets(6),
    );
  });

  testWidgets('Formula tooltip goes through localization', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const content = r'行内 $x^2$ 公式。';
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: LearningMarkdown(content)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate((w) => w is Tooltip && w.message == '长按复制 LaTeX'),
      findsOneWidget,
    );
  });
}
