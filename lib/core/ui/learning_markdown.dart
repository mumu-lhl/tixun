import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:val_latex_flutter/val_latex_flutter.dart';

import '../l10n/app_strings.dart';
import '../markdown/learning_syntax.dart';

export '../markdown/learning_syntax.dart';

Widget _math(BuildContext context, String source, {bool block = false}) {
  return Tooltip(
    message: context.l10n.longPressToCopyLaTeX,
    child: GestureDetector(
      onLongPress: () => Clipboard.setData(ClipboardData(text: source)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(vertical: block ? 12 : 2),
        child: Math.tex(
          source,
          displayMode: block,
          block: false,
          wrap: false,
          overflow: MathOverflow.visible,
          parseOptions: const ParseOptions(
            strict: Strict.ignore,
            streaming: true,
          ),
          textStyle: TextStyle(
            fontSize: block ? 19 : 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onError: (_, _) => SelectableText(
            source,
            style: const TextStyle(fontFamily: 'TixunMono'),
          ),
        ),
      ),
    ),
  );
}

class _MathBlock extends MarkdownBlockSyntax {
  const _MathBlock(this.prefix);
  @override
  final String prefix;
  @override
  String get type =>
      prefix == r'$$' ? 'tixun-dollar-math' : 'tixun-bracket-math';
  @override
  MarkdownBlockMatch? parse(List<String> lines, int startLine) {
    final end = prefix == r'$$' ? r'$$' : r'\]';
    final first = lines[startLine].trim().substring(2);
    if (first.endsWith(end)) {
      return MarkdownBlockMatch(
        node: MdCustomBlock(
          type: type,
          body: first.substring(0, first.length - 2),
        ),
        endLine: startLine + 1,
      );
    }
    final body = <String>[first];
    var next = startLine + 1;
    var closed = false;
    while (next < lines.length) {
      final line = lines[next++].trimRight();
      if (line.endsWith(end)) {
        body.add(line.substring(0, line.length - 2));
        closed = true;
        break;
      }
      body.add(lines[next - 1]);
    }
    return MarkdownBlockMatch(
      node: MdCustomBlock(type: type, body: body.join('\n'), closed: closed),
      endLine: next,
    );
  }
}

// Disable the package's dollar-math heuristic: its price detection differs
// from the syntax used by existing notes and the print exporters. Mask escape
// sequences before Markdown removes them, then use the shared inline syntax.
final _mathPattern = InlinePattern(
  pattern: RegExp('(?<!\\\\)(?:${MathInlineSyntax.expression})'),
  scopes: MarkdownComponent.allScopes,
  builder: (context, match, style) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: _math(
      context,
      match.group(1) ?? match.group(2) ?? match.group(3) ?? match.group(4)!,
    ),
  ),
);
final _escapedDollarPattern = InlinePattern(
  pattern: RegExp(r'(?<!\\)((?:\\\\)*)\\\$'),
  scopes: MarkdownComponent.allScopes,
  builder: (context, match, style) =>
      TextSpan(text: '${r'\' * (match.group(1)!.length ~/ 2)}\$', style: style),
);
final _escapedSlashMathPattern = InlinePattern(
  pattern: RegExp('${r'(?<!\\)((?:\\\\)+)(?:'}${MathInlineSyntax.expression})'),
  scopes: MarkdownComponent.allScopes,
  builder: (context, match, style) => TextSpan(
    text: r'\' * (match.group(1)!.length ~/ 2),
    style: style,
    children: [
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _math(
          context,
          match.group(2) ?? match.group(3) ?? match.group(4) ?? match.group(5)!,
        ),
      ),
    ],
  ),
);
final _mathBlocks = [
  for (final syntax in [const _MathBlock(r'$$'), const _MathBlock(r'\[')])
    MarkdownBlockComponent(
      syntax: syntax,
      builder: (context, node, config) =>
          _math(context, node.body, block: true),
    ),
];

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
  const LearningMarkdown(
    this.data, {
    this.visualBuilder,
    this.streaming = false,
    super.key,
  });
  final String data;
  final Widget? Function(Uri source)? visualBuilder;
  final bool streaming;
  @override
  Widget build(BuildContext context) => _buildContent(context);

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return SelectionArea(
      child: GptMarkdown(
        data,
        animation: streaming
            ? GptMarkdownAnimation.typewriter
            : GptMarkdownAnimation.none,
        isStreaming: streaming,
        charactersPerSecond: 90,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
        html: false,
        autolink: false,
        inlinePatterns: [
          _escapedDollarPattern,
          _escapedSlashMathPattern,
          _mathPattern,
        ],
        blockComponents: _mathBlocks,
        inlineLatexBuilder: (details) =>
            details.asWidgetSpan(_math(details.context, details.source)),
        blockLatexBuilder: (details) =>
            _math(details.context, details.source, block: true),
        inlineCodeBuilder: (context, code, style, codeStyle) => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            child: Text(code, style: style),
          ),
        ),
        imageBuilder: (context, url, width, height) {
          final uri = Uri.tryParse(url);
          return (uri == null ? null : visualBuilder?.call(uri)) ??
              Text(context.l10n.externalImageWasNotLoaded);
        },
        onLinkTap: (url, _) async {
          await Clipboard.setData(ClipboardData(text: url));
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(context.l10n.linkCopied)));
          }
        },
        styleSheet: GptMarkdownStyleSheet(
          blockSpacing: 14,
          table: TableStyle(
            columnWidth: const _ReadableTableColumnWidth(),
            cellPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            borderColor: theme.colorScheme.outlineVariant,
          ),
          codeBlock: CodeBlockStyle(
            backgroundColor: theme.colorScheme.surfaceContainer,
            borderRadius: const Radius.circular(10),
            fontFamily: 'TixunMono',
            fontSize: 14,
          ),
        ),
        inlineCodeStyle: InlineCodeStyle(
          fontFamily: 'TixunMono',
          backgroundColor: theme.colorScheme.surfaceContainer,
          borderRadius: const Radius.circular(6),
        ),
      ),
    );
  }
}
