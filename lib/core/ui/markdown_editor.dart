import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/markdown.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

import '../l10n/app_strings.dart';
import 'learning_markdown.dart';

typedef MarkdownPreviewBuilder = Widget Function(
  BuildContext context,
  String text,
);

/// The caller owns the original controller. Changes are applied only after Done.
Future<TextEditingValue?> showMarkdownEditor(
  BuildContext context, {
  required String title,
  required TextEditingValue initialValue,
  int? maxLength,
  MarkdownPreviewBuilder? previewBuilder,
}) async {
  final route = MaterialPageRoute<TextEditingValue>(
    fullscreenDialog: true,
    builder: (_) => MarkdownEditor(
      title: title,
      initialValue: initialValue,
      maxLength: maxLength,
      previewBuilder: previewBuilder,
    ),
  );
  final value = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  return value;
}

class MarkdownFullscreenButton extends StatelessWidget {
  const MarkdownFullscreenButton({
    super.key,
    required this.controller,
    required this.title,
    this.enabled = true,
    this.maxLength,
    this.previewBuilder,
    this.onApplied,
  });
  final TextEditingController controller;
  final String title;
  final bool enabled;
  final int? maxLength;
  final MarkdownPreviewBuilder? previewBuilder;
  final ValueChanged<String>? onApplied;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.markdownOpenFull,
    icon: const Icon(Icons.open_in_full_outlined),
    onPressed: !enabled
        ? null
        : () async {
            final result = await showMarkdownEditor(
              context,
              title: title,
              initialValue: controller.value,
              maxLength: maxLength,
              previewBuilder: previewBuilder,
            );
            if (result != null && context.mounted) {
              controller.value = result;
              onApplied?.call(result.text);
            }
          },
  );
}

