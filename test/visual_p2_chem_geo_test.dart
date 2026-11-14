import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_animator.dart';
import 'package:tixun/core/visual/render/visual_png.dart';
import 'package:tixun/core/visual/render/visual_theme.dart';
import 'package:tixun/core/visual/validation/visual_validator.dart';

/// P2 coverage for chemistry/geography scenes: the combustion reaction
/// renders to a real PNG, and the earth-revolution timeline shows a
/// different earth position at each step.

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

Map<String, dynamic> _combustionJson() => {
  'v': 1,
  'kind': 'chemistry',
  'title': '甲烷燃烧',
  'view': {
    'x': [-3, 3],
    'y': [-3, 3],
  },
  'elements': [
    {
      'id': 'lhs',
      'type': 'math_label',
      'at': [-2, 0],
      'tex': r'CH_4 + 2O_2',
    },
    {
      'id': 'arrow',
      'type': 'arrow',
      'from': [-0.5, 0],
      'to': [0.5, 0],
    },
    {
      'id': 'rhs',
      'type': 'math_label',
      'at': [2, 0],
      'tex': r'CO_2 + 2H_2O',
    },
  ],
  'meta': {'alt': '甲烷燃烧的化学方程式'},
};

Map<String, dynamic> _revolutionJson() => {
  'v': 1,
  'kind': 'geography',
  'title': '地球公转',
  'view': {
    'x': [-3, 3],
    'y': [-3, 3],
  },
  'elements': [
    {
      'id': 'orbit',
      'type': 'circle',
      'center': [0, 0],
      'r': 2,
      'style': 'muted',
    },
    {
      'id': 'sun',
      'type': 'point',
      'at': [0, 0],
      'label': '太阳',
    },
    for (final (i, pos) in const [
      [2, 0],
      [0, 2],
      [-2, 0],
      [0, -2],
    ].indexed)
      {'id': 'earth$i', 'type': 'point', 'at': pos, 'label': '地球'},
  ],
  'timeline': {
    'durationMs': 8000,
    'tracks': [],
    'steps': [
      for (var i = 0; i < 4; i++)
        {
          'atMs': i * 2000,
          'show': ['earth$i'],
          'hide': [
            for (var j = 0; j < 4; j++)
              if (j != i) 'earth$j',
          ],
          'note': '第 ${i + 1} 个位置',
        },
    ],
  },
  'meta': {'alt': '地球绕太阳公转的四个位置'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('combustion reaction', () {
    test('the scene validates', () {
      expect(validateVisualScene(_combustionJson()).ok, isTrue);
    });

    test('it renders to a non-empty PNG', () async {
      final scene = VisualScene.fromJson(_combustionJson());
      final png = await renderVisualPng(scene, _palette);
      expect(png, isNotEmpty);
      // PNG magic: 89 50 4E 47 0D 0A 1A 0A.
      expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    });
  });

  group('earth revolution frames', () {
    test('each step shows exactly one earth position', () {
      final scene = VisualScene.fromJson(_revolutionJson());
      for (var i = 0; i < 4; i++) {
        final frame = resolveVisualFrame(scene, i * 2000.0);
        expect(frame.stepIndex, i, reason: 't=${i * 2000}');
        expect(
          frame.hiddenElementIds,
          {'earth0', 'earth1', 'earth2', 'earth3'}..remove('earth$i'),
          reason: 't=${i * 2000}',
        );
      }
    });

    test('the final position stays visible past the duration', () {
      final scene = VisualScene.fromJson(_revolutionJson());
      final frame = resolveVisualFrame(scene, 12000);
      expect(frame.hiddenElementIds, {'earth0', 'earth1', 'earth2'});
      expect(frame.stepIndex, 3);
    });

    test('the orbit and the sun are never hidden by steps', () {
      final scene = VisualScene.fromJson(_revolutionJson());
      for (var t = 0.0; t <= 8000; t += 2000) {
        final frame = resolveVisualFrame(scene, t);
        expect(frame.hiddenElementIds, isNot(contains('orbit')));
        expect(frame.hiddenElementIds, isNot(contains('sun')));
      }
    });

    test('each frame renders to a PNG', () async {
      final scene = VisualScene.fromJson(_revolutionJson());
      for (var i = 0; i < 4; i++) {
        final png = await renderVisualPng(
          scene,
          _palette,
          timeMs: i * 2000.0,
          stepIndex: i,
        );
        expect(png, isNotEmpty);
        expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      }
    });
  });
}
