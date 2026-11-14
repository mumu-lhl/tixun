import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';

Map<String, dynamic> _triangle({
  Map<String, dynamic>? meta,
  List<Map<String, dynamic>>? constraints,
}) => {
  'v': 1,
  'kind': 'geometry',
  'title': '直角三角形',
  'view': {
    'x': [-1, 5],
    'y': [-1, 5],
  },
  'elements': [
    {
      'id': 'A',
      'type': 'point',
      'at': [0, 0],
      'label': 'A',
    },
    {
      'id': 'B',
      'type': 'point',
      'at': [3, 0],
      'label': 'B',
    },
    {
      'id': 'C',
      'type': 'point',
      'at': [0, 4],
      'label': 'C',
    },
    {
      'id': 'M',
      'type': 'point',
      'at': [1.5, 2],
      'label': 'M',
    },
    {
      'id': 'AB',
      'type': 'line',
      'p1': [0, 0],
      'p2': [3, 0],
    },
    {
      'id': 'AC',
      'type': 'line',
      'p1': [0, 0],
      'p2': [0, 4],
    },
    {
      'id': 'BC',
      'type': 'line',
      'p1': [3, 0],
      'p2': [0, 4],
    },
  ],
  'meta': ?meta,
  'constraints': ?constraints,
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Linux GUI: a constrained triangle renders; a schematic one '
      'shows the not-to-scale note', (tester) async {
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
    final id = scenes.first.id;

    await c.visual.revise(
      id,
      jsonEncode(
        _triangle(
          constraints: [
            {'type': 'distance', 'a': 'A', 'b': 'B', 'value': 3},
            {'type': 'perpendicular', 'a': 'AB', 'b': 'AC'},
            {'type': 'midpoint', 'point': 'M', 'a': 'B', 'b': 'C'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('直角三角形'), findsOneWidget);
    expect(find.text('示意图，不按比例'), findsNothing);

    // Same triangle declared a schematic with a wrong distance: the
    // scene still renders, with the not-to-scale note.
    await c.visual.revise(
      id,
      jsonEncode(
        _triangle(
          meta: {'schematic': true, 'alt': '直角三角形示意图'},
          constraints: [
            {'type': 'distance', 'a': 'A', 'b': 'B', 'value': 4},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('直角三角形'), findsOneWidget);
    expect(find.text('示意图，不按比例'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
