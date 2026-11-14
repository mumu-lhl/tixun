import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/export/docx_export.dart';
import 'package:tixun/core/export/image_size.dart';
import 'package:tixun/core/export/latex_text.dart';
import 'package:tixun/core/export/markdown_blocks.dart';
import 'package:tixun/core/export/markdown_export.dart';
import 'package:tixun/core/export/pdf_export.dart';
import 'package:tixun/core/export/study_export.dart';
import 'package:xml/xml.dart' as xml;

const _note = r'''
## 顶点式

二次函数的**顶点式**为 $y=a(x-h)^2+k$，顶点是 $(h,k)$。

- 对称轴 $x=h$
- 判别式 $\Delta=b^2-4ac$

1. 提取系数
2. 配方

> 配方：$x^2+bx=(x+\frac{b}{2})^2-\frac{b^2}{4}$。

| 条件 | 开口 |
| --- | --- |
| $a>0$ | 向上 |

```dart
final y = a * x * x;
```
''';

StudyExportBundle _bundle({List<StudyExportImage> images = const []}) {
  final now = DateTime.utc(2026, 11, 10, 9, 30);
  return StudyExportBundle(
    title: '知识打印稿',
    generatedAt: now,
    notes: [
      StudyExportNote(
        title: '二次函数：顶点式与判别式',
        subject: '数学',
        chapter: '第二章 二次函数',
        kind: '个人笔记',
        tags: const ['函数', '易错'],
        updatedAt: now,
        content: _note,
        images: images,
      ),
      StudyExportNote(
        title: '牛顿第二定律',
        subject: '物理',
        chapter: '第三章',
        kind: '个人笔记',
        updatedAt: now,
        content: r'受力分析：$F=ma$，单位换算 $1 \mathrm{N}=1 \mathrm{kg}\cdot \mathrm{m/s^2}$。',
      ),
    ],
  );
}

StudyExportChrome _chrome(StudyExportBundle bundle) => StudyExportChrome(
  title: '知识打印稿',
  dateLine: '生成于 2026-11-10 · 共 ${bundle.notes.length} 条',
  pageLabel: (page, total) => '第 $page / $total 页',
  noteMeta: (note) => '${note.subject} · 更新于 2026-11-10',
  imagesExcluded: '纯文本导出不包含图片附件。',
);

/// An 8x6 PNG: small, valid, and enough for the size reader and both writers.
final _png = Uint8List.fromList([
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x08,
  0x00,
  0x00,
  0x00,
  0x06,
  0x08,
  0x02,
  0x00,
  0x00,
  0x00,
  0x71,
  0x67,
  0x48,
  0xac,
  0x00,
  0x00,
  0x00,
  0x12,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0xf8,
  0xcf,
  0xc0,
  0x80,
  0x15,
  0x61,
  0x17,
  0xa5,
  0x93,
  0x04,
  0x00,
  0x33,
  0x28,
  0x2f,
  0xd1,
  0xec,
  0xc1,
  0x05,
  0xf9,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
]);

Future<Uint8List> _pdf(StudyExportBundle bundle) async {
  final font = await File('assets/fonts/NotoSansSC.ttf').readAsBytes();
  final mono = await File('assets/fonts/RobotoMono.ttf').readAsBytes();
  return buildStudyPdf(
    bundle: bundle,
    chrome: _chrome(bundle),
    font: ByteData.view(font.buffer, font.offsetInBytes, font.lengthInBytes),
    monoFont: ByteData.view(
      mono.buffer,
      mono.offsetInBytes,
      mono.lengthInBytes,
    ),
  );
}

