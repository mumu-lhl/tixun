import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';

Future<void> _sendMockDrawing(WidgetTester tester, AppController c) async {
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
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Real Linux GUI: chemistry molecule and geography profile render',
    (tester) async {
      final c = await AppController.open(demo: true);
      final container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TixunApp(),
        ),
      );
      await tester.pumpAndSettle();
      await _sendMockDrawing(tester, c);
      final scenes = await c.visual.listByMessage(c.messages.last.id);
      expect(scenes, hasLength(1));
      final id = scenes.first.id;

      final molecule = {
        'v': 1,
        'kind': 'chemistry',
        'title': '水分子的结构',
        'view': {
          'x': [-2, 2],
          'y': [-2, 2],
        },
        'elements': [
          {
            'id': 'o',
            'type': 'circle',
            'center': [0, 0.4],
            'r': 0.5,
            'style': 'danger',
          },
          {
            'id': 'h1',
            'type': 'circle',
            'center': [-0.8, -0.6],
            'r': 0.35,
          },
          {
            'id': 'h2',
            'type': 'circle',
            'center': [0.8, -0.6],
            'r': 0.35,
          },
          {
            'id': 'b1',
            'type': 'line',
            'p1': [-0.3, 0.1],
            'p2': [-0.65, -0.35],
          },
          {
            'id': 'b2',
            'type': 'line',
            'p1': [0.3, 0.1],
            'p2': [0.65, -0.35],
          },
          {
            'id': 'formula',
            'type': 'math_label',
            'at': [0, 1.4],
            'tex': r'H_2O',
          },
        ],
        'meta': {'alt': '水分子：一个氧原子连接两个氢原子'},
      };
      await c.visual.revise(id, jsonEncode(molecule));
      await tester.pumpAndSettle();
      expect(find.text('水分子的结构'), findsOneWidget);

      final terrain = {
        'v': 1,
        'kind': 'geography',
        'title': '地形剖面',
        'view': {
          'x': [-4, 4],
          'y': [-2, 3],
        },
        'elements': [
          {
            'id': 'ground',
            'type': 'polygon',
            'points': [
              [-3.5, -1.5],
              [-1.5, 1],
              [-0.5, 0.4],
              [0.5, 1.8],
              [1.5, 0.6],
              [3.5, -1.5],
            ],
            'fill': true,
          },
          {
            'id': 'peak',
            'type': 'text',
            'at': [0.5, 2],
            'text': '山峰',
          },
        ],
        'meta': {'alt': '山地地形剖面：山峰与山谷'},
      };
      await c.visual.revise(id, jsonEncode(terrain));
      await tester.pumpAndSettle();
      expect(find.text('地形剖面'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
