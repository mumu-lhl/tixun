part of "markdown_editor.dart";

extension _MarkdownEditorTools on _MarkdownEditorState {
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
        ? (placeholder ?? "")
        : selected.textInside(source);
    final inserted = "$before$content$after";
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
        : text.lastIndexOf("\n", selection.start - 1) + 1;
    final end = selection.end;
    final body = text.substring(start, end);
    final lines = body.split("\n");
    final replacement = lines.map((line) => "$prefix$line").join("\n");
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

  void _unindent() {
    final selection = _selection;
    final text = _text.text;
    final start = selection.start == 0
        ? 0
        : text.lastIndexOf("\n", selection.start - 1) + 1;
    final body = text.substring(start, selection.end);
    final lines = body.split("\n");
    String removeIndent(String line) => line.startsWith("  ")
        ? line.substring(2)
        : line.startsWith("\t")
        ? line.substring(1)
        : line;
    final replacement = lines.map(removeIndent).join("\n");
    final removedFirst = lines.first.length - removeIndent(lines.first).length;
    final end = start + replacement.length;
    final newStart = (selection.start - removedFirst).clamp(start, end);
    _text.value = TextEditingValue(
      text: text.replaceRange(start, selection.end, replacement),
      selection: TextSelection(baseOffset: newStart, extentOffset: end),
    );
    _focus.requestFocus();
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
            button(l.markdownHeading, Icons.title, () => _prefixLines("## ")),
            button(
              l.markdownBold,
              Icons.format_bold,
              () => _wrap("**", "**", placeholder: l.markdownSelectedText),
            ),
            button(
              l.markdownItalic,
              Icons.format_italic,
              () => _wrap("*", "*", placeholder: l.markdownSelectedText),
            ),
            button(
              l.markdownBulletList,
              Icons.format_list_bulleted,
              () => _prefixLines("- "),
            ),
            button(
              l.markdownNumberedList,
              Icons.format_list_numbered,
              () => _prefixLines("1. "),
            ),
            button(
              l.markdownTaskList,
              Icons.checklist,
              () => _prefixLines("- [ ] "),
            ),
            button(
              l.markdownTable,
              Icons.table_chart_outlined,
              () => _wrap(
                "\n\n| ",
                " | B |\n| --- | --- |\n| 1 | 2 |\n",
                placeholder: "A",
              ),
            ),
            button(
              l.markdownDivider,
              Icons.horizontal_rule,
              () => _wrap("\n\n---\n\n", ""),
            ),
            button(
              l.markdownQuote,
              Icons.format_quote,
              () => _prefixLines("> "),
            ),
            button(
              l.markdownInlineCode,
              Icons.code,
              () => _wrap("`", "`", placeholder: "code"),
            ),
            button(
              l.markdownCodeBlock,
              Icons.data_object,
              () => _wrap("```\n", "\n```", placeholder: "code"),
            ),
            button(
              l.markdownLink,
              Icons.link,
              () => _wrap(
                "[",
                "](${l.markdownLinkTarget})",
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
                  key: const Key("markdown-find"),
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
                onPressed: _closeSearch,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key("markdown-replace-text"),
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
          (l.markdownMathInline, r"\(", r"\)"),
          (l.markdownMathBlock, "\n\\[\n", "\n\\]\n"),
          (l.markdownFraction, r"\(\frac{", r"}{b}\)"),
          (l.markdownRoot, r"\(\sqrt{", r"}\)"),
          (l.markdownPower, r"\(x^{", r"}\)"),
          (l.markdownSubscript, r"\(x_{", r"}\)"),
          (l.markdownIntegral, r"\(\int_{a}^{b} ", r"\,dx\)"),
          (l.markdownSum, r"\(\sum_{i=1}^{n} ", r"\)"),
          (
            l.markdownMatrix,
            r"\(\begin{pmatrix}",
            r" & b \\ c & d\end{pmatrix}\)",
          ),
          (l.markdownGreek, r"\(", r"\)"),
        ],
      ),
      (
        l.markdownPhysicsCategory,
        [
          (l.markdownEquation, r"\(F = ", r"\)"),
          (l.markdownVector, r"\(\vec{", r"}\)"),
          (l.markdownUnit, r"\(", r"\,\mathrm{m/s}\)"),
        ],
      ),
      (
        l.markdownChemistryCategory,
        [
          (l.markdownChemFormula, r"\(\mathrm{", r"}\)"),
          (l.markdownChemReaction, r"\(", r" \rightarrow 2\mathrm{H_2O}\)"),
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
        ? "a"
        : label == l.markdownChemFormula
        ? "H_2O"
        : label == l.markdownChemReaction
        ? r"2\mathrm{H_2} + \mathrm{O_2}"
        : label == l.markdownGreek
        ? r"\alpha"
        : label == l.markdownEquation
        ? "ma"
        : label == l.markdownUnit
        ? "v"
        : "x";
    _wrap(before, after, placeholder: placeholder);
  }
}
