/// Print-oriented PDF writer.
///
/// Text stays real text (selectable, searchable and small on disk): the CJK
/// font is embedded as a subset and no page is rasterised. Markdown is expanded
/// by [parseLearningMarkdown]. Formulas are rendered separately at print
/// resolution; ordinary text stays selectable.
library;

import "dart:math" as math;
import "dart:typed_data";

import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

import "markdown_blocks.dart";
import "pdf_math.dart";
import "study_export.dart";

const _pageMargin = pw.EdgeInsets.fromLTRB(44, 52, 44, 48);

class _Styles {
  _Styles(this.base, this.mono, this.formulas);
  final pw.Font base;
  final pw.Font mono;
  final Map<(String, bool), PdfFormulaImage> formulas;
  final _formulaProviders = <PdfFormulaImage, pw.MemoryImage>{};
  pw.MemoryImage image(PdfFormulaImage formula) => _formulaProviders
      .putIfAbsent(formula, () => pw.MemoryImage(formula.bytes));

  pw.TextStyle get body =>
      pw.TextStyle(font: base, fontSize: 10.5, lineSpacing: 3.2);
  pw.TextStyle get small =>
      pw.TextStyle(font: base, fontSize: 8.5, color: PdfColors.grey700);
  pw.TextStyle get noteTitle => pw.TextStyle(font: base, fontSize: 15);
  pw.TextStyle get section => pw.TextStyle(font: base, fontSize: 12.5);
  pw.TextStyle heading(int level) => pw.TextStyle(
    font: base,
    fontSize: switch (level) {
      1 => 14,
      2 => 13,
      3 => 11.5,
      _ => 10.5,
    },
    fontWeight: pw.FontWeight.bold,
  );
  pw.TextStyle get monoText =>
      pw.TextStyle(font: mono, fontSize: 9, lineSpacing: 2.4);
}

/// Builds the printable PDF for [bundle].
///
/// [font] must be a CJK-capable TrueType face (the app bundles Noto Sans SC);
/// [monoFont] is only used for code blocks.
Future<Uint8List> buildStudyPdf({
  required StudyExportBundle bundle,
  required StudyExportChrome chrome,
  required ByteData font,
  ByteData? monoFont,
  bool includeImages = true,
  PdfPageFormat pageFormat = PdfPageFormat.a4,
}) async {
  final base = pw.Font.ttf(font);
  final mono = monoFont == null ? base : pw.Font.ttf(monoFont);
  final formulas = <(String, bool), PdfFormulaImage>{};
  final attempted = <(String, bool)>{};
  for (final note in bundle.notes) {
    for (final block in parseLearningMarkdown(note.content).blocks) {
      final display = block.kind == MdBlockKind.formula;
      for (final run in block.allRuns) {
        final tex = run.tex;
        if (tex == null || !attempted.add((tex, display))) continue;
        final image = await renderPdfFormula(tex, display: display);
        if (image != null) formulas[(tex, display)] = image;
      }
    }
  }
  final styles = _Styles(base, mono, formulas);
  final contentWidth =
      pageFormat.availableWidth - _pageMargin.left - _pageMargin.right;

  final document = pw.Document(
    title: chrome.title,
    author: "题训",
    creator: "题训",
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: _pageMargin,
      theme: pw.ThemeData.withFont(
        base: base,
        bold: base,
        italic: base,
        boldItalic: base,
      ),
      header: (context) {
        if (context.pageNumber == 1) return pw.SizedBox();
        return pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Text(chrome.title, style: styles.small),
        );
      },
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          chrome.pageLabel(context.pageNumber, context.pagesCount),
          style: styles.small,
        ),
      ),
      build: (context) => [
        _cover(chrome, bundle, styles),
        for (final entry in bundle.bySubject.entries) ...[
          if (bundle.bySubject.length > 1) _subjectHeader(entry.key, styles),
          for (final note in entry.value)
            ..._note(note, chrome, styles, contentWidth, includeImages),
        ],
      ],
    ),
  );

  return document.save();
}

