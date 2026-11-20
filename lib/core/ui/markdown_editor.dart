import "dart:async";

import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "package:val_highlight/languages/markdown.dart";
import "package:val_highlight_flutter/val_highlight_flutter.dart";

import "../l10n/app_strings.dart";
import "learning_markdown.dart";

part "markdown_editor_tools.dart";

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

  void _closeSearch() => setState(() => _search = false);

  void _openSearch() {
    setState(() {
      _search = true;
      _preview = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _findFocus.requestFocus();
    });
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
        if (!didPop) unawaited(_close());
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
                key: const Key("markdown-done"),
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
                  key: const Key("markdown-mode"),
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
                            "**",
                            "**",
                            placeholder: l.markdownSelectedText,
                          ),
                          const SingleActivator(
                            LogicalKeyboardKey.keyI,
                            control: true,
                          ): () => _wrap(
                            "*",
                            "*",
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
                              _wrap("  ", "");
                            } else {
                              _prefixLines("  ");
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
                            "[",
                            "](${l.markdownLinkTarget})",
                            placeholder: l.markdownSelectedText,
                          ),
                        },
                        child: TextField(
                          key: const Key("markdown-source"),
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
                            fontFamily: "TixunMono",
                            fontFamilyFallback: ["NotoSansSC"],
                            height: 1.6,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(20),
                            counterText: "",
                          ),
                        ),
                      ),
                    ),
                    if (_preview)
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _text,
                        builder: (context, value, _) => SingleChildScrollView(
                          key: const Key("markdown-preview"),
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
}