void main() {
  group('LaTeX for print', () {
    test('fractions, roots and scripts become readable text', () {
      expect(latexToText(r'$\frac{a}{b}$'), 'a/b');
      expect(latexToText(r'$\frac{x+1}{2}$'), '(x+1)/2');
      expect(latexToText(r'$\frac{(n+1)!}{n!}$'), '((n+1)!)/(n!)');
      expect(latexToText(r'$\sqrt{x+1}$'), '√(x+1)');
      expect(latexToText(r'$\sqrt[3]{8}$'), '³√(8)');
      expect(latexToText(r'$x^2+1$'), 'x²+1');
      expect(latexToText(r'$10^{-3}$'), '10^(-3)');
      expect(latexToText(r'$x_1$'), 'x_1');
      expect(latexToText(r'$a_{n+1}$'), 'a_(n+1)');
    });

    test('symbols keep their meaning and delimiters are dropped', () {
      expect(latexToText(r'$\Delta = b^2-4ac$'), 'Δ = b²-4ac');
      expect(latexToText(r'$a \times b \div c$'), 'a × b ÷ c');
      expect(latexToText(r'$\alpha\geq\beta$'), 'α≥β');
      expect(latexToText(r'$\left(x+1\right)$'), '(x+1)');
      expect(latexToText(r'\(\sqrt[3]{8}\)'), '³√(8)');
      expect(latexToText(r'$$\frac{b^2}{4}$$'), 'b²/4');
      expect(latexToText(r'$\mathrm{kg}\cdot \mathrm{m}$'), 'kg· m');
    });

    test('matrices keep row and column order inside delimiters', () {
      expect(
        latexToText(r'$$\begin{pmatrix}1&2\\3&4\end{pmatrix}$$'),
        '(1, 2; 3, 4)',
      );
      expect(latexToText(r'$\begin{cases}x>0\\x<1\end{cases}$'), '{x>0; x<1}');
    });

    test('unknown commands keep their source instead of vanishing', () {
      final converted = latexToText(r'$\unknownmacro{x}$');
      expect(converted, contains('unknownmacro'));
      expect(converted, contains('x'));
    });

    test('trailing layout commands do not leave stray spaces', () {
      expect(latexToText(r'$a>0 \, $'), 'a>0');
      expect(latexToText(r'$\left| x \right|$'), '| x |');
    });
  });

  group('Markdown blocks', () {
    test('keeps headings, lists, quotes, tables and code', () {
      final document = parseLearningMarkdown(_note);
      final kinds = document.blocks.map((block) => block.kind).toList();
      expect(kinds.first, MdBlockKind.heading);
      expect(document.blocks.first.level, 2);
      expect(kinds, contains(MdBlockKind.bulletList));
      expect(kinds, contains(MdBlockKind.orderList));
      expect(kinds, contains(MdBlockKind.table));
      expect(kinds, contains(MdBlockKind.code));

      final quote = document.blocks.firstWhere((block) => block.quote);
      expect(plainText(quote.runs), contains('配方'));

      final ordered = document.blocks
          .where((block) => block.kind == MdBlockKind.orderList)
          .toList();
      expect(ordered.map((block) => block.marker), ['1.', '2.']);

      final code = document.blocks.firstWhere(
        (block) => block.kind == MdBlockKind.code,
      );
      expect(code.language, 'dart');
      expect(plainText(code.runs), 'final y = a * x * x;');

      final table = document.blocks.firstWhere(
        (block) => block.kind == MdBlockKind.table,
      );
      expect(table.rows.first.header, isTrue);
      expect(plainText(table.rows.first.cells.first), '条件');
      expect(plainText(table.rows[1].cells.first), 'a>0');
    });

    test('inline emphasis and maths are runs, not markup', () {
      final document = parseLearningMarkdown(_note);
      final paragraph = document.blocks.firstWhere(
        (block) =>
            block.kind == MdBlockKind.paragraph &&
            plainText(block.runs).contains('顶点式'),
      );
      expect(plainText(paragraph.runs), contains('y=a(x-h)²+k'));
      expect(paragraph.runs.any((run) => run.bold), isTrue);
      expect(paragraph.runs.any((run) => run.math), isTrue);
      expect(plainText(paragraph.runs), isNot(contains(r'$')));
    });

    test('nested lists keep their depth', () {
      final document = parseLearningMarkdown('- 顶层\n  - 子项\n');
      final depths = document.blocks.map((block) => block.listDepth).toList();
      expect(depths, [1, 2]);
    });

    test('an empty note is detected as empty', () {
      expect(parseLearningMarkdown('   \n\n').isEmpty, isTrue);
      expect(parseLearningMarkdown('正文').isEmpty, isFalse);
    });
  });

  group('Markdown export', () {
    test('groups by subject and keeps the note markdown', () {
      final bundle = _bundle();
      final markdown = buildStudyMarkdown(bundle, _chrome(bundle));
      expect(markdown, startsWith('# 知识打印稿'));
      expect(markdown, contains('## 数学'));
      expect(markdown, contains('## 物理'));
      expect(markdown, contains('### 二次函数：顶点式与判别式'));
      expect(markdown, contains('对称轴'));
      expect(markdown, contains('更新于 2026-11-10'));
    });

    test('says so when attachments are left out', () {
      final bundle = _bundle(
        images: [StudyExportImage(bytes: _png, mime: 'image/png')],
      );
      final markdown = buildStudyMarkdown(bundle, _chrome(bundle));
      expect(markdown, contains('纯文本导出不包含图片附件。'));
    });
  });

  group('PDF export', () {
    test('writes a real PDF with an embedded subset font', () async {
      final bytes = await _pdf(_bundle());
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(utf8.decode(bytes.sublist(bytes.length - 6)), contains('EOF'));
      expect(bytes.length, greaterThan(2000));
      // A full 16.9 MB face would make each export unusable; the writer must
      // embed only the glyphs the document uses.
      expect(bytes.length, lessThan(200 * 1024));
    });

    test('includes attachment images without breaking the page flow', () async {
      final bundle = _bundle(
        images: [StudyExportImage(bytes: _png, mime: 'image/png')],
      );
      final bytes = await _pdf(bundle);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(2000));
    });

    test('ignores image bytes the PDF writer cannot embed', () async {
      final bundle = _bundle(
        images: [
          StudyExportImage(
            bytes: Uint8List.fromList([1, 2, 3]),
            mime: 'image/webp',
          ),
        ],
      );
      final bytes = await _pdf(bundle);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  });

  group('DOCX export', () {
    Archive read(Uint8List bytes) =>
        ZipDecoder().decodeBytes(bytes, verify: true);

    test('contains the parts Word requires', () {
      final bundle = _bundle();
      final archive = read(
        buildStudyDocx(bundle: bundle, chrome: _chrome(bundle)),
      );
      final names = archive.files.map((file) => file.name).toSet();
      expect(
        names,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'word/document.xml',
          'word/styles.xml',
          'word/footer1.xml',
          'word/_rels/document.xml.rels',
        ]),
      );
      for (final name in names.where(
        (name) => name.endsWith('.xml') || name.endsWith('.rels'),
      )) {
        final content = utf8.decode(
          archive.files.firstWhere((file) => file.name == name).content
              as List<int>,
        );
        expect(
          () => xml.XmlDocument.parse(content),
          returnsNormally,
          reason: name,
        );
      }
      final document = utf8.decode(
        archive.files
                .firstWhere((file) => file.name == 'word/document.xml')
                .content
            as List<int>,
      );
      expect(document, contains('知识打印稿'));
      expect(document, contains('<w:tbl>'));
      expect(document, contains('Heading2'));
    });

    test('adds images as media parts with a relationship', () {
      final bundle = _bundle(
        images: [StudyExportImage(bytes: _png, mime: 'image/png')],
      );
      final archive = read(
        buildStudyDocx(bundle: bundle, chrome: _chrome(bundle)),
      );
      final names = archive.files.map((file) => file.name).toList();
      expect(names, contains('word/media/image1.png'));
      final rels = utf8.decode(
        archive.files
                .firstWhere(
                  (file) => file.name == 'word/_rels/document.xml.rels',
                )
                .content
            as List<int>,
      );
      expect(rels, contains('media/image1.png'));
      final contentTypes = utf8.decode(
        archive.files
                .firstWhere((file) => file.name == '[Content_Types].xml')
                .content
            as List<int>,
      );
      expect(contentTypes, contains('image/png'));
    });

    test('escapes markup characters so Word can open the file', () {
      final bundle = StudyExportBundle(
        title: '标题 <&>"',
        generatedAt: DateTime.utc(2026),
        notes: [
          StudyExportNote(
            title: 'a < b & c',
            subject: '数学',
            content: r'当 a < b 且 b & c 时，$x>1$。',
            updatedAt: DateTime.utc(2026),
          ),
        ],
      );
      final archive = read(
        buildStudyDocx(bundle: bundle, chrome: _chrome(bundle)),
      );
      final document = utf8.decode(
        archive.files
                .firstWhere((file) => file.name == 'word/document.xml')
                .content
            as List<int>,
      );
      expect(document, contains('a &lt; b &amp; c'));
      expect(xml.XmlDocument.parse(document), isA<xml.XmlDocument>());
    });
  });

  group('Image size', () {
    test('reads PNG and JPEG headers', () {
      expect(imagePixelSize(_png), (8, 6));
      // Minimal JPEG: SOI, APP0, SOF0 with 320x240.
      final jpeg = Uint8List.fromList([
        0xff, 0xd8, //
        0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00,
        0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
        0xff, 0xc0, 0x00, 0x11, 0x08, 0x00, 0xf0, 0x01, 0x40,
        0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
      ]);
      expect(imagePixelSize(jpeg), (320, 240));
      expect(imagePixelSize(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
    });
  });
}
