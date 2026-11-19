import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/ui/actions.dart';
import 'exam_ai.dart';
import 'exam_labels.dart';
import 'exam_material.dart';
import 'exam_store.dart';
import 'quick_lookup/quick_selection.dart';
import 'sentence_practice.dart' show sentenceSkillLabel;

class ExamPaperScreen extends StatefulWidget {
  const ExamPaperScreen({
    super.key,
    required this.ai,
    required this.material,
    this.glossLanguage,
  });

  final ExamAi ai;
  final ExamMaterial material;
  final String? glossLanguage;

  @override
  State<ExamPaperScreen> createState() => _ExamPaperScreenState();
}

class _ExamPaperScreenState extends State<ExamPaperScreen> {
  late var _material = widget.material;
  ExamPaper get _paper => _material.paper;
  late final _answers = List.filled(_paper.items.length, '');
  late var _attempt = widget.ai.store.newExamAttemptId();
  late final _history = widget.ai.store.examHistory(_material.row.id);
  final _hints = <int>{};
  ExamConfidence? _confidence;
  ExamResult? _result;
  CancelToken? _review;
  bool _saving = false;
  bool _lookedUp = false;

  String _confidenceLabel(AppLocalizations l10n, ExamConfidence confidence) =>
      switch (confidence) {
        ExamConfidence.certain => l10n.languageExamCertain,
        ExamConfidence.unsure => l10n.languageExamUnsure,
        ExamConfidence.guess => l10n.languageExamGuess,
      };

