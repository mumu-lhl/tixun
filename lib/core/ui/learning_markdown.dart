import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../l10n/app_strings.dart';

class MathInlineSyntax extends md.InlineSyntax {
  MathInlineSyntax()
    : super(r'\$\$([^$]+?)\$\$|\$([^\n$]+?)\$|\\\((.+?)\\\)|\\\[([^\]]+?)\\\]');
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
      message: '长按复制 LaTeX',
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

class LearningMarkdown extends StatelessWidget {
  const LearningMarkdown(this.data, {super.key});
  final String data;
  @override
  Widget build(BuildContext context) {
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
        },
        imageBuilder: (_, _, _) => Text(context.tr("[外部图片未自动加载]")),
        onTapLink: (_, href, _) async {
          if (href == null) return;
          await Clipboard.setData(ClipboardData(text: href));
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(context.tr("链接已复制"))));
          }
        },
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
          blockSpacing: 14,
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