pw.Widget _cover(
  StudyExportChrome chrome,
  StudyExportBundle bundle,
  _Styles styles,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 14),
    margin: const pw.EdgeInsets.only(bottom: 18),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColors.grey600, width: 1.2),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          chrome.title,
          style: pw.TextStyle(font: styles.base, fontSize: 21),
        ),
        pw.SizedBox(height: 6),
        pw.Text(chrome.dateLine, style: styles.small),
      ],
    ),
  );
}

pw.Widget _subjectHeader(String subject, _Styles styles) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 14, bottom: 4),
  padding: const pw.EdgeInsets.only(bottom: 3),
  decoration: const pw.BoxDecoration(
    border: pw.Border(
      bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
    ),
  ),
  child: pw.Text(subject, style: styles.section),
);

List<pw.Widget> _note(
  StudyExportNote note,
  StudyExportChrome chrome,
  _Styles styles,
  double contentWidth,
  bool includeImages,
) {
  final parsed = parseLearningMarkdown(note.content);
  return [
    pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(note.title, style: styles.noteTitle),
          pw.SizedBox(height: 2),
          pw.Text(chrome.noteMeta(note), style: styles.small),
          pw.SizedBox(height: 6),
        ],
      ),
    ),
    for (final block in parsed.blocks) ..._block(block, styles, contentWidth),
    if (includeImages && note.images.isNotEmpty)
      ..._images(note.images, contentWidth),
  ];
}

List<pw.Widget> _block(MdBlock block, _Styles styles, double contentWidth) {
  switch (block.kind) {
    case MdBlockKind.rule:
      return [
        pw.Container(
          height: 0.6,
          margin: const pw.EdgeInsets.symmetric(vertical: 8),
          color: PdfColors.grey400,
        ),
      ];
    case MdBlockKind.heading:
      return [
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 10, bottom: 3),
          child: pw.RichText(
            text: pw.TextSpan(
              children: _spans(
                block.runs,
                styles,
                style: styles.heading(block.level),
              ),
            ),
          ),
        ),
      ];
    case MdBlockKind.code:
      return [
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(plainText(block.runs), style: styles.monoText),
        ),
      ];
    case MdBlockKind.formula:
      return [
        pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          alignment: pw.Alignment.center,
          child: _formulaBlock(block, styles, contentWidth),
        ),
      ];
    case MdBlockKind.table:
      return [_table(block, styles, contentWidth)];
    case MdBlockKind.bulletList:
    case MdBlockKind.orderList:
      return [
        pw.Container(
          margin: pw.EdgeInsets.only(
            left: 8.0 + block.listDepth * 12,
            bottom: 2,
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: block.kind == MdBlockKind.orderList ? 18 : 10,
                child: pw.Text(block.marker, style: styles.body),
              ),
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(children: _spans(block.runs, styles)),
                ),
              ),
            ],
          ),
        ),
      ];
    case MdBlockKind.paragraph:
      return [
        pw.Container(
          margin: pw.EdgeInsets.only(left: block.quote ? 10 : 0, bottom: 4),
          padding: pw.EdgeInsets.only(left: block.quote ? 8 : 0),
          decoration: block.quote
              ? const pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: PdfColors.grey400, width: 2),
                  ),
                )
              : null,
          child: pw.RichText(
            text: pw.TextSpan(
              children: _spans(
                block.runs,
                styles,
                style: block.quote
                    ? styles.body.copyWith(color: PdfColors.grey800)
                    : null,
              ),
            ),
            textAlign: pw.TextAlign.justify,
          ),
        ),
      ];
  }
}

