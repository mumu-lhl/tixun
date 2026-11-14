import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/circuit_geometry.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';
import 'package:tixun/core/visual/render/visual_png.dart';
import 'package:tixun/core/visual/render/visual_theme.dart';
import 'package:tixun/core/visual/validation/visual_validator.dart';
import 'package:tixun/features/visual/visual_card.dart';

Map<String, dynamic> circuitSceneJson({bool showAxes = false}) => {
  'v': 1,
  'kind': 'circuit',
  'title': '串联电路',
  'model': {'showAxes': showAxes},
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

const _palette = VisualPalette(
  primary: Color(0xff226450),
  highlight: Color(0xff7d5700),
  muted: Color(0xff767680),
  success: Color(0xff226450),
  danger: Color(0xffb3261e),
  axis: Color(0x991c1b1f),
  grid: Color(0xffd0d0d0),
  background: Color(0xfffafbf8),
  onBackground: Color(0xff1c1b1f),
  textMuted: Color(0xff767680),
);

void main() {
  group('CircuitElement model', () {
    test('every component round-trips through JSON', () {
      final scene = VisualScene.fromJson(circuitSceneJson());
      final byId = {for (final e in scene.elements) e.id: e};
      final battery = byId['bat'] as CircuitElement;
      expect(battery.component, CircuitComponent.battery);
      expect(
        battery.from,
        const VisualPoint(VisualCoord.literal(-2), VisualCoord.literal(2)),
      );
      expect(battery.label, '6V');
      final sw = byId['sw'] as CircuitElement;
      expect(sw.component, CircuitComponent.powerSwitch);
      expect(sw.closed, isFalse);
      final meter = byId['a1'] as CircuitElement;
      expect(meter.component, CircuitComponent.meter);
      expect(meter.meter, CircuitMeterKind.ammeter);
      expect(
        meter.at,
        const VisualPoint(VisualCoord.literal(-2), VisualCoord.literal(0)),
      );
      // toJson writes `switch` (not `powerSwitch`) for the switch, and
      // keeps the two-point fields.
      expect(sw.toJson()['component'], 'switch');
      expect(sw.toJson()['from'], [2, -2]);
      expect(sw.toJson()['to'], [-2, -2]);
    });

    test('fromJson rejects an unknown component and missing fields', () {
      expect(
        () => VisualElement.fromJson({
          'id': 'x',
          'type': 'circuit',
          'component': 'coil',
          'from': [0, 0],
          'to': [1, 0],
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualElement.fromJson({
          'id': 'x',
          'type': 'circuit',
          'component': 'meter',
          'at': [0, 0],
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualElement.fromJson({
          'id': 'x',
          'type': 'circuit',
          'component': 'resistor',
          'to': [1, 0],
        }),
        throwsA(isA<AppFormatException>()),
      );
    });
  });

  group('circuit geometry helpers', () {
    test('resistor zigzag has three peaks with the right amplitude', () {
      const from = ui.Offset(0, 0);
      const to = ui.Offset(10, 0);
      final points = circuitZigzagPoints(from, to);
      expect(points.length, 9);
      expect(points.first, from);
      expect(points.last, to);
      // Peaks alternate sides of the segment, amplitude 1.2 (12% of 10).
      final lifts = points.sublist(1, 8).map((p) => p.dy).toList();
      expect(lifts, [0.0, 1.2, -1.2, 1.2, -1.2, 1.2, 0.0]);
      // Degenerate segment: just the endpoints.
      expect(circuitZigzagPoints(from, from), [from, from]);
    });

    test('battery plates are perpendicular, long toward from', () {
      const from = ui.Offset(0, 0);
      const to = ui.Offset(10, 0);
      final plates = circuitBatteryPlates(from, to);
      final longLength = (plates.longB - plates.longA).distance;
      final shortLength = (plates.shortB - plates.shortA).distance;
      expect(longLength, closeTo(3.0, 1e-9));
      expect(shortLength, closeTo(1.5, 1e-9));
      // Both plates vertical (perpendicular to the horizontal segment).
      expect(plates.longA.dx, closeTo(4.5, 1e-9));
      expect(plates.shortA.dx, closeTo(5.5, 1e-9));
      // Long plate is closer to `from`.
      final longCenter = (plates.longA + plates.longB) / 2;
      final shortCenter = (plates.shortA + plates.shortB) / 2;
      expect(longCenter.dx, lessThan(shortCenter.dx));
    });

    test('switch segments: closed is straight, open has a 30-degree blade', () {
      const from = ui.Offset(0, 0);
      const to = ui.Offset(10, 0);
      expect(circuitSwitchSegments(from, to, true), [(from, to)]);
      final open = circuitSwitchSegments(from, to, false);
      expect(open.length, 2);
      expect(open[0], (from, const ui.Offset(3.5, 0)));
      // Blade rises 30 degrees over 3 units from the 35% point.
      expect(open[1].$1, const ui.Offset(3.5, 0));
      expect(open[1].$2.dx, closeTo(3.5 + 3 * 0.8660254, 1e-6));
      expect(open[1].$2.dy, closeTo(1.5, 1e-9));
    });
  });

  group('validateVisualScene: circuits', () {
    test('a series circuit scene is ok and verified', () {
      final v = validateVisualScene(circuitSceneJson());
      expect(v.ok, isTrue);
      expect(v.errors, isEmpty);
      expect(v.verificationStatus, 'verified');
    });

    test('chemistry and geography kinds are accepted', () {
      for (final kind in ['chemistry', 'geography']) {
        final v = validateVisualScene({
          'v': 1,
          'kind': kind,
          'elements': [
            {
              'id': 'c',
              'type': 'circle',
              'center': [0, 0],
              'r': 1,
            },
          ],
        });
        expect(v.ok, isTrue, reason: kind);
      }
    });

    test('rejects bad circuit fields', () {
      Map<String, dynamic> withElement(Map<String, dynamic> element) => {
        'v': 1,
        'kind': 'circuit',
        'elements': [element],
      };
      // closed on a resistor.
      expect(
        validateVisualScene(
          withElement({
            'id': 'r',
            'type': 'circuit',
            'component': 'resistor',
            'from': [0, 0],
            'to': [1, 0],
            'closed': true,
          }),
        ).ok,
        isFalse,
      );
      // meter without a meter kind.
      expect(
        validateVisualScene(
          withElement({
            'id': 'm',
            'type': 'circuit',
            'component': 'meter',
            'at': [0, 0],
          }),
        ).ok,
        isFalse,
      );
      // meter carrying from/to.
      expect(
        validateVisualScene(
          withElement({
            'id': 'm',
            'type': 'circuit',
            'component': 'meter',
            'at': [0, 0],
            'meter': 'voltmeter',
            'from': [0, 0],
            'to': [1, 0],
          }),
        ).ok,
        isFalse,
      );
    });

    test('a circuit scene without circuit elements only warns', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'circuit',
        'elements': [
          {
            'id': 'l',
            'type': 'line',
            'p1': [0, 0],
            'p2': [1, 0],
          },
        ],
      });
      expect(v.ok, isTrue);
      expect(v.warnings.any((w) => w.code == 'no_circuit_element'), isTrue);
    });
  });

  group('visualSceneDrawsAxes', () {
    test('diagrams have no axes unless explicitly opted in', () {
      expect(
        visualSceneDrawsAxes(VisualScene.fromJson(circuitSceneJson())),
        isFalse,
      );
      expect(
        visualSceneDrawsAxes(
          VisualScene.fromJson(circuitSceneJson(showAxes: true)),
        ),
        isTrue,
      );
      expect(
        visualSceneDrawsAxes(
          VisualScene.fromJson({
            'v': 1,
            'kind': 'geometry',
            'view': {
              'x': [-3, 3],
              'y': [-3, 3],
            },
          }),
        ),
        isTrue,
      );
      expect(
        visualSceneDrawsAxes(VisualScene.fromJson({'v': 1, 'kind': 'plot2d'})),
        isTrue,
      );
    });
  });

  test('renderVisualPng renders a circuit scene', () async {
    final bytes = await renderVisualPng(
      VisualScene.fromJson(circuitSceneJson()),
      _palette,
    );
    expect(bytes.length, greaterThan(100));
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
  });

  testWidgets('circuit card renders without axes', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VisualCard(scene: VisualScene.fromJson(circuitSceneJson())),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('串联电路'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