class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.title,
    required this.initialValue,
    this.maxLength,
    this.previewBuilder,
  });
  final String title;
  final TextEditingValue initialValue;
  final int? maxLength;
  final MarkdownPreviewBuilder? previewBuilder;
  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late final HighlightTextController _text;
  final _focus = FocusNode();
  final _findFocus = FocusNode();
  final _undo = UndoHistoryController();
  final _find = TextEditingController();
  final _replace = TextEditingController();
  bool _preview = false, _search = false, _allowPop = false;

  @override
  void initState() {
    super.initState();
    _text = HighlightTextController(
      text: widget.initialValue.text,
      language: markdownLanguage,
    )..value = widget.initialValue.copyWith(composing: TextRange.empty);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _findFocus.dispose();
    _undo.dispose();
    _find.dispose();
    _replace.dispose();
    super.dispose();
  }

  Future<void> _close({bool apply = false}) async {
    if (!apply && _text.text != widget.initialValue.text) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.markdownDiscardTitle),
          content: Text(ctx.l10n.markdownDiscardMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.keepEditing),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.discardChanges),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (!mounted) return;
    final result = apply
        ? _text.value.copyWith(composing: TextRange.empty)
        : null;
    setState(() => _allowPop = true);
    Navigator.of(context).pop(result);
  }

  TextSelection get _selection {
    final selection = _text.selection;
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: _text.text.length);
    }
    return TextSelection(
      baseOffset: selection.baseOffset.clamp(0, _text.text.length),
      extentOffset: selection.extentOffset.clamp(0, _text.text.length),
    );
  }

  void _wrap(String before, String after, {String? placeholder}) {
    final selected = _selection;
    final source = _text.text;
    final content = selected.isCollapsed
        ? (placeholder ?? '')
        : selected.textInside(source);
    final inserted = '$before$content$after';
    final newText = source.replaceRange(selected.start, selected.end, inserted);
    if (widget.maxLength != null &&
        newText.characters.length > widget.maxLength!) {
      return;
    }
    final start = selected.start + before.length;
    _text.value = TextEditingValue(
      text: newText,
      selection: content.isEmpty
          ? TextSelection.collapsed(offset: start)
          : TextSelection(
              baseOffset: start,
              extentOffset: start + content.length,
            ),
    );
    _focus.requestFocus();
  }

  void _prefixLines(String prefix) {
    final selection = _selection;
    final text = _text.text;
    final start = selection.start == 0
        ? 0
        : text.lastIndexOf('\n', selection.start - 1) + 1;
    final end = selection.end;
    final body = text.substring(start, end);
    final lines = body.split('\n');
    final replacement = lines.map((line) => '$prefix$line').join('\n');
    final next = text.replaceRange(start, end, replacement);
    if (widget.maxLength != null &&
        next.characters.length > widget.maxLength!) {
      return;
    }
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + replacement.length,
      ),
    );
    _focus.requestFocus();
  }

  void _openSearch() {
    setState(() {
      _search = true;
      _preview = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _findFocus.requestFocus();
    });
  }

  void _unindent() {
    final selection = _selection;
    final text = _text.text;
    final start = selection.start == 0
        ? 0
        : text.lastIndexOf('\n', selection.start - 1) + 1;
    final body = text.substring(start, selection.end);
    final lines = body.split('\n');
    String removeIndent(String line) => line.startsWith('  ')
        ? line.substring(2)
        : line.startsWith('\t')
        ? line.substring(1)
        : line;
    final replacement = lines.map(removeIndent).join('\n');
    final removedFirst = lines.first.length - removeIndent(lines.first).length;
    final end = start + replacement.length;
    final newStart = (selection.start - removedFirst).clamp(start, end);
    _text.value = TextEditingValue(
      text: text.replaceRange(start, selection.end, replacement),
      selection: TextSelection(baseOffset: newStart, extentOffset: end),
    );
    _focus.requestFocus();
  }

  void _findNext({bool previous = false}) {
    final query = _find.text;
    if (query.isEmpty) return;
    final text = _text.text;
    final selection = _selection;
    var pos = previous
        ? (selection.start == 0
              ? -1
              : text.lastIndexOf(query, selection.start - 1))
        : text.indexOf(query, selection.end);
    if (pos < 0) pos = previous ? text.lastIndexOf(query) : text.indexOf(query);
    if (pos < 0) return;
    _text.selection = TextSelection(
      baseOffset: pos,
      extentOffset: pos + query.length,
    );
    _focus.requestFocus();
  }

  void _replaceOne() {
    final query = _find.text;
    if (query.isEmpty) return;
    final selection = _selection;
    if (selection.textInside(_text.text) != query) {
      _findNext();
      return;
    }
    final next = _text.text.replaceRange(
      selection.start,
      selection.end,
      _replace.text,
    );
    if (widget.maxLength != null &&
        next.characters.length > widget.maxLength!) {
      return;
    }
    final end = selection.start + _replace.text.length;
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: end),
    );
    _findNext();
  }

  void _replaceAll() {
    if (_find.text.isEmpty) return;
    final next = _text.text.replaceAll(_find.text, _replace.text);
    if (widget.maxLength != null &&
        next.characters.length > widget.maxLength!) {
      return;
    }
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l = context.l10n;
    return PopScope<TextEditingValue>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l.cancel,
            onPressed: _close,
            icon: const Icon(Icons.close),
          ),
          title: Text(widget.title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: l.markdownFind,
              onPressed: () {
                if (_search) {
                  setState(() => _search = false);
                } else {
                  _openSearch();
                }
              },
              icon: const Icon(Icons.search),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const Key('markdown-done'),
                onPressed: () => _close(apply: true),
                child: Text(l.markdownDone),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SegmentedButton<bool>(
                  key: const Key('markdown-mode'),
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l.markdownEdit),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.visibility_outlined),
                      label: Text(l.markdownPreview),
                    ),
                  ],
                  selected: {_preview},
                  onSelectionChanged: (value) => setState(() {
                    _preview = value.single;
                    if (_preview) _focus.unfocus();
                  }),
                ),
              ),
              if (_search && !_preview) _searchBar(),
              if (!_preview) _toolbar(),
              const Divider(height: 1),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Offstage(
                      offstage: _preview,
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(
                            LogicalKeyboardKey.keyB,
                            control: true,
                          ): () => _wrap(
                            '**',
                            '**',
                            placeholder: l.markdownSelectedText,
                          ),
                          const SingleActivator(
                            LogicalKeyboardKey.keyI,
                            control: true,
                          ): () => _wrap(
                            '*',
                            '*',
                            placeholder: l.markdownSelectedText,
                          ),
                          const SingleActivator(
                            LogicalKeyboardKey.keyF,
                            control: true,
                          ): _openSearch,
                          const SingleActivator(
                            LogicalKeyboardKey.keyS,
                            control: true,
                          ): () =>
                              _close(apply: true),
                          const SingleActivator(LogicalKeyboardKey.tab): () {
                            if (_selection.isCollapsed) {
                              _wrap('  ', '');
                            } else {
                              _prefixLines('  ');
                            }
                          },
                          const SingleActivator(
                            LogicalKeyboardKey.tab,
                            shift: true,
                          ): _unindent,
                          const SingleActivator(
                            LogicalKeyboardKey.keyK,
                            control: true,
                          ): () => _wrap(
                            '[',
                            '](${l.markdownLinkTarget})',
                            placeholder: l.markdownSelectedText,
                          ),
                        },
                        child: TextField(
                          key: const Key('markdown-source'),
                          controller: _text,
                          focusNode: _focus,
                          undoController: _undo,
                          expands: true,
                          minLines: null,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          maxLength: widget.maxLength,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(
                            fontFamily: 'TixunMono',
                            fontFamilyFallback: ['NotoSansSC'],
                            height: 1.6,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(20),
                            counterText: '',
                          ),
                        ),
                      ),
                    ),
                    if (_preview)
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _text,
                        builder: (context, value, _) => SingleChildScrollView(
                          key: const Key('markdown-preview'),
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 850),
                              child: SizedBox(
                                width: double.infinity,
                                child: value.text.isEmpty
                                    ? Text(
                                        l.markdownEmptyPreview,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      )
                                    : (widget.previewBuilder?.call(
                                            context,
                                            value.text,
                                          ) ??
                                          LearningMarkdown(value.text)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    final l = context.l10n;
    Widget button(String label, IconData icon, VoidCallback action) =>
        IconButton(
          tooltip: label,
          onPressed: action,
          icon: Icon(icon, size: 20),
        );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: _undo,
              builder: (_, value, _) => IconButton(
                tooltip: l.markdownUndo,
                onPressed: value.canUndo ? _undo.undo : null,
                icon: const Icon(Icons.undo, size: 20),
              ),
            ),
            ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: _undo,
              builder: (_, value, _) => IconButton(
                tooltip: l.markdownRedo,
                onPressed: value.canRedo ? _undo.redo : null,
                icon: const Icon(Icons.redo, size: 20),
              ),
            ),
            button(l.markdownMath, Icons.functions, _formulaMenu),
            button(l.markdownHeading, Icons.title, () => _prefixLines('## ')),
            button(
              l.markdownBold,
              Icons.format_bold,
              () => _wrap('**', '**', placeholder: l.markdownSelectedText),
            ),
            button(
              l.markdownItalic,
              Icons.format_italic,
              () => _wrap('*', '*', placeholder: l.markdownSelectedText),
            ),
            button(
              l.markdownBulletList,
              Icons.format_list_bulleted,
              () => _prefixLines('- '),
            ),
            button(
              l.markdownNumberedList,
              Icons.format_list_numbered,
              () => _prefixLines('1. '),
            ),
            button(
              l.markdownTaskList,
              Icons.checklist,
              () => _prefixLines('- [ ] '),
            ),
            button(
              l.markdownTable,
              Icons.table_chart_outlined,
              () => _wrap(
                '\n\n| ',
                ' | B |\n| --- | --- |\n| 1 | 2 |\n',
                placeholder: 'A',
              ),
            ),
            button(
              l.markdownDivider,
              Icons.horizontal_rule,
              () => _wrap('\n\n---\n\n', ''),
            ),
            button(
              l.markdownQuote,
              Icons.format_quote,
              () => _prefixLines('> '),
            ),
            button(
              l.markdownInlineCode,
              Icons.code,
              () => _wrap('`', '`', placeholder: 'code'),
            ),
            button(
              l.markdownCodeBlock,
              Icons.data_object,
              () => _wrap('```\n', '\n```', placeholder: 'code'),
            ),
            button(
              l.markdownLink,
              Icons.link,
              () => _wrap(
                '[',
                '](${l.markdownLinkTarget})',
                placeholder: l.markdownSelectedText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('markdown-find'),
                  controller: _find,
                  focusNode: _findFocus,
                  decoration: InputDecoration(labelText: l.markdownFindHint),
                  onSubmitted: (_) => _findNext(),
                ),
              ),
              IconButton(
                tooltip: l.markdownPrevious,
                onPressed: () => _findNext(previous: true),
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: l.markdownNext,
                onPressed: _findNext,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton(
                tooltip: l.markdownCloseFind,
                onPressed: () => setState(() => _search = false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('markdown-replace-text'),
                  controller: _replace,
                  decoration: InputDecoration(labelText: l.markdownReplaceHint),
                ),
              ),
              TextButton(
                onPressed: _replaceOne,
                child: Text(l.markdownReplace),
              ),
              TextButton(
                onPressed: _replaceAll,
                child: Text(l.markdownReplaceAll),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _formulaMenu() async {
    final l = context.l10n;
    final groups = <(String, List<(String, String, String)>)>[
      (
        l.markdownMathCategory,
        [
          (l.markdownMathInline, r'\(', r'\)'),
          (l.markdownMathBlock, '\n\\[\n', '\n\\]\n'),
          (l.markdownFraction, r'\(\frac{', r'}{b}\)'),
          (l.markdownRoot, r'\(\sqrt{', r'}\)'),
          (l.markdownPower, r'\(x^{', r'}\)'),
          (l.markdownSubscript, r'\(x_{', r'}\)'),
          (l.markdownIntegral, r'\(\int_{a}^{b} ', r'\,dx\)'),
          (l.markdownSum, r'\(\sum_{i=1}^{n} ', r'\)'),
          (
            l.markdownMatrix,
            r'\(\begin{pmatrix}',
            r' & b \\ c & d\end{pmatrix}\)',
          ),
          (l.markdownGreek, r'\(', r'\)'),
        ],
      ),
      (
        l.markdownPhysicsCategory,
        [
          (l.markdownEquation, r'\(F = ', r'\)'),
          (l.markdownVector, r'\(\vec{', r'}\)'),
          (l.markdownUnit, r'\(', r'\,\mathrm{m/s}\)'),
        ],
      ),
      (
        l.markdownChemistryCategory,
        [
          (l.markdownChemFormula, r'\(\mathrm{', r'}\)'),
          (l.markdownChemReaction, r'\(', r' \rightarrow 2\mathrm{H_2O}\)'),
        ],
      ),
    ];
    final selected = await showModalBottomSheet<(String, String, String)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(l.markdownMath, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(l.markdownMathHelp),
              for (final (heading, choices) in groups) ...[
                const SizedBox(height: 18),
                Text(heading, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final item in choices)
                      ActionChip(
                        label: Text(item.$1),
                        onPressed: () => Navigator.pop(ctx, item),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final (label, before, after) = selected;
    final placeholder = label == l.markdownFraction
        ? 'a'
        : label == l.markdownChemFormula
        ? 'H_2O'
        : label == l.markdownChemReaction
        ? r'2\mathrm{H_2} + \mathrm{O_2}'
        : label == l.markdownGreek
        ? r'\alpha'
        : label == l.markdownEquation
        ? 'ma'
        : label == l.markdownUnit
        ? 'v'
        : 'x';
    _wrap(before, after, placeholder: placeholder);
  }
}
