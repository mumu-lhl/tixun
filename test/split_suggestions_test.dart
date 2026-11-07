import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/features/library/split_suggestions.dart';

void main() {
  group('displayRectForContain', () {
    test('letterboxes a wide image into a tall box', () {
      final rect = displayRectForContain(
        const Size(300, 200),
        const Size(400, 100),
      );
      // Scale 300/400 = 0.75; height 75, centered vertically.
      expect(rect, const Rect.fromLTWH(0, 62.5, 300, 75));
    });

    test('letterboxes a tall image into a wide box', () {
      final rect = displayRectForContain(
        const Size(300, 200),
        const Size(100, 400),
      );
      // Scale 200/400 = 0.5; width 50, centered horizontally.
      expect(rect, const Rect.fromLTWH(125, 0, 50, 200));
    });

    test('same aspect fills the box exactly', () {
      final rect = displayRectForContain(
        const Size(300, 200),
        const Size(600, 400),
      );
      expect(rect, const Rect.fromLTWH(0, 0, 300, 200));
    });

    test('empty sizes fall back to the full box', () {
      expect(
        displayRectForContain(const Size(300, 200), Size.zero),
        const Rect.fromLTWH(0, 0, 300, 200),
      );
      expect(
        displayRectForContain(Size.zero, const Size(100, 100)),
        const Rect.fromLTWH(0, 0, 0, 0),
      );
    });
  });
}
