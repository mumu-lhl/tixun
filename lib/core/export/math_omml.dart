/// Converts supported LaTeX to editable Office Math. Unsupported constructs
/// return null so callers can preserve the original source instead of silently
/// changing its meaning.
library;

import 'package:val_latex_flutter/val_latex_flutter.dart' as math;

String? latexToOmml(String source) {
  final parsed = math.parseLatex(
    source,
    options: const math.ParseOptions(strict: math.Strict.ignore),
  );
  if (parsed.hasErrors || parsed.incomplete) return null;
  try {
    return '<m:oMath>${_node(parsed.root)}</m:oMath>';
  } on _Unsupported {
    return null;
  }
}

class _Unsupported implements Exception {}

String _escape(String s) => s.runes
    .where((c) => c >= 0x20 || c == 0x09 || c == 0x0a || c == 0x0d)
    .map(
      (c) => switch (c) {
        0x26 => '&amp;',
        0x3c => '&lt;',
        0x3e => '&gt;',
        0x22 => '&quot;',
        _ => String.fromCharCode(c),
      },
    )
    .join();
String _text(String s) =>
    '<m:r><m:t xml:space="preserve">${_escape(s)}</m:t></m:r>';
String _element(String name, math.MathNode? node) =>
    '<m:$name>${node == null ? '' : _node(node)}</m:$name>';
String _delimited(String left, String right, String content) =>
    '<m:d><m:dPr><m:begChr m:val="${_escape(left == '.' ? '' : left)}"/><m:endChr m:val="${_escape(right == '.' ? '' : right)}"/></m:dPr><m:e>$content</m:e></m:d>';

String _node(math.MathNode node) {
  switch (node) {
    case math.RowNode():
      return node.nodes.map(_node).join();
    case math.SymbolNode():
      return _text(node.text);
    case math.TextNode():
      return _text(node.text);
    case math.SpaceNode():
      return _text(' ');
    case math.FracNode():
      final frac =
          '<m:f><m:fPr>${node.hasBar ? '' : '<m:type m:val="noBar"/>'}</m:fPr>${_element('num', node.numerator)}${_element('den', node.denominator)}</m:f>';
      return node.leftDelim == null && node.rightDelim == null
          ? frac
          : _delimited(node.leftDelim ?? '', node.rightDelim ?? '', frac);
    case math.SqrtNode():
      return '<m:rad><m:radPr>${node.index == null ? '<m:degHide m:val="1"/>' : ''}</m:radPr>${_element('deg', node.index)}${_element('e', node.body)}</m:rad>';
    case math.ScriptsNode():
      if (node.preSub != null || node.preSup != null) throw _Unsupported();
      final op = node.base;
      if (op is math.OpNode &&
          op.isSymbol &&
          op.body is math.SymbolNode &&
          op.limitsByDefault) {
        final symbol = (op.body as math.SymbolNode).text;
        return '<m:nary><m:naryPr><m:chr m:val="${_escape(symbol)}"/>'
            '${node.sub == null ? '<m:subHide m:val="1"/>' : ''}'
            '${node.sup == null ? '<m:supHide m:val="1"/>' : ''}'
            '</m:naryPr>${_element('sub', node.sub)}${_element('sup', node.sup)}<m:e/></m:nary>';
      }
      final type = node.sub != null && node.sup != null
          ? 'sSubSup'
          : node.sub != null
          ? 'sSub'
          : 'sSup';
      return '<m:$type>${_element('e', node.base)}${node.sub == null ? '' : _element('sub', node.sub)}${node.sup == null ? '' : _element('sup', node.sup)}</m:$type>';
    case math.OpNode():
      return _node(node.body);
    case math.LeftRightNode():
      return _delimited(node.left, node.right, _node(node.body));
    case math.AccentNode():
      if (node.under || node.accent.length != 1) throw _Unsupported();
      return '<m:acc><m:accPr><m:chr m:val="${_escape(node.accent)}"/></m:accPr>${_element('e', node.base)}</m:acc>';
    case math.LineNode():
      return '<m:bar><m:barPr><m:pos m:val="${node.over ? 'top' : 'bot'}"/></m:barPr>${_element('e', node.body)}</m:bar>';
    case math.OverUnderNode():
      var result = _node(node.base);
      if (node.under != null) {
        result =
            '<m:limLow><m:e>$result</m:e>${_element('lim', node.under)}</m:limLow>';
      }
      if (node.over != null) {
        result =
            '<m:limUpp><m:e>$result</m:e>${_element('lim', node.over)}</m:limUpp>';
      }
      return result;
    case math.ExtArrowNode():
      final arrow = switch (node.command) {
        r'\xrightarrow' => '→',
        r'\xleftarrow' => '←',
        r'\xrightleftharpoons' => '⇌',
        r'\xleftrightharpoons' => '⇋',
        _ => throw _Unsupported(),
      };
      var result = _text(arrow);
      if (node.below != null) {
        result =
            '<m:limLow><m:e>$result</m:e>${_element('lim', node.below)}</m:limLow>';
      }
      if (node.above != null) {
        result =
            '<m:limUpp><m:e>$result</m:e>${_element('lim', node.above)}</m:limUpp>';
      }
      return result;
    case math.StyleNode():
      return _node(node.body);
    case math.TextGroupNode():
      return _node(node.body);
    case math.FontNode():
      final style = switch (node.font) {
        'mathrm' || 'textrm' || 'textup' => '<m:sty m:val="p"/>',
        'mathbf' || 'textbf' => '<m:sty m:val="b"/>',
        'mathit' || 'textit' => '<m:sty m:val="i"/>',
        'boldsymbol' => '<m:sty m:val="bi"/>',
        'mathbb' => '<m:scr m:val="double-struck"/>',
        'mathcal' || 'mathscr' => '<m:scr m:val="script"/>',
        'mathfrak' => '<m:scr m:val="fraktur"/>',
        'mathsf' || 'textsf' => '<m:scr m:val="sans-serif"/>',
        'mathtt' || 'texttt' => '<m:scr m:val="monospace"/>',
        'mathnormal' || 'textnormal' => '',
        _ => throw _Unsupported(),
      };
      final body = _node(node.body);
      if (style.isNotEmpty && body.contains('<m:rPr>')) {
        throw _Unsupported();
      }
      return style.isEmpty
          ? body
          : body.replaceAll('<m:r>', '<m:r><m:rPr>$style</m:rPr>');
    case math.ClassNode():
      return _node(node.body);
    case math.ArrayNode():
      if (node.linesBelow.isNotEmpty ||
          node.rows.any(
            (row) => row.linesAbove.isNotEmpty || row.tag != null,
          )) {
        throw _Unsupported();
      }
      final rows = node.rows
          .map(
            (row) =>
                '<m:mr>${row.cells.map((cell) => _element('e', cell)).join()}</m:mr>',
          )
          .join();
      final matrix = '<m:m>$rows</m:m>';
      return node.leftDelim == null && node.rightDelim == null
          ? matrix
          : _delimited(node.leftDelim ?? '', node.rightDelim ?? '', matrix);
    default:
      throw _Unsupported();
  }
}
