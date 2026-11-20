import "package:dio/dio.dart";
import "package:material_ui/material_ui.dart";

import "language_layout.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/app_menu.dart";
import "../../core/ui/actions.dart";
import "sentence_content.dart";
import "writing_ai.dart";
import "writing_practice.dart";
import "writing_store.dart";
import "writing_task_ai.dart";

class WritingLab extends StatefulWidget {
  const WritingLab({super.key, required this.ai, this.glossLanguage});

  final WritingTaskAi ai;
  final String? glossLanguage;

  @override
  State<WritingLab> createState() => _WritingLabState();
}

class _WritingLabState extends State<WritingLab> {
  late final _tasks = widget.ai.store.savedWritingTasks();
  CancelToken? _pending;
  bool _choosing = false;

  @override
  void dispose() {
    _pending?.cancel();
    super.dispose();
  }

  Future<void> _open(WritingTask task) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WritingPractice(
        store: widget.ai.store,
        feedbackLanguage: widget.glossLanguage,
        ai: WritingAi(
          store: widget.ai.store,
          provider: widget.ai.provider,
          config: widget.ai.config,
          usageStore: widget.ai.usageStore,
          prompts: widget.ai.prompts,
          task: task,
        ),
      ),
    ),
  );

  Future<void> _generate() async {
    if (_pending != null || _choosing) return;
    setState(() => _choosing = true);
    final input =
        await showDialog<
          ({WritingTaskKind kind, SentenceLevel level, String topic})
        >(context: context, builder: (_) => const _WritingTaskOptions());
    if (!mounted) return;
    setState(() => _choosing = false);
    if (input == null) return;
    final cancel = CancelToken();
    setState(() => _pending = cancel);
    try {
      final task = await widget.ai.generate(
        kind: input.kind,
        level: input.level,
        topic: input.topic,
        cancel: cancel,
      );
      if (mounted && !cancel.isCancelled) await _open(task);
    } catch (error) {
      if (mounted && !cancel.isCancelled) {
        await act(context, () => Future<void>.error(error));
      }
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy = _choosing || _pending != null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageWriting)),
      body: languagePage(
        children: [
          FilledButton.icon(
            onPressed: busy ? null : _generate,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(l10n.languageGenerateWritingTask),
          ),
          if (_pending != null) ...[
            const LinearProgressIndicator(),
            TextButton(
              onPressed: () => _pending?.cancel(),
              child: Text(l10n.cancel),
            ),
          ],
          Text(
            l10n.languageWritingTasksSaved,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          StreamBuilder<List<LearningWritingTaskRow>>(
            stream: _tasks,
            builder: (context, snapshot) {
              final rows = snapshot.data;
              if (snapshot.hasError) {
                return Text(l10n.couldNotCompleteTheAction);
              }
              if (rows == null) return const LinearProgressIndicator();
              if (rows.isEmpty) return Text(l10n.languageWritingTasksEmpty);
              return Column(
                children: [
                  for (final row in rows)
                    ListTile(
                      title: Text(row.title),
                      subtitle: Text(
                        row.model == "Mock"
                            ? l10n.languageExamMock
                            : l10n.languageAiSource(row.model),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: busy ? null : () => _open(openWritingTask(row)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WritingTaskOptions extends StatefulWidget {
  const _WritingTaskOptions();

  @override
  State<_WritingTaskOptions> createState() => _WritingTaskOptionsState();
}

class _WritingTaskOptionsState extends State<_WritingTaskOptions> {
  final _topic = TextEditingController();
  WritingTaskKind _kind = WritingTaskKind.application;
  SentenceLevel _level = SentenceLevel.intermediate;

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.languageGenerateWritingTask),
      content: SizedBox(
        width: 420,
        child: Column(
          spacing: 12,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.languageExamProfile),
            AppSelectField<WritingTaskKind>(
              initialValue: _kind,
              items: [
                DropdownMenuItem(
                  value: WritingTaskKind.application,
                  child: Text(l10n.languageApplicationWriting),
                ),
                DropdownMenuItem(
                  value: WritingTaskKind.continuation,
                  child: Text(l10n.languageContinuation),
                ),
              ],
              onChanged: (kind) => _kind = kind!,
            ),
            AppSelectField<SentenceLevel>(
              initialValue: _level,
              decoration: InputDecoration(
                labelText: l10n.languageDifficulty,
                hintText: l10n.languageSentenceMixed,
              ),
              items: [
                DropdownMenuItem(
                  value: SentenceLevel.beginner,
                  child: Text(l10n.languageBeginner),
                ),
                DropdownMenuItem(
                  value: SentenceLevel.intermediate,
                  child: Text(l10n.languageIntermediate),
                ),
              ],
              onChanged: (level) => _level = level!,
            ),
            TextField(
              controller: _topic,
              maxLength: 100,
              decoration: InputDecoration(labelText: l10n.languageExamTopic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop((kind: _kind, level: _level, topic: _topic.text.trim())),
          child: Text(l10n.languageGenerateWritingTask),
        ),
      ],
    );
  }
}
