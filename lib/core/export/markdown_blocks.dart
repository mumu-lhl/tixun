/// Flattens learning Markdown into the block/run model used by the print
/// exporters. The model keeps only what a printed page can show: block type,
/// nesting level, inline emphasis, code and tables. Maths retains its source
/// alongside a readable text fallback for the exporters.
library;

import 'package:markdown/markdown.dart' as md;

import '../markdown/learning_syntax.dart';
import 'latex_text.dart';

enum MdBlockKind {
  heading,
  paragraph,
  orderList,
  bulletList,
  formula,
  code,
  table,
  rule,
}

class MdRun {
  const MdRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.math = false,
    this.tex,
  });

  final String text;
  final bool bold, italic, code, math;
  final String? tex;

  /// Text used where emphasis cannot be applied.
  String get plain => text;

  MdRun merge(MdRun other) => MdRun(
    text + other.text,
    bold: bold && other.bold,
    italic: italic && other.italic,
    code: code && other.code,
    math: math && other.math,
  );
}

class MdRow {
  const MdRow(this.cells, {this.header = false});
  final List<List<MdRun>> cells;
  final bool header;
}

class MdBlock {
  const MdBlock(
    this.kind, {
    this.level = 0,
    this.marker = '',
    this.runs = const [],
    this.rows = const [],
    this.language = '',
    this.quote = false,
    this.listDepth = 0,
  });

  final MdBlockKind kind;

  /// Heading level (1-6) or ordered-list start number.
  final int level;
  final String marker;
  final List<MdRun> runs;
  final List<MdRow> rows;
  final String language;
  final bool quote;
  final int listDepth;

  List<MdRun> get allRuns => [
    for (final row in rows)
      for (final cell in row.cells) ...cell,
    ...runs,
  ];
}

class MdParsedDocument {
  const MdParsedDocument(this.blocks);
  final List<MdBlock> blocks;

  bool get isEmpty => blocks.every(
    (block) => switch (block.kind) {
      MdBlockKind.rule => true,
      MdBlockKind.table => block.rows.isEmpty,
      _ => plainText(block.runs).trim().isEmpty,
    },
  );
}

/// Text of one run list, ignoring emphasis markers.
String plainText(Iterable<MdRun> runs) => runs.map((run) => run.text).join();

/// Parses [source] with the same syntax extensions the app renders with.
MdParsedDocument parseLearningMarkdown(String source) {
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    inlineSyntaxes: [MathInlineSyntax()],
    blockSyntaxes: const [MathBlockSyntax()],
  );
  final blocks = <MdBlock>[];
  _collectBlocks(
    document.parseLines(_splitLines(source)),
    blocks,
    quote: false,
  );
  return MdParsedDocument(blocks);
}

List<String> _splitLines(String source) =>
    source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

void _collectBlocks(
  List<md.Node> nodes,
  List<MdBlock> out, {
  required bool quote,
  int listDepth = 0,
  int headingShift = 0,
}) {
  for (final node in nodes) {
    if (node is md.Text) {
      final runs = _runs([node]);
      if (plainText(runs).trim().isEmpty) continue;
      out.add(MdBlock(MdBlockKind.paragraph, runs: runs, quote: quote));
      continue;
    }
    if (node is! md.Element) continue;
    switch (node.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final level = (int.parse(node.tag.substring(1)) + headingShift).clamp(
          1,
          6,
        );
        out.add(
          MdBlock(
            MdBlockKind.heading,
            level: level,
            runs: _runs(node.children ?? const []),
            quote: quote,
          ),
        );
      case 'p':
        final runs = _runs(node.children ?? const []);
        if (plainText(runs).trim().isEmpty) continue;
        out.add(MdBlock(MdBlockKind.paragraph, runs: runs, quote: quote));
      case 'blockquote':
        _collectBlocks(
          node.children ?? const [],
          out,
          quote: true,
          headingShift: headingShift + 1,
        );
      case 'ul':
      case 'ol':
        _collectList(node, out, quote: quote, depth: listDepth + 1);
      case 'pre':
        final codes = (node.children ?? const []).whereType<md.Element>();
        final code = codes.isEmpty ? null : codes.first;
        final text = (code?.textContent ?? node.textContent).replaceFirst(
          RegExp(r'\n$'),
          '',
        );
        out.add(
          MdBlock(
            MdBlockKind.code,
            runs: [MdRun(text)],
            language: _languageOf(code?.attributes['class'] ?? ''),
            quote: quote,
          ),
        );
      case 'table':
        final rows = _tableRows(node);
        if (rows.isNotEmpty) {
          out.add(MdBlock(MdBlockKind.table, rows: rows, quote: quote));
        }
      case 'hr':
        out.add(MdBlock(MdBlockKind.rule, quote: quote));
      case 'mathblock':
        out.add(
          MdBlock(
            MdBlockKind.formula,
            runs: _mathRuns(node.textContent),
            quote: quote,
          ),
        );
      default:
        // A block element we do not model: keep its text so nothing is lost.
        final runs = _runs(node.children ?? const []);
        if (plainText(runs).trim().isEmpty) continue;
        out.add(MdBlock(MdBlockKind.paragraph, runs: runs, quote: quote));
    }
  }
}

