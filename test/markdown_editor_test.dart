import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/ui/markdown_editor.dart";
import "package:val_highlight_flutter/val_highlight_flutter.dart";
import "package:val_latex_flutter/val_latex_flutter.dart";

void main() {
  testWidgets(
    "math, physics and chemistry templates render with the current math engine",
    (tester) async {
      final errors = <String>[];
      const expressions = [
        r"\frac{a}{b}",
        r"\sqrt{x}",
        r"x^{x}",
        r"x_{x}",
        r"\int_{a}^{b} x\,dx",
        r"\sum_{i=1}^{n} x",
        r"\begin{pmatrix}x & b \\ c & d\end{pmatrix}",
        r"\alpha",
        r"F = ma",
        r"\vec{x}",
        r"v\,\mathrm{m/s}",
        r"\mathrm{H_2O}",
        r"2\mathrm{H_2} + \mathrm{O_2} \rightarrow 2\mathrm{H_2O}",
        r"\ce{2H2 + O2 -> 2H2O}",
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (final expression in expressions)
                    Math.tex(
                      expression,
                      onError: (_, _) {
                        errors.add(expression);
                        return const SizedBox();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(errors, isEmpty);
    },
  );

  testWidgets(
    "fullscreen editing preserves selection, formats and previews before applying",
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = TextEditingController(text: "important");
      addTearDown(controller.dispose);
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 9,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownFullscreenButton(controller: controller, title: "正文"),
          ),
        ),
      );
      await tester.tap(find.byTooltip("全屏编辑 Markdown"));
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownEditor), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key("markdown-source")))
            .controller,
        isA<HighlightTextController>(),
      );
      await tester.tap(find.byTooltip("粗体"));
      await tester.pumpAndSettle();
      final editor = tester
          .widget<TextField>(find.byKey(const Key("markdown-source")))
          .controller!;
      expect(editor.text, "**important**");
      expect(controller.text, "important");
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byTooltip("撤销"));
      await tester.pumpAndSettle();
      expect(editor.text, "important");
      await tester.tap(find.byTooltip("重做"));
      await tester.pumpAndSettle();
      expect(editor.text, "**important**");
      await tester.tap(find.text("预览"));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("markdown-preview")), findsOneWidget);
      await tester.tap(find.byKey(const Key("markdown-done")));
      await tester.pumpAndSettle();
      expect(controller.text, "**important**");
    },
  );

  testWidgets("desktop shortcuts format, indent and open search", (
    tester,
  ) async {
    final controller = TextEditingController(text: "word");
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownFullscreenButton(controller: controller, title: "正文"),
        ),
      ),
    );
    await tester.tap(find.byTooltip("全屏编辑 Markdown"));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key("markdown-source"));
    await tester.tap(field);
    final editor = tester.widget<TextField>(field).controller!;
    editor.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(editor.text, "**word**");
    editor.selection = TextSelection.collapsed(offset: editor.text.length);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(editor.text, "**word**  ");
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("markdown-find")), findsOneWidget);
  });

  testWidgets("cancel confirms before discarding the full-screen draft", (
    tester,
  ) async {
    final controller = TextEditingController(text: "original");
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownFullscreenButton(controller: controller, title: "正文"),
        ),
      ),
    );
    await tester.tap(find.byTooltip("全屏编辑 Markdown"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("markdown-source")), "changed");
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text("放弃编辑？"), findsOneWidget);
    await tester.tap(find.text("继续编辑"));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key("markdown-source")))
          .controller!
          .text,
      "changed",
    );
    await tester.tap(find.byTooltip("取消"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("放弃修改"));
    await tester.pumpAndSettle();
    expect(controller.text, "original");
  });

  testWidgets(
    "find and replace works and formula templates insert editable LaTeX",
    (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(text: "alpha alpha");
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownFullscreenButton(controller: controller, title: "正文"),
          ),
        ),
      );
      await tester.tap(find.byTooltip("全屏编辑 Markdown"));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("查找和替换"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key("markdown-find")), "alpha");
      await tester.enterText(
        find.byKey(const Key("markdown-replace-text")),
        "beta",
      );
      await tester.tap(find.text("全部替换"));
      await tester.pumpAndSettle();
      final editor = tester
          .widget<TextField>(find.byKey(const Key("markdown-source")))
          .controller!;
      expect(editor.text, "beta beta");
      await tester.tap(find.byTooltip("关闭查找"));
      await tester.pumpAndSettle();
      editor.selection = TextSelection.collapsed(offset: editor.text.length);
      await tester.ensureVisible(find.byTooltip("插入公式"));
      await tester.tap(find.byTooltip("插入公式"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("分数"));
      await tester.pumpAndSettle();
      expect(editor.text, contains(r"\(\frac{a}{b}\)"));
      editor.selection = TextSelection.collapsed(offset: editor.text.length);
      await tester.ensureVisible(find.byTooltip("表格"));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("表格"));
      await tester.pumpAndSettle();
      expect(editor.text, contains("| A | B |\n| --- | --- |"));
      await tester.tap(find.text("预览"));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("markdown-preview")), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key("markdown-done")));
      await tester.pumpAndSettle();
      expect(controller.text, contains(r"\(\frac{a}{b}\)"));
    },
  );
}
