import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';
import 'package:tixun/core/visual/render/visual_png.dart';
import 'package:tixun/core/visual/render/visual_theme.dart';
import 'package:tixun/core/visual/validation/visual_validator.dart';

/// A water molecule: atoms as circles, bonds as lines, formula as a
/// math label (subscripts come from TeX, not canvas text).
Map<String, dynamic> waterMoleculeJson() => {
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
      'id': 'o-label',
      'type': 'text',
      'at': [0.2, 0.6],
      'text': 'O',
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

/// A combustion reaction: formulas as math labels, reaction arrow.
Map<String, dynamic> combustionJson() => {
  'v': 1,
  'kind': 'chemistry',
  'title': '甲烷燃烧',
  'view': {
    'x': [-4, 4],
    'y': [-2, 2],
  },
  'elements': [
    {
      'id': 'reactants',
      'type': 'math_label',
      'at': [-3.5, 0.5],
      'tex': r'CH_4 + 2O_2',
    },
    {
      'id': 'arrow',
      'type': 'arrow',
      'from': [-1, 0],
      'to': [1, 0],
    },
    {
      'id': 'products',
      'type': 'math_label',
      'at': [1.5, 0.5],
      'tex': r'CO_2 + 2H_2O',
    },
  ],
  'meta': {'alt': '甲烷燃烧生成二氧化碳和水'},
};

/// A terrain cross-section: filled polygon + labels.
Map<String, dynamic> terrainJson() => {
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
    {
      'id': 'valley',
      'type': 'text',
      'at': [-0.5, 0.6],
      'text': '山谷',
    },
  ],
  'meta': {'alt': '山地地形剖面：山峰与山谷'},
};

/// Earth revolving around the sun: orbit circle + four earth positions
/// shown one per timeline step.
Map<String, dynamic> revolutionJson() => {
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
    for (final (i, pos) in [
      [2, 0],
      [0, 2],
      [-2, 0],
      [0, -2],
    ].indexed)
      {
        'id': 'earth$i',
        'type': 'point',
        'at': pos,
        'label': '地球',
        'style': 'highlight',
      },
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
  group('chemistry scenes', () {
    test('water molecule validates and renders', () async {
      final v = validateVisualScene(waterMoleculeJson());
      expect(v.ok, isTrue);
      expect(v.errors, isEmpty);
      final bytes = await renderVisualPng(
        VisualScene.fromJson(waterMoleculeJson()),
        _palette,
      );
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
    });

    test('combustion reaction validates', () {
      final v = validateVisualScene(combustionJson());
      expect(v.ok, isTrue);
      expect(v.errors, isEmpty);
    });
  });

  group('geography scenes', () {
    test('terrain profile validates and renders', () async {
      final v = validateVisualScene(terrainJson());
      expect(v.ok, isTrue);
      expect(v.errors, isEmpty);
      final bytes = await renderVisualPng(
        VisualScene.fromJson(terrainJson()),
        _palette,
      );
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
    });

    test('earth revolution validates, steps resolve', () {
      final v = validateVisualScene(revolutionJson());
      expect(v.ok, isTrue);
      expect(v.errors, isEmpty);
      final scene = VisualScene.fromJson(revolutionJson());
      expect(scene.timeline!.steps.length, 4);
      expect(scene.timeline!.durationMs, 8000);
    });

    test('geography and chemistry scenes have no axes by default', () {
      expect(
        visualSceneDrawsAxes(VisualScene.fromJson(terrainJson())),
        isFalse,
      );
      expect(
        visualSceneDrawsAxes(VisualScene.fromJson(waterMoleculeJson())),
        isFalse,
      );
    });
  });
}
