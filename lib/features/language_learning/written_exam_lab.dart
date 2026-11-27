import "package:dio/dio.dart";
import "package:material_ui/material_ui.dart";

import "language_layout.dart";
import "generation_activity.dart";
import "generation_progress.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "exam_ai.dart";
import "exam_material.dart";
import "exam_store.dart";
import "sentence_content.dart";
import "written_exam_profile.dart";
import "written_exam_run.dart";
import "written_exam_store.dart";
import "writing_ai.dart";
import "writing_task_ai.dart";

typedef _Prepared = ({
  List<ExamMaterial> objectives,
  List<LearningWritingTaskRow> essays,
});

class WrittenExamLab extends StatefulWidget {
  const WrittenExamLab({
    super.key,
    required this.ai,
    required this.writing,
    this.glossLanguage,
    this.openProfile,
  });
  final ExamAi ai;
  final WritingTaskAi writing;
  final String? glossLanguage;
  final VoidCallback? openProfile;

  @override
  State<WrittenExamLab> createState() => _WrittenExamLabState();
}

class _WrittenExamLabState extends State<WrittenExamLab> {
  final _activity = ValueNotifier<GenerationActivity?>(null);
  static const _profile = WrittenExamProfile.zhejiang2026;
  late var _history = widget.ai.store.writtenExamHistory();
  CancelToken? _request;
  _Prepared? _prepared;
  int _ready = 0;
  bool _opening = false;

  @override
  void dispose() {
    _request?.cancel();
    super.dispose();
  }

  String get _gloss =>
      widget.glossLanguage ?? Localizations.localeOf(context).languageCode;

  Future<void> _prepare() async {
    if (_request != null || _opening) return;
    final cancel = CancelToken();
    final gloss = _gloss;
    setState(() {
      _request = cancel;
      _ready = 0;
    });
    try {
      final objectives = <ExamMaterial>[];
      final essays = <LearningWritingTaskRow>[];
      final selected = <String>{};
      for (final spec in _profile.sections) {
        if (spec.kind case final kind?) {
          final material = await trackLanguageGeneration(
            _activity,
            () => widget.ai.acquire(
              ExamTarget(
                kind: kind,
                profile: _profile.exam,
                level: SentenceLevel.intermediate,
                count: spec.count,
              ),
              glossLanguage: gloss,
              cancel: cancel,
              excludeIds: selected,
              fresh: true,
            ),
          );
          selected.add(material.row.id);
          objectives.add(material);
        } else {
          final saved = await widget.ai.store.reusableMockEssay(
            _profile.exam,
            spec.writing!,
          );
          if (saved != null) {
            essays.add(saved);
          } else {
            final made = await trackLanguageGeneration(
              _activity,
              () => widget.writing.generate(
                kind: spec.writing!,
                level: SentenceLevel.intermediate,
                topic: "",
                cancel: cancel,
                profile: _profile.exam,
              ),
            );
            essays.add(await widget.ai.store.mockEssayRow(made.id));
          }
        }
        if (cancel.isCancelled || !mounted) return;
        setState(() => _ready++);
      }
      setState(() => _prepared = (objectives: objectives, essays: essays));
    } catch (error) {
      if (mounted && !cancel.isCancelled) {
        await act(context, () => Future<void>.error(error));
      }
    } finally {
      if (mounted) setState(() => _request = null);
    }
  }

  Future<void> _open(Future<WrittenExam> Function() load) async {
    if (_opening || _request != null) return;
    setState(() => _opening = true);
    try {
      await act(context, () async {
        final run = await load();
        if (!mounted) return;
        setState(() => _prepared = null);
        final gloss = _gloss;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WrittenExamRun(
              store: widget.ai.store,
              initial: run,
              openProfile: widget.openProfile,
              writing: (task, text, cancel) => WritingAi(
                store: widget.ai.store,
                task: task,
                provider: widget.writing.provider,
                config: widget.writing.config,
                usageStore: widget.writing.usageStore,
                prompts: widget.writing.prompts,
              ).evaluate(text: text, glossLanguage: gloss, cancel: cancel),
            ),
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
          _history = widget.ai.store.writtenExamHistory();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageWrittenMock)),
      body: languagePage(
        children: [
          Text(l10n.languageExamProfile),
          Text(
            l10n.languageWrittenMockScope(
              _profile.duration.inMinutes,
              _profile.maximumHalfPoints ~/ 2,
            ),
          ),
          Text(l10n.languageWrittenMockCost(_profile.sections.length)),
          FutureBuilder(
            future: _history,
            builder: (context, snapshot) {
              final history = snapshot.data;
              if (history == null) {
                return snapshot.hasError
                    ? Text(l10n.couldNotCompleteTheAction)
                    : const LinearProgressIndicator();
              }
              final inProgress = history
                  .where((entry) => entry.submittedAt == null)
                  .firstOrNull;
              final prepared = _prepared;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (inProgress != null)
                    FilledButton(
                      onPressed: _opening
                          ? null
                          : () => _open(
                              () => widget.ai.store.writtenExam(inProgress.id),
                            ),
                      child: Text(l10n.languageWrittenMockResume),
                    )
                  else if (prepared != null)
                    FilledButton(
                      onPressed: _opening
                          ? null
                          : () => _open(
                              () => widget.ai.store.startWrittenExam(
                                profile: _profile,
                                objectives: prepared.objectives,
                                essays: prepared.essays,
                              ),
                            ),
                      child: Text(l10n.languageWrittenMockStart),
                    )
                  else if (_request == null)
                    FilledButton(
                      onPressed: _opening ? null : _prepare,
                      child: Text(l10n.languageExamPrepare),
                    )
                  else ...[
                    LanguageGenerationProgress(
                      label: l10n.languageExamPrepare,
                      completed: _ready,
                      total: _profile.sections.length,
                    ),
                    LanguageGenerationActivity(activity: _activity),
                    TextButton(
                      onPressed: () => _request?.cancel(),
                      child: Text(l10n.cancel),
                    ),
                  ],
                  for (final run in history.where(
                    (row) => row.submittedAt != null,
                  ))
                    ListTile(
                      title: Text(l10n.languageWrittenMockReview),
                      subtitle: Text(
                        MaterialLocalizations.of(context)
                            .formatShortDate(run.startedAt.toLocal()),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _opening || _request != null
                          ? null
                          : () => _open(
                              () => widget.ai.store.writtenExam(run.id),
                            ),
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
