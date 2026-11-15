import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/app/theme.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';
import 'package:tixun/features/practice/question_card.dart';

import 'support/gui_capture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('exam figures and fullscreen share one persistent attempt', (
    tester,
  ) async {
    final c = await AppController.open(demo: true);
    await c.setAiDrawingEnabled(true);
    await c.newSession();
    await c.mode('exam');
    await c.send('请出一道带图拖点考试题');
    expect(c.messages.last.status, 'complete');
    final q = (await c.practice.list(messageId: c.messages.last.id)).single;
    expect(await c.visual.listByMessage(c.messages.last.id), isEmpty);
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: QuestionCard(q.id),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await resizeGui(tester, 430, 900);
    expect(find.text('提交后解析图'), findsNothing);
    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();
    expect(find.text('提交后解析图'), findsNothing);
    expect(find.byKey(const Key('visual-play-pause')), findsNothing);
    expect(find.byType(Slider), findsNothing);
    await guiCapture('assessment', 'fullscreen-question-phone');

    final paintFinder = find.byKey(const Key('visual-canvas-paint')).last;
    final paint =
        tester.widget<CustomPaint>(paintFinder).painter! as VisualPainter;
    final box = tester.renderObject<RenderBox>(paintFinder);
    final mapper = VisualCoordinateMapper.fromScene(paint.scene, box.size);
    final start = box.localToGlobal(
      mapper.modelToCanvas(const ui.Offset(0, 0)),
    );
    final end = box.localToGlobal(mapper.modelToCanvas(const ui.Offset(2, 0)));
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('visual-return-to-answer')));
    await tester.pumpAndSettle();
    expect(find.textContaining('已选点：'), findsOneWidget);
    final moved =
        (tester
                    .widget<CustomPaint>(
                      find.byKey(const Key('visual-canvas-paint')),
                    )
                    .painter!
                as VisualPainter)
            .pointOverrides['p'];
    expect(moved!.dx, closeTo(2, .05));
    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('submit-quiz')));
    await tester.tap(find.byKey(const Key('submit-quiz')));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      if (find.textContaining('参考答案：').evaluate().isNotEmpty) break;
    }
    await tester.pumpAndSettle();
    final detail = await c.practice.detail(q.id);
    expect(detail.attempts, hasLength(1));
    expect(detail.latest!.correct, true);
    expect(find.text('提交后解析图'), findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(find.text('提交后解析图')),
      alignment: .1,
    );
    await tester.pumpAndSettle();
    await guiCapture('assessment', 'solution-after-submit-phone');
    await tester.tap(find.byKey(const Key('visual-return-to-answer')));
    await tester.pumpAndSettle();
    await resizeGui(tester, 1280, 900);
    await tester.ensureVisible(find.text('再做一次'));
    await tester.tap(find.text('再做一次'));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      if (find.byKey(const Key('submit-quiz')).evaluate().isNotEmpty) break;
    }
    await tester.pumpAndSettle();
    expect(find.text('提交后解析图'), findsNothing);
    await tester.ensureVisible(find.byIcon(Icons.open_in_full));
    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();
    expect(find.text('提交后解析图'), findsNothing);
    await guiCapture('assessment', 'fullscreen-retry-desktop');
    await tester.tap(find.byKey(const Key('visual-return-to-answer')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await c.shutdown();
  });
}
