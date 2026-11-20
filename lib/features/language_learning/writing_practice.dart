import "dart:async";

import "package:dio/dio.dart";
import "package:material_ui/material_ui.dart";

import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "language_store.dart";
import "writing_ai.dart";
import "quick_lookup/quick_selection.dart";
import "writing_store.dart";

class WritingPractice extends StatefulWidget {
  const WritingPractice({
    super.key,
    required this.store,
    required this.ai,
    this.feedbackLanguage,
  });

  final LanguageLearningStore store;
  final WritingAi ai;
  final String? feedbackLanguage;

  @override
  State<WritingPractice> createState() => _WritingPracticeState();
}

class _WritingPracticeState extends State<WritingPractice> {
  final _controller = TextEditingController();
  late final _history = widget.store.writingHistory(taskId: widget.ai.task.id);
  String _saved = "";
  bool _loaded = false;
  bool _loadError = false;
  bool _saving = false;
  bool _leaving = false;
  bool _checkingExit = false;
  CancelToken? _pending;

  bool get _dirty => _controller.text != _saved;
  bool get _busy => _pending != null || _saving;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final text = await widget.store.writingDraft(taskId: widget.ai.task.id);
      if (!mounted) return;
      _controller.text = text;
      setState(() {
        _saved = text;
        _loaded = true;
        _loadError = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  @override
  void dispose() {
    _pending?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final draft = _controller.text;
    setState(() => _saving = true);
    await act(context, () async {
      if (draft.trim().isEmpty) {
        await widget.store.saveWritingDraft(draft, taskId: widget.ai.task.id);
      } else {
        await widget.store.snapshotWriting(draft, taskId: widget.ai.task.id);
      }
      if (mounted) _saved = draft;
    });
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _evaluate() async {
    final draft = _controller.text;
    if (_busy || draft.trim().isEmpty || draft.length > writingMaxLength) {
      return;
    }
    final cancel = CancelToken();
    final gloss =
        widget.feedbackLanguage ?? Localizations.localeOf(context).languageCode;
    setState(() => _pending = cancel);
    try {
      await widget.store.saveWritingDraft(draft, taskId: widget.ai.task.id);
      if (!mounted) return;
      setState(() => _saved = draft);
      await widget.ai.evaluate(
        text: draft,
        glossLanguage: gloss,
        cancel: cancel,
      );
    } catch (error) {
      if (mounted && !cancel.isCancelled) {
        await act(context, () => Future<void>.error(error));
      }
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  Future<void> _confirmExit() async {
    if (_checkingExit || _busy || _leaving) return;
    _checkingExit = true;
    final l10n = context.l10n;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.languageWritingDiscard),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.languageWritingLeave),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _checkingExit = false;
    if (leave == true) {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.maybePop(context);
      });
    }
  }

  void _openVersion(WritingHistory entry) => showDialog<void>(
    context: context,
    builder: (_) => _WritingVersionDialog(entry: entry, store: widget.store),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context).textTheme;
    return PopScope(
      canPop: _leaving || !_dirty || _pending != null,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) unawaited(_confirmExit());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.ai.task.passage == null
                ? l10n.languageWriting
                : l10n.languageContinuation,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 740),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.languageWritingTask, style: theme.headlineSmall),
                    const SizedBox(height: 8),
                    if (widget.ai.task.title case final title?)
                      Text(title, style: theme.titleLarge),
                    if (widget.ai.task.passage case final passage?) ...[
                      SelectableText(passage),
                      const SizedBox(height: 12),
                    ],
                    SelectableText(widget.ai.task.prompt),
                    const SizedBox(height: 12),
                    if (_loadError)
                      OutlinedButton(
                        onPressed: _load,
                        child: Text(l10n.couldNotLoadTapTo),
                      )
                    else if (!_loaded)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      TextField(
                        controller: _controller,
                        minLines: 6,
                        maxLines: 12,
                        maxLength: writingMaxLength,
                        readOnly: _busy,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: l10n.draft),
                      ),
                      if (_dirty) Text(l10n.languageWritingUnsaved),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: !_dirty || _busy ? null : _save,
                            child: Text(l10n.languageWritingSave),
                          ),
                          FilledButton(
                            onPressed: _busy || _controller.text.trim().isEmpty
                                ? null
                                : _evaluate,
                            child: Text(l10n.languageWritingEvaluate),
                          ),
                          if (_pending case final cancel?)
                            TextButton(
                              onPressed: cancel.isCancelled
                                  ? null
                                  : () => setState(() => cancel.cancel()),
                              child: Text(l10n.cancel),
                            ),
                        ],
                      ),
                      if (_busy) const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(l10n.languageWritingPrivacy),
                      const SizedBox(height: 24),
                      Text(
                        l10n.languageWritingVersions,
                        style: theme.titleLarge,
                      ),
                      StreamBuilder<List<WritingHistory>>(
                        stream: _history,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Text(l10n.couldNotCompleteTheAction);
                          }
                          final versions = snapshot.data;
                          if (versions == null) return const SizedBox.shrink();
                          if (versions.isEmpty) {
                            return Text(l10n.languageWritingNoVersions);
                          }
                          return Column(
                            children: [
                              for (final entry in versions)
                                ListTile(
                                  title: Text(
                                    entry.version.content.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    entry.evaluation == null
                                        ? l10n.languageWritingNoEvaluation
                                        : entry.evaluation!.isMock
                                        ? l10n.languageAiMockSource
                                        : l10n.languageWritingScores(
                                            entry.evaluation!.taskScore,
                                            entry.evaluation!.organizationScore,
                                            entry.evaluation!.languageScore,
                                          ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _openVersion(entry),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WritingVersionDialog extends StatefulWidget {
  const _WritingVersionDialog({required this.entry, required this.store});
  final WritingHistory entry;
  final LanguageLearningStore store;

  @override
  State<_WritingVersionDialog> createState() => _WritingVersionDialogState();
}

class _WritingVersionDialogState extends State<_WritingVersionDialog> {
  late final _annotations = widget.store.writingNotes(widget.entry.version.id);
  LearningWritingNote? _active;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final evaluation = entry.evaluation;
    final version = entry.version;
    final note = _active;
    final content = version.content;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.languageWritingSavedVersion),
      content: SizedBox(
        width: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note == null)
              quickSelectableText(content)
            else
              SelectableText.rich(
                contextMenuBuilder: quickSelectionToolbar,
                TextSpan(
                  children: [
                    TextSpan(text: content.substring(0, note.startOffset)),
                    TextSpan(
                      text: content.substring(note.startOffset, note.endOffset),
                      style: TextStyle(
                        backgroundColor: colors.secondaryContainer,
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                    TextSpan(text: content.substring(note.endOffset)),
                  ],
                ),
              ),
            const Divider(),
            if (evaluation == null)
              Text(l10n.languageWritingNoEvaluation)
            else ...[
              Text(
                evaluation.isMock
                    ? l10n.languageAiMockSource
                    : l10n.languageAiSource(evaluation.model),
              ),
              if (!evaluation.isMock)
                Text(
                  l10n.languageWritingScores(
                    evaluation.taskScore,
                    evaluation.organizationScore,
                    evaluation.languageScore,
                  ),
                ),
              Text(l10n.languageWritingReference),
              const SizedBox(height: 8),
              quickSelectableText(evaluation.summary),
              FutureBuilder<List<LearningWritingNote>>(
                future: _annotations,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(l10n.couldNotCompleteTheAction);
                  }
                  return Column(
                    children: [
                      for (final item
                          in snapshot.data ?? const <LearningWritingNote>[])
                        if (item.startOffset >= 0 &&
                            item.endOffset > item.startOffset &&
                            item.endOffset <= content.length)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item.kind == "issue"
                                  ? l10n.languageWritingIssue
                                  : l10n.languageWritingSuggestion,
                            ),
                            subtitle: Text(
                              "${content.substring(item.startOffset, item.endOffset)}\n${item.comment}",
                            ),
                            selected: item == note,
                            onTap: () => setState(() => _active = item),
                          ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