  @override
  void dispose() {
    _review?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving ||
        _result != null ||
        _review != null ||
        _answers.any((answer) => answer.trim().isEmpty)) {
      return;
    }
    setState(() => _saving = true);
    await act(context, () async {
      final result = await widget.ai.store.submitExam(
        material: _material,
        attemptId: _attempt,
        responses: List.of(_answers),
        confidence: _confidence,
        hintUsed: _hints.isNotEmpty || _lookedUp,
      );
      if (mounted) setState(() => _result = result);
    });
    if (mounted) setState(() => _saving = false);
  }

  void _retry() {
    setState(() {
      _result = null;
      _confidence = null;
      _hints.clear();
      _lookedUp = false;
      _answers.fillRange(0, _answers.length, '');
      _attempt = widget.ai.store.newExamAttemptId();
    });
  }

  Future<void> _qualityReview() async {
    if (_review != null ||
        _saving ||
        _result != null ||
        _answers.any((answer) => answer.isNotEmpty) ||
        _hints.isNotEmpty ||
        _lookedUp) {
      return;
    }
    final cancel = CancelToken();
    final gloss =
        widget.glossLanguage ?? Localizations.localeOf(context).languageCode;
    setState(() => _review = cancel);
    try {
      final review = await widget.ai.review(
        _material,
        glossLanguage: gloss,
        cancel: cancel,
      );
      if (mounted && !cancel.isCancelled) {
        setState(() {
          _material = review.material;
        });
      }
    } catch (error) {
      if (mounted && !cancel.isCancelled) {
        await act(context, () => Future<void>.error(error));
      }
    } finally {
      if (mounted) setState(() => _review = null);
    }
  }

  Future<void> _dispute(int position) async {
    final result = _result;
    if (result == null || _saving) return;
    setState(() => _saving = true);
    await act(context, () async {
      final updated = await widget.ai.store.flagExamResponse(result, position);
      if (mounted) setState(() => _result = updated);
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _result;
    final theme = Theme.of(context);
    final insertion = _material.target.kind == ExamKind.sentenceInsertion;
    final canReview =
        result == null &&
        _material.verification != ExamVerification.aiReviewed &&
        _material.source == ExamSource.aiGenerated &&
        _material.row.model != 'Mock' &&
        !widget.ai.isMock &&
        _answers.every((answer) => answer.isEmpty) &&
        _hints.isEmpty &&
        !_lookedUp;
    return Scaffold(
      appBar: AppBar(title: Text(examSourceLabel(l10n, _material))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_paper.title, style: theme.textTheme.headlineSmall),
                  if (result != null) ...[
                    Text(
                      l10n.languageExamResult(
                        result.matched,
                        _paper.items.length,
                      ),
                      style: theme.textTheme.titleLarge,
                    ),
                    if (result.confidence case final confidence?)
                      Text(
                        '${l10n.languageExamConfidence} · ${_confidenceLabel(l10n, confidence)}',
                      ),
                    if (_material.source == ExamSource.aiGenerated)
                      Text(l10n.languageExamReferenceResult),
                  ],
                  if (canReview || _review != null) ...[
                    Text(l10n.languageExamReviewCost),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: _review == null
                            ? _qualityReview
                            : () => _review?.cancel(),
                        child: Text(
                          _review == null
                              ? l10n.languageExamReviewAi
                              : l10n.cancel,
                        ),
                      ),
                    ),
                    if (_review != null) const LinearProgressIndicator(),
                  ],
                  if (_material.row.reviewIssue case final issue?) Text(issue),
                  for (final paragraph in _paper.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _review == null
                          ? quickSelectableText(
                              result == null ? paragraph : _filled(paragraph),
                              onLookup: () => setState(() => _lookedUp = true),
                            )
                          : SelectableText(paragraph),
                    ),
                  if (insertion) ...[
                    const Divider(height: 28),
                    Text(l10n.languageExamSharedCandidates),
                    for (final entry in _paper.candidates.entries)
                      Text('${entry.key}. ${entry.value}'),
                  ],
                  const Divider(height: 32),
                  for (final (index, item) in _paper.items.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: result == null
                          ? _input(context, index, item, insertion)
                          : _feedback(context, result, index, item),
                    ),
                  if (result == null) ...[
                    Text(l10n.languageExamConfidence),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final confidence in ExamConfidence.values)
                          ChoiceChip(
                            label: Text(_confidenceLabel(l10n, confidence)),
                            selected: _confidence == confidence,
                            onSelected: _saving
                                ? null
                                : (selected) => setState(
                                    () => _confidence = selected
                                        ? confidence
                                        : null,
                                  ),
                          ),
                      ],
                    ),
                    FilledButton(
                      onPressed:
                          !_saving &&
                              _review == null &&
                              _answers.every((value) => value.trim().isNotEmpty)
                          ? _submit
                          : null,
                      child: Text(l10n.languageExamSubmitAll),
                    ),
                  ] else
                    FilledButton(
                      onPressed: _saving || _review != null ? null : _retry,
                      child: Text(l10n.languageExamRetry),
                    ),
                  const SizedBox(height: 12),
                  _historyButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _filled(String paragraph) =>
      paragraph.replaceAllMapped(RegExp(r'\[(\d+)\]'), (match) {
        final index = int.parse(match[1]!) - 1;
        final answer = _paper.items[index].answers.first;
        return '[${match[1]}: ${_paper.optionsFor(index)[answer] ?? answer}]';
      });

  Widget _input(
    BuildContext context,
    int index,
    ExamItem item,
    bool insertion,
  ) {
    final l10n = context.l10n;
    final options = _paper.optionsFor(index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${index + 1}. ${item.prompt}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (options.isEmpty)
          TextFormField(
            key: ValueKey('$_attempt:$index'),
            initialValue: _answers[index],
            enabled: !_saving,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: l10n.languageExamAnswer,
              counterText: '',
            ),
            onChanged: (value) => setState(() => _answers[index] = value),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final option in options.entries)
                ChoiceChip(
                  label: Text(
                    insertion ? option.key : '${option.key}. ${option.value}',
                  ),
                  selected: _answers[index] == option.key,
                  onSelected:
                      _saving ||
                          (insertion &&
                              _answers[index] != option.key &&
                              _answers.contains(option.key))
                      ? null
                      : (selected) => setState(
                          () => _answers[index] = selected ? option.key : '',
                        ),
                ),
            ],
          ),
        if (_hints.contains(index))
          SelectableText(item.evidence)
        else
          TextButton(
            onPressed: _saving || _review != null
                ? null
                : () => setState(() => _hints.add(index)),
            child: Text(l10n.languageExamEvidenceHint),
          ),
      ],
    );
  }

  Widget _feedback(
    BuildContext context,
    ExamResult result,
    int index,
    ExamItem item,
  ) {
    final l10n = context.l10n;
    final options = _paper.optionsFor(index);
    final response = result.responses[index];
    final correct = item.matches(response);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: !correct,
      title: Text('${index + 1}. ${item.prompt}'),
      subtitle: Text(correct ? l10n.correct : l10n.needsCorrection),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.languageExamYourAnswer(options[response] ?? response)),
        Text(
          l10n.languageSentenceAnswer(
            item.answers.map((answer) => options[answer] ?? answer).join(' / '),
          ),
        ),
        Text(sentenceSkillLabel(l10n, item.skill)),
        SelectableText(
          item.evidence,
          style: TextStyle(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        Text(item.explanation),
        for (final entry in item.distractors.entries)
          Text('${entry.key}. ${entry.value}'),
        if (_material.target.kind == ExamKind.grammar && !correct)
          TextButton(
            onPressed:
                _saving || _review != null || result.disputed.contains(index)
                ? null
                : () => _dispute(index),
            child: Text(
              result.disputed.contains(index)
                  ? l10n.languageExamDisputed
                  : l10n.languageExamDispute,
            ),
          ),
      ],
    );
  }

  Widget _historyButton(
    BuildContext context,
  ) => StreamBuilder<List<ExamResult>>(
    stream: _history,
    builder: (context, snapshot) {
      final history = snapshot.data;
      if (history == null || history.isEmpty) return const SizedBox.shrink();
      return TextButton(
        onPressed: _saving || _review != null
            ? null
            : () async {
                final entry = await showDialog<ExamResult>(
                  context: context,
                  builder: (context) => SimpleDialog(
                    title: Text(context.l10n.languageReadingAttempts),
                    children: [
                      for (final result in history)
                        SimpleDialogOption(
                          onPressed: () => Navigator.of(context).pop(result),
                          child: Text(
                            '${MaterialLocalizations.of(context).formatShortDate(result.submittedAt)} · ${result.matched}/${_paper.items.length}',
                          ),
                        ),
                    ],
                  ),
                );
                if (mounted && entry != null) setState(() => _result = entry);
              },
        child: Text(context.l10n.languageReadingAttempts),
      );
    },
  );
}
