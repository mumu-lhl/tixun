import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/theme.dart';
import 'package:tixun/core/ui/learning_markdown.dart';

void main() {
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
    const content = r'价格是 $5 and $10，总计 $15。点 $(2,-1)$ 与 $x$、$x^2$、$-1$、$0$、$3.14$。';
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
