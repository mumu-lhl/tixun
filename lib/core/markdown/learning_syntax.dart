/// Markdown syntax extensions shared by the learning-content renderer and the
/// print exporters: single-`$`, `$$`, `\(...\)` and `\[...\]` formulas become
/// dedicated `math` / `mathblock` nodes instead of literal text.
library;

import 'package:markdown/markdown.dart' as md;

class MathInlineSyntax extends md.InlineSyntax {
  // A single-$ span is only a formula when its content carries a LaTeX
  // feature character (\ ^ _ { } = ( ) < > /) or is a bare variable
  // ($x$), a delimited number ($-1$), or a simple list/expression ($A,B,C$,
  // $a+b$). The latter accepts terms separated by operators, not prose.
  // Plain money such as "$5 and $10" has neither, so it stays
  // literal text instead of being parsed as a formula and losing its
  // `$` signs when the (invalid) formula falls back. `$$...$$`,
  // `\(...\)` and `\[...\]` are unchanged.
  MathInlineSyntax()
    : super(
        r'\$\$([^$]+?)\$\$|\$((?:[^\n$]*[\\^_{}=()<>\\/][^\n$]*?)|(?:[A-Za-z][A-Za-z0-9_]*)|(?:[A-Za-z0-9]+(?:\.[0-9]+)?(?:\s*[,;+*:|−±×÷-]\s*[A-Za-z0-9]+(?:\.[0-9]+)?)+)|(?:[+-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)))\$|\\\((.+?)\\\)|\\\[([^\]]+?)\\\]',
      );
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element.text(
        'math',
        match.group(1) ?? match.group(2) ?? match.group(3) ?? match.group(4)!,
      ),
    );
    return true;
  }
}

class MathBlockSyntax extends md.BlockSyntax {
  const MathBlockSyntax();
  @override
  RegExp get pattern => RegExp(r'^\s*(\$\$|\\\[)');
  @override
  md.Node parse(md.BlockParser parser) {
    final opening = parser.current.content.trim();
    final end = opening.startsWith(r'$$') ? r'$$' : r'\]';
    final first = opening.substring(2);
    parser.advance();
    if (first.endsWith(end)) {
      return md.Element.text('mathblock', first.substring(0, first.length - 2));
    }
    final lines = <String>[first];
    while (!parser.isDone) {
      final line = parser.current.content;
      parser.advance();
      if (line.trimRight().endsWith(end)) {
        lines.add(line.trimRight().substring(0, line.trimRight().length - 2));
        break;
      }
      lines.add(line);
    }
    return md.Element.text('mathblock', lines.join('\n'));
  }
}