String _languageOf(String? classes) {
  if (classes == null) return '';
  for (final token in classes.split(' ')) {
    if (token.startsWith('language-')) {
      return token.substring('language-'.length);
    }
  }
  return '';
}

void _collectList(
  md.Element list,
  List<MdBlock> out, {
  required bool quote,
  required int depth,
}) {
  final ordered = list.tag == 'ol';
  var number = int.tryParse(list.attributes['start'] ?? '') ?? 1;
  for (final item in (list.children ?? const []).whereType<md.Element>()) {
    if (item.tag != 'li') continue;
    final inline = <md.Node>[];
    final nested = <md.Element>[];
    for (final child in item.children ?? const <md.Node>[]) {
      if (child is md.Element && (child.tag == 'ul' || child.tag == 'ol')) {
        nested.add(child);
        continue;
      }
      // A `<p>` inside a loose list item still belongs to that item.
      if (child is md.Element && child.tag == 'p') {
        inline.addAll(child.children ?? const []);
        continue;
      }
      inline.add(child);
    }
    final marker = ordered ? '${number++}.' : '•';
    final runs = _runs(inline);
    out.add(
      MdBlock(
        ordered ? MdBlockKind.orderList : MdBlockKind.bulletList,
        level: ordered ? number - 1 : 0,
        marker: marker,
        runs: runs,
        quote: quote,
        listDepth: depth,
      ),
    );
    for (final child in nested) {
      _collectList(child, out, quote: quote, depth: depth + 1);
    }
  }
}

List<MdRow> _tableRows(md.Element table) {
  final rows = <MdRow>[];
  void visit(md.Element element, {required bool header}) {
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is! md.Element) continue;
      if (child.tag == 'tr') {
        final cells = <List<MdRun>>[];
        var isHeader = header;
        for (final cell
            in (child.children ?? const []).whereType<md.Element>()) {
          if (cell.tag == 'th') isHeader = true;
          cells.add(_runs(cell.children ?? const []));
        }
        if (cells.isNotEmpty) rows.add(MdRow(cells, header: isHeader));
      } else if (child.tag == 'thead' ||
          child.tag == 'tbody' ||
          child.tag == 'tfoot') {
        visit(child, header: header || child.tag == 'thead');
      }
    }
  }

  visit(table, header: false);
  return rows;
}

List<MdRun> _mathRuns(String tex) {
  final text = latexToText(tex);
  if (text.isEmpty) return const [];
  return [MdRun(text, math: true, tex: tex)];
}

List<MdRun> _runs(List<md.Node> nodes) {
  final runs = <MdRun>[];

  void add(MdRun run) {
    if (run.text.isEmpty) return;
    final last = runs.isEmpty ? null : runs.last;
    if (last != null && _sameStyle(last, run)) {
      runs[runs.length - 1] = last.merge(run);
      return;
    }
    runs.add(run);
  }

  void visit(
    md.Node node, {
    bool bold = false,
    bool italic = false,
    bool code = false,
  }) {
    if (node is md.Text) {
      add(MdRun(node.text, bold: bold, italic: italic, code: code));
      return;
    }
    if (node is! md.Element) return;
    switch (node.tag) {
      case 'strong':
        node.children?.forEach(
          (child) => visit(child, bold: true, italic: italic, code: code),
        );
      case 'em':
        node.children?.forEach(
          (child) => visit(child, bold: bold, italic: true, code: code),
        );
      case 'del':
        node.children?.forEach(
          (child) => visit(child, bold: bold, italic: italic, code: code),
        );
      case 'code':
        add(MdRun(node.textContent, bold: bold, italic: italic, code: true));
      case 'math':
        add(
          MdRun(
            latexToText(node.textContent),
            math: true,
            tex: node.textContent,
          ),
        );
      case 'mathblock':
        add(
          MdRun(
            latexToText(node.textContent),
            math: true,
            tex: node.textContent,
          ),
        );
      case 'br':
        add(const MdRun('\n'));
      case 'img':
        final alt = node.attributes['alt'] ?? '';
        if (alt.isNotEmpty) add(MdRun(alt, bold: bold, italic: italic));
      case 'a':
        final href = node.attributes['href'] ?? '';
        node.children?.forEach(
          (child) => visit(child, bold: bold, italic: italic, code: code),
        );
        if (href.startsWith('http')) add(MdRun(' ($href)', italic: true));
      default:
        node.children?.forEach(
          (child) => visit(child, bold: bold, italic: italic, code: code),
        );
    }
  }

  for (final node in nodes) {
    visit(node);
  }
  // A paragraph must never end with trailing spaces that look like a gap.
  if (runs.isNotEmpty) {
    final last = runs.last;
    final trimmed = last.text.replaceFirst(RegExp(r'[ \t]+$'), '');
    if (trimmed.isEmpty) {
      runs.removeLast();
    } else if (trimmed != last.text) {
      runs[runs.length - 1] = MdRun(
        trimmed,
        bold: last.bold,
        italic: last.italic,
        code: last.code,
        math: last.math,
        tex: last.tex,
      );
    }
  }
  return runs;
}

bool _sameStyle(MdRun a, MdRun b) =>
    a.tex == null &&
    b.tex == null &&
    a.bold == b.bold &&
    a.italic == b.italic &&
    a.code == b.code &&
    a.math == b.math;
