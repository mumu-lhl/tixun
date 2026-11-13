import 'package:tixun/core/l10n/app_error_localization.dart';

import 'study_localization.dart';
import '../../core/ui/app_menu.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'library_providers.dart';
import 'study_store.dart';

class StudyEditor extends ConsumerStatefulWidget {
  const StudyEditor({
    required this.isMistake,
    this.knowledge,
    this.mistake,
    this.initialKnowledge,
    this.initialMistake,
    this.sourceSessionId,
    this.sourceMessageId,
    this.analysisOnly = false,
    super.key,
  }) : assert(!analysisOnly || (isMistake && mistake != null));
  final bool isMistake;
  final KnowledgeDetail? knowledge;
  final MistakeDetail? mistake;
  final KnowledgeDraft? initialKnowledge;
  final MistakeDraft? initialMistake;
  final String? sourceSessionId, sourceMessageId;
  final bool analysisOnly;
  @override
  ConsumerState<StudyEditor> createState() => _StudyEditorState();
}

class _StudyEditorState extends ConsumerState<StudyEditor> {
  final _fields = <String, TextEditingController>{};
  bool _saving = false, _dirty = false;
  late String _kind;
  TextEditingController field(String name) => _fields[name]!;
  @override
  void initState() {
    super.initState();
    final k = widget.knowledge;
    final m = widget.mistake;
    final kd = widget.initialKnowledge;
    final md = widget.initialMistake;
    _kind = k?.item.kind ?? kd?.kind ?? '个人笔记';
    final values = <String, String>{
      'title': k?.item.title ?? m?.item.title ?? kd?.title ?? md?.title ?? '',
      'subject':
          k?.item.subject ??
          m?.item.subject ??
          kd?.subject ??
          md?.subject ??
          '数学',
      'chapter':
          k?.item.chapter ??
          m?.item.chapter ??
          kd?.chapter ??
          md?.chapter ??
          '',
      'tags': (k?.tags ?? m?.tags ?? kd?.tags ?? md?.tags ?? []).join('，'),
      'content': k?.item.content ?? kd?.content ?? '',
      'question': m?.item.question ?? md?.question ?? '',
      'correctAnswer': m?.item.correctAnswer ?? md?.correctAnswer ?? '',
      'originalAnswer': m?.item.originalAnswer ?? md?.originalAnswer ?? '',
      'ownAnalysis': m?.item.ownAnalysis ?? md?.ownAnalysis ?? '',
      'aiAnalysis': m?.item.aiAnalysis ?? md?.aiAnalysis ?? '',
      'errorReason': m?.item.errorReason ?? md?.errorReason ?? '暂未确定',
      'suggestedReason': m?.item.suggestedReason ?? md?.suggestedReason ?? '',
    };
    for (final e in values.entries) {
      _fields[e.key] = TextEditingController(text: e.value)
        ..addListener(() {
          if (!_dirty) setState(() => _dirty = true);
        });
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _discard() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.discardUnsavedChanges),
            content: Text(context.l10n.youHaveUnsavedChanges),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.keepEditing),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.discardChanges),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final store = ref.read(studyStoreProvider);
      final labels = field('tags').text.split(RegExp('[,，]'));
      final oldId = widget.knowledge?.item.id ?? widget.mistake?.item.id;
      final oldSubject =
          widget.knowledge?.item.subject ?? widget.mistake?.item.subject;
      if (oldId != null && oldSubject != field('subject').text.trim()) {
        final linked = await store.modules.ids(oldId, widget.isMistake);
        if (linked.isNotEmpty) {
          if (!mounted) return;
          final yes = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: Text(d.l10n.changeSubject),
              content: Text(d.l10n.changingTheSubjectRemovesIts),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d),
                  child: Text(d.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: Text(d.l10n.continueSaving),
                ),
              ],
            ),
          );
          if (yes != true) return;
        }
      }

      String id;
      if (widget.isMistake) {
        final row = await store.saveMistake(
          MistakeDraft(
            title: field('title').text,
            question: field('question').text,
            subject: field('subject').text,
            chapter: field('chapter').text,
            tags: labels,
            correctAnswer: field('correctAnswer').text,
            originalAnswer: field('originalAnswer').text,
            ownAnalysis: field('ownAnalysis').text,
            aiAnalysis: field('aiAnalysis').text,
            errorReason: field('errorReason').text,
            suggestedReason: field('suggestedReason').text,
          ),
          id: widget.mistake?.item.id,
          expectedRevision: widget.mistake?.item.revision,
          sourceSessionId: widget.sourceSessionId,
          sourceMessageId: widget.sourceMessageId,
        );
        id = row.id;
      } else {
        final row = await store.saveKnowledge(
          KnowledgeDraft(
            title: field('title').text,
            content: field('content').text,
            subject: field('subject').text,
            kind: _kind,
            chapter: field('chapter').text,
            tags: labels,
          ),
          id: widget.knowledge?.item.id,
          expectedRevision: widget.knowledge?.item.revision,
          sourceSessionId: widget.sourceSessionId,
          sourceMessageId: widget.sourceMessageId,
        );
        id = row.id;
      }
      if (mounted) {
        _dirty = false;
        Navigator.pop(context, id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FormatException
                  ? failureText(context.l10n, e)
                  : context.l10n.couldNotSaveCheckAvailable,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && !_saving,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && !_saving && await _discard() && context.mounted) {
        setState(() => _dirty = false);
        if (context.mounted) Navigator.pop(context);
      }
    },
    child: Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.l10n.closeEditor,
            onPressed: _saving
                ? null
                : () async {
                    if (await _discard() && context.mounted) {
                      setState(() => _dirty = false);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
            icon: const Icon(Icons.close),
          ),
          title: Text(
            widget.analysisOnly
                ? context.l10n.saveMistakeExplanation
                : widget.isMistake
                ? context.l10n.organizeMistakes
                : context.l10n.editKnowledge,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const Key('save-study'),
                onPressed: _saving ? null : () => act(context, _save),
                child: Text(
                  _saving ? context.l10n.savingEllipsis : context.l10n.save,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.analysisOnly) ...[
                        Text(
                          widget.mistake!.item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        _input(
                          'aiAnalysis',
                          context.l10n.aiExplanationCheckConclusion,
                          key: const Key('study-ai-analysis'),
                          lines: 12,
                        ),
                      ] else ...[
                        _input(
                          'title',
                          context.l10n.titleLabel,
                          key: const Key('study-title'),
                          maxLength: 160,
                        ),
                        _input(
                          'subject',
                          context.l10n.subjectCustomizable,
                          maxLength: 40,
                        ),
                        if (!widget.isMistake)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AppSelectField<String>(
                              initialValue: _kind,
                              decoration: InputDecoration(
                                labelText: context.l10n.knowledgeType,
                              ),
                              items: knowledgeKinds
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(
                                        knowledgeKindLabel(context, v),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() {
                                _kind = v!;
                                _dirty = true;
                              }),
                            ),
                          ),
                        _input(
                          'chapter',
                          context.l10n.chapterLearningScope,
                          maxLength: 160,
                        ),
                        _input(
                          'tags',
                          context.l10n.tagsCommaSeparated,
                          maxLength: 800,
                        ),
                        if (!widget.isMistake)
                          _input(
                            'content',
                            context.l10n.contentMarkdownLatex,
                            key: const Key('study-content'),
                            lines: 12,
                          )
                        else ...[
                          _input(
                            'question',
                            context.l10n.questionTextOptionalForImages,
                            key: const Key('study-content'),
                            lines: 5,
                          ),
                          _input(
                            'correctAnswer',
                            context.l10n.correctAnswer,
                            lines: 3,
                          ),
                          _input(
                            'originalAnswer',
                            context.l10n.myOriginalAnswer,
                            lines: 3,
                          ),
                          _input(
                            'ownAnalysis',
                            context.l10n.myAnalysisAndThoughts,
                            lines: 4,
                          ),
                          _input(
                            'aiAnalysis',
                            context.l10n.aiExplanationCheckConclusion,
                            lines: 6,
                          ),
                          _input(
                            'errorReason',
                            context.l10n.confirmedErrorReasonCustomizable,
                            maxLength: 100,
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: field('errorReason'),
                            builder: (context, value, _) => Wrap(
                              spacing: 6,
                              children: mistakeReasons.map((r) {
                                final selected = value.text == r;
                                final colors = Theme.of(context).colorScheme;
                                return ActionChip(
                                  label: Text(
                                    mistakeReasonLabel(context, r),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: selected
                                          ? colors.onPrimaryContainer
                                          : null,
                                    ),
                                  ),
                                  backgroundColor: selected
                                      ? colors.primaryContainer
                                      : null,
                                  onPressed: () =>
                                      field('errorReason').text = r,
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _input(
                            'suggestedReason',
                            context.l10n.aiSuggestedCauseUnverified,
                            lines: 2,
                            maxLength: 500,
                          ),
                        ],
                        Text(
                          context.l10n.addImagesFromTheSaved,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _input(
    String name,
    String label, {
    int lines = 1,
    int? maxLength,
    Key? key,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      key: key,
      controller: field(name),
      enabled: !_saving,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 4,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
        // Fields with a visible limit keep the counter; body fields pass no
        // maxLength at all, so over-long input reaches the store's 60000
        // check and is rejected with an error instead of being silently
        // truncated by the TextField.
        counterText: maxLength == null ? '' : null,
      ),
    ),
  );
}
