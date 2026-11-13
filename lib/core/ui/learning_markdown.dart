import 'package:material_ui/material_ui.dart';
// Markdown's theme API has not migrated to material_ui yet.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy;
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../l10n/app_strings.dart';

class MathInlineSyntax extends md.InlineSyntax {
  // A single-$ span is only a formula when its content carries a LaTeX
  // feature character (\ ^ _ { } = ( ) < > /) or is a bare variable
  // ($x$), or a fully delimited number ($-1$). Plain money such as "$5 and $10" has neither, so it stays
  // literal text instead of being parsed as a formula and losing its
  // `$` signs when the (invalid) formula falls back. `$$...$$`,
  // `\(...\)` and `\[...\]` are unchanged.
  MathInlineSyntax()
    : super(
        r'\$\$([^$]+?)\$\$|\$((?:[^\n$]*[\\^_{}=()<>\\/][^\n$]*?)|(?:[A-Za-z][A-Za-z0-9_]*)|(?:[+-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)))\$|\\\((.+?)\\\)|\\\[([^\]]+?)\\\]',
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

class MathBuilder extends MarkdownElementBuilder {
  MathBuilder({this.block = false});
  final bool block;
  @override
  bool isBlockElement() => block;
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final source = element.textContent;
    final formula = Tooltip(
      message: context.l10n.longPressToCopyLaTeX,
      child: GestureDetector(
        onLongPress: () => Clipboard.setData(ClipboardData(text: source)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(vertical: block ? 12 : 2),
          child: Math.tex(
            source,
            mathStyle: block ? MathStyle.display : MathStyle.text,
            textStyle: TextStyle(
              fontSize: block ? 19 : 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onErrorFallback: (_) => SelectableText(
              source,
              style: const TextStyle(fontFamily: 'TixunMono'),
            ),
          ),
        ),
      ),
    );
    if (block) return formula;
    // A text span lets Markdown merge math into the surrounding paragraph.
    // Returning an independent widget makes punctuation wrap as a separate run.
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: formula),
        ],
      ),
    );
  }
}

/// Inline `code` rendered as a small chip: a subtle surface background with
/// rounded corners, matching the fenced-code-block decoration. Fenced blocks
/// are left alone — their text always ends with a newline while inline code
/// never contains one, so the builder returns null there and the default
/// scrollable code-block rendering applies.
class _InlineCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (element.textContent.contains('\n')) return null;
    final colors = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              child: Text(
                element.textContent,
                style:
                    preferredStyle ??
                    const TextStyle(fontFamily: 'TixunMono', fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Intrinsic sizing keeps short columns compact and enables the Markdown
// package's horizontal scrolling. Cap long cells so prose still wraps.
class _ReadableTableColumnWidth extends IntrinsicColumnWidth {
  const _ReadableTableColumnWidth();

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) =>
      super.minIntrinsicWidth(cells, containerWidth).clamp(72, 260);

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) =>
      super.maxIntrinsicWidth(cells, containerWidth).clamp(72, 260);
}

class LearningMarkdown extends StatelessWidget {
  const LearningMarkdown(this.data, {super.key});
  final String data;
  @override
  Widget build(BuildContext context) =>
      // Keep standalone Markdown widgets themed as well as the main app.
      // ignore: deprecated_member_use
      MaterialUiCompatibilityBridge(child: Builder(builder: _buildContent));

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return SelectionArea(
      child: MarkdownBody(
        data: data,
        selectable: false,
        softLineBreak: true,
        inlineSyntaxes: [MathInlineSyntax()],
        blockSyntaxes: const [MathBlockSyntax()],
        builders: {
          'math': MathBuilder(),
          'mathblock': MathBuilder(block: true),
          'code': _InlineCodeBuilder(),
        },
        imageBuilder: (_, _, _) => Text(context.l10n.externalImageWasNotLoaded),
        onTapLink: (_, href, _) async {
          if (href == null) return;
          await Clipboard.setData(ClipboardData(text: href));
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(context.l10n.linkCopied)));
          }
        },
        styleSheet: MarkdownStyleSheet.fromTheme(legacy.Theme.of(context))
            .copyWith(
              p: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
              blockSpacing: 14,
              tableColumnWidth: const _ReadableTableColumnWidth(),
              tableScrollbarThumbVisibility: true,
              tableVerticalAlignment: TableCellVerticalAlignment.top,
              tableCellsPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              tableBody: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              tableHead: theme.textTheme.bodyLarge?.copyWith(
                height: 1.6,
                fontWeight: FontWeight.w600,
              ),
              tableBorder: TableBorder.all(
                color: theme.colorScheme.outlineVariant,
              ),
              code: TextStyle(
                fontFamily: 'TixunMono',
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
              codeblockDecoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              blockquoteDecoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                border: Border(
                  left: BorderSide(color: theme.colorScheme.primary, width: 3),
                ),
              ),
            ),
      ),
    );
  }
}
