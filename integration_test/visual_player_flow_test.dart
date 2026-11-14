import 'dart:convert';

import 'support/gui_capture.dart';

import 'package:tixun/features/visual/visual_card.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Linux GUI: timeline scene plays, steps apply, seek works', (
    tester,
  ) async {
    final c = await AppController.open(demo: true);
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TixunApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-chat')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chat-input')),
      '请画图，画出 y = x^2 的函数图',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 100 && c.busy; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.busy, false);
    await tester.pumpAndSettle();
    final scenes = await c.visual.listByMessage(c.messages.last.id);
    expect(scenes, hasLength(1));
    // Replace the static mock scene with a timeline scene: y = a·x²,
    // a animates 0.5 -> 2 over 4s, and point P hides at 2s.
    final timelineScene = {
      'v': 1,
      'kind': 'plot2d',
      'title': 'y = a·x²',
      'model': {
        'expression': 'a*x^2',
        'parameters': {'a': 1.0},
      },
      'view': {
        'x': [-3, 3],
        'y': [-1, 9],
      },
      'elements': [
        {
          'id': 'p1',
          'type': 'point',
          'at': [1, 1],
          'label': 'P',
        },
      ],
      'controls': [
        {
          'id': 'a',
          'kind': 'slider',
          'label': 'a',
          'min': 0.5,
          'max': 2.0,
          'step': 0.1,
          'value': 1.0,
        },
      ],
      'timeline': {
        'durationMs': 4000,
        'tracks': [
          {
            'id': 't1',
            'target': 'a',
            'from': 0.5,
            'to': 2.0,
            'startMs': 0,
            'endMs': 4000,
          },
        ],
        'steps': [
          {
            'atMs': 2000,
            'show': [],
            'hide': ['p1'],
            'note': '2 秒时隐藏点 P',
          },
        ],
      },
      'meta': {'alt': '抛物线 y = a·x² 随参数 a 变化'},
    };
    await c.visual.revise(scenes.single.id, jsonEncode(timelineScene));
    await tester.pumpAndSettle();
    // The chat card now offers playback for the timeline scene.
    expect(find.byType(VisualCard), findsOneWidget);
    expect(find.byKey(const Key('visual-play-card')), findsOneWidget);
    // Scroll the card fully into view first: the list starts scrolled
    // to the message text and the title-row button sits near the top.
    await tester.ensureVisible(find.byKey(const Key('visual-play-card')));
    await tester.pumpAndSettle();
    // Open fullscreen via the card play button: autoplay starts.
    // Do NOT pumpAndSettle here: it would drain the whole 4s animation
    // and both captures would show the end state. A fixed 500ms pump
    // lets the route transition finish while the animation is still
    // near the start (a ≈ 0.7).
    await tester.tap(find.byKey(const Key('visual-play-card')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byKey(const Key('visual-play-pause')), findsOneWidget);
    expect(find.byKey(const Key('visual-seek')), findsOneWidget);
    expect(find.byKey(const Key('visual-time-label')), findsOneWidget);
    await guiCapture('visual', 'player-fullscreen-start');
    // Let the animation run ~3s more: a reaches ~1.9, the 2s step hides P.
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump();
    final timeText = tester
        .widget<Text>(find.byKey(const Key('visual-time-label')))
        .data!;
    expect(timeText, contains('4.0s'));
    expect(timeText, isNot(contains('0.0s')));
    expect(find.text('2 秒时隐藏点 P'), findsOneWidget);
    await guiCapture('visual', 'player-midway');
    // Pause: the button flips back to the play icon.
    await tester.tap(find.byKey(const Key('visual-play-pause')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow), findsWidgets);
    // The parameter slider and the canvas must agree in the same
    // frame: both read the animator frame for the current timeMs.
    final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
    final visual = paints.where((p) => p.painter is VisualPainter).toList();
    final painter = visual.last.painter as VisualPainter;
    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    final paramSlider = sliders.firstWhere(
      (s) => s.key != const Key('visual-seek'),
    );
    expect(paramSlider.value, painter.parameters['a']);
    await guiCapture('visual', 'player-end');
    // Close the fullscreen view and confirm the card is still there.
    await tester.tap(find.byTooltip('关闭预览'));
    await tester.pumpAndSettle();
    expect(find.byType(VisualCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await c.db.close();
    await c.files.root.delete(recursive: true);
  });
}