pw.Widget _table(MdBlock block, _Styles styles, double contentWidth) {
  final columns = block.rows
      .map((row) => row.cells.length)
      .fold(1, (max, count) => math.max(max, count));
  return pw.Container(
    margin: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        for (var i = 0; i < columns; i++) i: const pw.FlexColumnWidth(),
      },
      children: [
        for (final row in block.rows)
          pw.TableRow(
            decoration: row.header
                ? const pw.BoxDecoration(color: PdfColors.grey200)
                : null,
            children: [
              for (var i = 0; i < columns; i++)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  child: pw.RichText(
                    text: pw.TextSpan(
                      children: i < row.cells.length
                          ? _spans(
                              row.cells[i],
                              styles,
                              style: styles.body.copyWith(
                                fontSize: 9.5,
                                fontWeight: row.header
                                    ? pw.FontWeight.bold
                                    : pw.FontWeight.normal,
                              ),
                              maxFormulaWidth: math.max(
                                20,
                                contentWidth / columns - 12,
                              ),
                            )
                          : <pw.InlineSpan>[],
                    ),
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

List<pw.Widget> _images(List<StudyExportImage> images, double contentWidth) {
  final widgets = <pw.Widget>[];
  final usable = images
      .where((image) => image.isPng || image.isJpeg)
      .toList(growable: false);
  if (usable.isEmpty) return widgets;
  final columns = usable.length == 1 ? 1 : 2;
  final gap = 8.0;
  final targetWidth = columns == 1 ? contentWidth : (contentWidth - gap) / 2;
  for (final image in usable) {
    final memory = pw.MemoryImage(image.bytes);
    final pixelWidth = memory.width?.toDouble();
    final pixelHeight = memory.height?.toDouble();
    if (pixelWidth == null || pixelHeight == null || pixelWidth <= 0) continue;
    final width = math.min(targetWidth, pixelWidth);
    // One figure may use half the page; a grid of figures stays compact enough
    // that several still fit on a single printed sheet.
    final maxHeight = columns == 1 ? 380.0 : 200.0;
    final height = math.min(width * pixelHeight / pixelWidth, maxHeight);
    widgets.add(
      pw.Container(
        margin: pw.EdgeInsets.only(top: 6, right: gap),
        child: pw.Image(
          memory,
          width: width,
          height: height,
          fit: pw.BoxFit.contain,
        ),
      ),
    );
  }
  if (widgets.isEmpty) return const [];
  return [
    pw.Wrap(spacing: 0, runSpacing: 4, children: widgets),
    pw.SizedBox(height: 4),
  ];
}

List<pw.InlineSpan> _spans(
  List<MdRun> runs,
  _Styles styles, {
  pw.TextStyle? style,
  double maxFormulaWidth = 120,
}) {
  final baseStyle = style ?? styles.body;
  return [
    for (final run in runs)
      if (run.text.isNotEmpty)
        if (run.tex != null && styles.formulas[(run.tex!, false)] != null)
          _formulaSpan(
            styles.formulas[(run.tex!, false)]!,
            baseStyle.fontSize ?? 10.5,
            maxFormulaWidth,
            styles,
          )
        else
          pw.TextSpan(
            text: run.tex ?? run.text,
            style: run.code
                ? baseStyle.copyWith(font: styles.mono, fontSize: 9)
                : run.math
                ? baseStyle.copyWith(fontStyle: pw.FontStyle.italic)
                : baseStyle.copyWith(
                    fontWeight: run.bold ? pw.FontWeight.bold : null,
                    fontStyle: run.italic ? pw.FontStyle.italic : null,
                  ),
          ),
  ];
}

pw.Widget _formulaBlock(MdBlock block, _Styles styles, double width) {
  final run = block.runs.isEmpty ? null : block.runs.first;
  final formula = run?.tex == null ? null : styles.formulas[(run!.tex!, true)];
  if (formula == null) {
    return pw.Text(run?.tex ?? plainText(block.runs), style: styles.body);
  }
  const size = 12.0;
  final factor = math.min(
    1.0,
    math.min(width / (formula.width * size), 600 / (formula.height * size)),
  );
  return pw.Image(
    styles.image(formula),
    width: formula.width * size * factor,
    height: formula.height * size * factor,
  );
}

pw.InlineSpan _formulaSpan(
  PdfFormulaImage formula,
  double size,
  double maxWidth,
  _Styles styles,
) {
  final factor = math.min(
    1.0,
    math.min(maxWidth / (formula.width * size), 100 / (formula.height * size)),
  );
  return pw.WidgetSpan(
    // PDF coordinates grow upwards: the image bottom must sit below the
    // text baseline by the formula's descent, not above it.
    baseline: -formula.depth * size * factor,
    child: pw.Image(
      styles.image(formula),
      width: formula.width * size * factor,
      height: formula.height * size * factor,
    ),
  );
}
