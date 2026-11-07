import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/features/review/review_screen.dart';

void main() {
  group('plainTextPreview', () {
    test('strips LaTeX delimiters', () {
      expect(
        plainTextPreview(r'解方程 $3x+5=20$，填写 $x$ 的值。'),
        '解方程 3x+5=20，填写 x 的值。',
      );
    });
    test('strips display math and markdown markers', () {
      expect(
        plainTextPreview(r'$$a^2+b^2=c^2$$ 与 **粗体** 和 `代码`'),
        'a^2+b^2=c^2 与 粗体 和 代码',
      );
    });
    test('keeps link text, drops images', () {
      expect(
        plainTextPreview('[链接文本](https://example.com) ![图](x.png) 尾巴'),
        '链接文本 尾巴',
      );
    });
    test('strips headings and collapses whitespace', () {
      expect(plainTextPreview('# 标题\n\n正文  第二行'), '标题 正文 第二行');
    });
  });

  group('reviewDate', () {
    test('current year shows no year', () {
      final now = DateTime.now();
      expect(reviewDate(DateTime(now.year, 11, 7, 19, 5)), '11月7日 19:05');
    });
    test('other years show the year', () {
      final now = DateTime.now();
      expect(
        reviewDate(DateTime(now.year - 1, 3, 2, 9, 4)),
        '${now.year - 1}年3月2日 09:04',
      );
    });
  });

  group('dueLabel', () {
    testWidgets('marks overdue items with days', (tester) async {
      final due = DateTime.now().subtract(const Duration(days: 3, hours: 2));
      late String label;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              label = dueLabel(context, due);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(label, contains('已逾期 3 天'));
    });
    testWidgets('future dates carry no marker', (tester) async {
      final due = DateTime.now().add(const Duration(days: 2));
      late String label;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              label = dueLabel(context, due);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(label, isNot(contains('已逾期')));
    });
  });
}
