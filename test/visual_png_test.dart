import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_png.dart';
import 'package:tixun/core/visual/render/visual_theme.dart';

const _testPalette = VisualPalette(
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('texToPlainText', () {
    test('frac becomes a/b', () {
      expect(texToPlainText(r'\frac{1}{2}'), '1/2');
      expect(texToPlainText(r'\frac{x+1}{2}'), 'x+1/2');
    });

    test('sqrt becomes the radical sign', () {
      expect(texToPlainText(r'\sqrt{x}'), '√x');
      expect(texToPlainText(r'\sqrt2'), '√2');
    });

    test('nested frac and sqrt compose', () {
      expect(texToPlainText(r'\frac{\sqrt{2}}{2}'), '√2/2');
      expect(texToPlainText(r'\sqrt{\frac{1}{2}}'), '√1/2');
    });

    test('other commands are dropped, ^ and _ are kept', () {
      expect(texToPlainText(r'x^2 + y^2 = 1'), 'x^2 + y^2 = 1');
      expect(texToPlainText(r'\alpha + \pi'), ' + ');
      expect(texToPlainText(r'a_{i}'), 'a_i');
    });

    test('plain text passes through unchanged', () {
      expect(texToPlainText('hello'), 'hello');
      expect(texToPlainText(''), '');
    });
  });

  test('renderVisualPng renders a frac label without crashing', () async {
    final scene = VisualScene.fromJson({
      'v': 1,
      'kind': 'geometry',
      'title': '分数',
      'elements': [
        {
          'id': 'label',
          'type': 'math_label',
          'at': [0, 0],
          'tex': r'\frac{1}{2}',
        },
      ],
      'meta': {'alt': '分数'},
    });
    final bytes = await renderVisualPng(scene, _testPalette);
    expect(bytes.length, greaterThan(100));
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
  });
}
