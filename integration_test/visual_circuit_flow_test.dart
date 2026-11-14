import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Linux GUI: a series circuit renders in the chat card', (
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
    // Replace the static mock scene with a series circuit: battery,
    // resistor, open switch, wire loop and an ammeter.
    final circuitScene = {
      'v': 1,
      'kind': 'circuit',
      'title': '串联电路',
      'view': {
        'x': [-4, 4],
        'y': [-3, 3],
      },
      'elements': [
        {
          'id': 'bat',
          'type': 'circuit',
          'component': 'battery',
          'from': [-2, 2],
          'to': [2, 2],
          'label': '6V',
        },
        {
          'id': 'r1',
          'type': 'circuit',
          'component': 'resistor',
          'from': [2, 2],
          'to': [2, -2],
          'label': 'R1',
        },
        {
          'id': 'sw',
          'type': 'circuit',
          'component': 'switch',
          'from': [2, -2],
          'to': [-2, -2],
        },
        {
          'id': 'w1',
          'type': 'circuit',
          'component': 'wire',
          'from': [-2, -2],
          'to': [-2, 2],
        },
        {
          'id': 'a1',
          'type': 'circuit',
          'component': 'meter',
          'at': [-2, 0],
          'meter': 'ammeter',
        },
      ],
      'meta': {'alt': '电源、电阻、开关与电流表组成的串联电路'},
    };
    await c.visual.revise(scenes.first.id, jsonEncode(circuitScene));
    await tester.pumpAndSettle();
    expect(find.text('串联电路'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
