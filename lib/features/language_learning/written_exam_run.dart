import 'dart:async';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';

import 'language_layout.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'exam_labels.dart';
import 'exam_material.dart';
import 'language_store.dart';
import 'sentence_practice.dart' show sentenceSkillLabel;
import 'written_exam_store.dart';
import 'writing_store.dart';
import 'writing_task_ai.dart';

class WrittenExamRun extends StatefulWidget {
  const WrittenExamRun({
    super.key,
    required this.store,
    required this.initial,
    required this.writing,
    this.openProfile,
  });

  final LanguageLearningStore store;
  final WrittenExam initial;
  final VoidCallback? openProfile;
  final Future<String> Function(
    WritingTask task,
    String text,
    CancelToken cancel,
  )
  writing;

  @override
  State<WrittenExamRun> createState() => _WrittenExamRunState();
}

class _WrittenExamRunState extends State<WrittenExamRun> {
  late var _run = widget.initial;
  late var _position = _run.row.currentSection;
  late var _answers = _run.sections[_position].answers;
  late final Timer _clock;
  Future<void> _pending = Future.value();
  bool _busy = false;
  bool _saveError = false;
  DateTime? _lastEditedAt;
  CancelToken? _feedback;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_run.submitted) return;
      if (_run.remaining(DateTime.now()) == Duration.zero &&
          !_busy &&
          !_saveError) {
        unawaited(_submit());
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    _feedback?.cancel();
    super.dispose();
  }

  void _answer(int index, String value) {
    if (_busy ||
        _run.submitted ||
        _run.remaining(DateTime.now()) == Duration.zero) {
      return;
    }
    setState(() => _answers[index] = value);
    final position = _position;
    final answers = List<String>.of(_answers);
    final now = _lastEditedAt = DateTime.now();
    _pending = _pending.then((_) async {
      try {
        await widget.store.editWrittenSection(
          id: _run.row.id,
          position: position,
          answers: answers,
          now: now,
        );
        if (mounted && _saveError) setState(() => _saveError = false);
      } catch (_) {
        if (mounted) setState(() => _saveError = true);
      }
    });
  }

  Future<void> _submit() async {
    if (_busy || _run.submitted) return;
    setState(() => _busy = true);
    try {
      await _pending;
      if (!mounted) return;
      await act(context, () async {
        if (_saveError) {
          await widget.store.editWrittenSection(
            id: _run.row.id,
            position: _position,
            answers: List.of(_answers),
            now: _lastEditedAt,
          );
        }
        final result = await widget.store.submitWrittenExam(_run.row.id);
        if (mounted) {
          setState(() {
            _run = result;
            _answers = _run.sections[_position].answers;
            _saveError = false;
            _clock.cancel();
          });
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(int position) async {
    if (_busy || position == _position) return;
    if (_run.submitted) {
      setState(() {
        _position = position;
        _answers = _run.sections[position].answers;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await _pending;
      if (!mounted || _saveError) return;
      await act(context, () async {
        final result = await widget.store.selectWrittenSection(
          _run.row.id,
          position,
        );
        if (mounted) {
          setState(() {
            _run = result;
            _position = result.row.currentSection;
            _answers = result.sections[_position].answers;
          });
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _evaluate(WrittenExamSection section) async {
    if (_feedback != null || !_run.submitted || section.writing == null) return;
    final token = CancelToken();
    setState(() => _feedback = token);
    try {
      await act(context, () async {
        final String version;
        try {
          version = await widget.writing(
            isolatedWrittenTask(_run, section.writing!),
            section.answers.single,
            token,
          );
        } catch (_) {
          if (token.isCancelled) return;
          rethrow;
        }
        if (token.isCancelled) return;
        await widget.store.attachWrittenFeedback(
          _run.row.id,
          section.row.position,
          version,
        );
        final refreshed = await widget.store.writtenExam(_run.row.id);
        if (mounted) setState(() => _run = refreshed);
      });
    } finally {
      if (mounted) setState(() => _feedback = null);
    }
  }

  String _sectionName(BuildContext context, WrittenExamSection section) {
    if (section.material case final material?) {
      return examKindLabel(context.l10n, material.target.kind);
    }
    return section.writing?.kind == WritingTaskKind.continuation.name
        ? context.l10n.languageContinuation
        : context.l10n.languageApplicationWriting;
  }

  String _clockText(Duration duration) => [
    duration.inMinutes.toString().padLeft(2, '0'),
    (duration.inSeconds % 60).toString().padLeft(2, '0'),
  ].join(':');
  String _points(int half) =>
      half.isEven ? (half ~/ 2).toString() : (half / 2).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final section = _run.sections[_position];
    final remaining = _run.remaining(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.languageWrittenMock),
        actions: [
          if (!_run.submitted)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(_clockText(remaining)),
              ),
            ),
        ],
      ),
      body: languagePage(
        children: [
          Text(l10n.languageWrittenMockReference),
          if (_run.submitted) ...[
            Text(
              l10n.languageWrittenMockObjective(
                _points(_run.earnedHalfPoints),
                _points(_run.objectiveHalfPoints),
              ),
            ),
            if (widget.openProfile case final open?)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: open,
                  icon: const Icon(Icons.insights_outlined),
                  label: Text(l10n.languageProfile),
                ),
              ),
            for (final part in _run.sections)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  [
                    _sectionName(context, part),
                    _clockText(Duration(seconds: part.row.seconds)),
                  ].join(' · '),
                ),
                subtitle: Text(
                  part.earnedHalfPoints == null
                      ? l10n.languageWrittenMockEssayPending(
                          _points(part.maximumHalfPoints),
                        )
                      : l10n.languageWrittenMockSectionScore(
                          _points(part.earnedHalfPoints!),
                          _points(part.maximumHalfPoints),
                        ),
                ),
                onTap: () => _select(part.row.position),
              ),
          ],
          if (_saveError) Text(l10n.couldNotCompleteTheAction),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final part in _run.sections)
                ChoiceChip(
                  selected: part.row.position == _position,
                  label: Text(
                    [
                      (part.row.position + 1).toString(),
                      _sectionName(context, part),
                    ].join(' '),
                  ),
                  onSelected: _busy ? null : (_) => _select(part.row.position),
                ),
            ],
          ),
          const Divider(height: 28),
          if (section.material case final paper?)
            ..._objective(context, paper.paper, paper.target.kind, remaining)
          else
            ..._essay(context, section, remaining),
          if (!_run.submitted)
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: Text(l10n.languageWrittenMockSubmitConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l10n.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(l10n.confirmChoice),
                            ),
                          ],
                        ),
                      );
                      if (mounted && confirmed == true) await _submit();
                    },
              child: Text(l10n.languageExamSubmitAll),
            ),
        ],
      ),
    );
  }

  List<Widget> _objective(
    BuildContext context,
    ExamPaper paper,
    ExamKind kind,
    Duration remaining,
  ) {
    final l10n = context.l10n;
    final active = !_busy && remaining != Duration.zero && !_run.submitted;
    return [
      Text(paper.title, style: Theme.of(context).textTheme.titleLarge),
      for (final paragraph in paper.paragraphs)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SelectableText(paragraph),
        ),
      if (kind == ExamKind.sentenceInsertion)
        for (final entry in paper.candidates.entries)
          Text([entry.key, entry.value].join('. ')),
      for (final (index, item) in paper.items.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.prompt),
              if (_run.submitted) ...[
                Text(
                  l10n.languageExpected(
                    item.answers
                        .map(
                          (answer) => paper.optionsFor(index)[answer] ?? answer,
                        )
                        .join(' / '),
                  ),
                ),
                Text([l10n.languageAnswer, _answers[index]].join(' · ')),
                Text(item.explanation),
                Text(item.evidence),
                Text(sentenceSkillLabel(l10n, item.skill)),
              ] else if (paper.optionsFor(index).isEmpty)
                TextFormField(
                  key: ValueKey((_position, index)),
                  initialValue: _answers[index],
                  maxLength: 100,
                  enabled: active,
                  decoration: InputDecoration(labelText: l10n.languageAnswer),
                  onChanged: (value) => _answer(index, value),
                )
              else
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in paper.optionsFor(index).entries)
                      ChoiceChip(
                        label: Text(
                          kind == ExamKind.sentenceInsertion
                              ? entry.key
                              : [entry.key, entry.value].join('. '),
                        ),
                        selected: _answers[index] == entry.key,
                        onSelected:
                            !active ||
                                (kind == ExamKind.sentenceInsertion &&
                                    _answers[index] != entry.key &&
                                    _answers.contains(entry.key))
                            ? null
                            : (selected) =>
                                  _answer(index, selected ? entry.key : ''),
                      ),
                  ],
                ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _essay(
    BuildContext context,
    WrittenExamSection section,
    Duration remaining,
  ) {
    final l10n = context.l10n;
    final task = section.writing!;
    return [
      Text(task.title, style: Theme.of(context).textTheme.titleLarge),
      SelectableText(task.prompt),
      if (task.passage case final passage?) SelectableText(passage),
      if (!_run.submitted)
        TextFormField(
          key: ValueKey((_position, 'essay')),
          initialValue: _answers.single,
          maxLength: 6000,
          minLines: 6,
          maxLines: 14,
          enabled: !_busy && remaining != Duration.zero,
          decoration: InputDecoration(labelText: l10n.languageAnswer),
          onChanged: (value) => _answer(0, value),
        )
      else ...[
        SelectableText(_answers.single),
        if (section.row.writingVersionId case final version?)
          FutureBuilder(
            future: widget.store.writingFeedback(version),
            builder: (context, snapshot) {
              final result = snapshot.data;
              return Text(
                result == null
                    ? l10n.languageWrittenMockReference
                    : [
                        l10n.languageWrittenMockReference,
                        result.summary,
                      ].join('\n'),
              );
            },
          )
        else if (_answers.single.trim().isNotEmpty)
          TextButton(
            onPressed: _feedback == null
                ? () => _evaluate(section)
                : () => _feedback?.cancel(),
            child: Text(
              _feedback == null
                  ? l10n.languageWrittenMockEvaluate
                  : l10n.cancel,
            ),
          ),
      ],
    ];
  }
}
