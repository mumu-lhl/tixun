import "package:dio/dio.dart";
import "package:material_ui/material_ui.dart";

import "language_layout.dart";

import "../../core/ai/chat_provider.dart";
import "../../core/l10n/app_error_localization.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/app_menu.dart";
import "../../core/l10n/generated/app_localizations.dart";
import "../../core/ui/actions.dart";
import "language_store.dart";
import "next_practice.dart";
import "sentence_batch_ai.dart";
import "sentence_batch_store.dart";
import "quick_lookup/quick_selection.dart";
import "sentence_batch_dialog.dart";
import "sentence_content.dart";
import "sentence_explanation.dart";
import "sentence_store.dart";

class SentencePractice extends StatefulWidget {
  const SentencePractice({
    super.key,
    required this.store,
    required this.explanation,
    this.batchAi,
    this.initialBatch,
    this.initialLevel,
    this.recommendation,
    this.feedbackLanguage,
  });

  final LanguageLearningStore store;
  final SentenceExplanation explanation;
  final SentenceBatchAi? batchAi;
  final SentenceBatch? initialBatch;
  final SentenceLevel? initialLevel;
  final SentencePlan? recommendation;
  final String? feedbackLanguage;

  @override
  State<SentencePractice> createState() => _SentencePracticeState();
}

class _SentencePracticeState extends State<SentencePractice> {
  late var _style = widget.recommendation?.style ?? SentenceStyle.written;
  var _topic = SentenceTopic.dailyLife;
  late SentenceLevel? _level =
      widget.recommendation?.level ?? widget.initialLevel;
  bool _planning = false;
  late SentenceBatch? _batch = widget.initialBatch;
  final _results = <(SentenceSkill?, bool?, bool, SentenceRating)>[];

  void _start(SentenceBatch? batch) {
    if (!mounted || batch == null) return;
    setState(() {
      _results.clear();
      _batch = batch;
    });
  }

  Future<void> _generate(SentenceBatchAi ai, {SentencePlan? plan}) async {
    if (_planning) return;
    final List<SentenceCard> saved;
    if (plan == null) {
      saved = const [];
    } else {
      setState(() => _planning = true);
      List<SentenceCard> reusable = [];
      await act(
        context,
        () async => reusable = await widget.store.savedForSentencePlan(plan),
      );
      if (!mounted) return;
      setState(() => _planning = false);
      saved = reusable;
      if (saved.length >= plan.count) {
        _start(SentenceBatch(saved));
        return;
      }
    }
    if (!mounted) return;
    final batch = await showDialog<SentenceBatch>(
      context: context,
      builder: (_) => SentenceBatchDialog(
        store: widget.store,
        ai: ai,
        topic: _topic,
        style: plan?.style ?? _style,
        level: plan?.level ?? _level,
        focus: plan?.skill,
        suggestedCount: plan == null ? null : plan.count - saved.length,
        exclusions: plan?.exclusions ?? const [],
        reused: saved,
        glossLanguage:
            widget.feedbackLanguage ??
            Localizations.localeOf(context).languageCode,
      ),
    );
    _start(batch);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final batch = _batch;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageSentencePractice)),
      body: languagePage(
        gap: 0,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: batch == null
                  ? _setup(l10n)
                  : _results.length == batch.cards.length
                  ? _summary(l10n)
                  : _SentenceStep(
                      key: ValueKey((batch.id, _results.length)),
                      card: batch.cards[_results.length],
                      position: _results.length + 1,
                      batch: batch,
                      store: widget.store,
                      explanation: widget.explanation,
                      batchAi: widget.batchAi,
                      feedbackLanguage: widget.feedbackLanguage,
                      onFinished: (skill, correct, assisted, rating) {
                        setState(
                          () =>
                              _results.add((skill, correct, assisted, rating)),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setup(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.recommendation case final plan?) ...[
        Text(l10n.languageNextSkill(sentenceSkillLabel(l10n, plan.skill))),
        Text(
          plan.diagnostic
              ? l10n.languageSentenceDiagnostic
              : l10n.languageNextSkillReason(
                  plan.performance.correct,
                  plan.performance.checked,
                ),
        ),
        if (widget.batchAi case final ai?)
          FilledButton.icon(
            onPressed: _planning ? null : () => _generate(ai, plan: plan),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(l10n.languageSentencePrepareRecommendation),
          ),
        const SizedBox(height: 12),
      ],
      AppSelectField<SentenceStyle>(
        initialValue: _style,
        decoration: InputDecoration(labelText: l10n.languageSentenceStyle),
        items: [
          DropdownMenuItem(
            value: SentenceStyle.written,
            child: Text(l10n.languageSentenceWritten),
          ),
          DropdownMenuItem(
            value: SentenceStyle.dialogue,
            child: Text(l10n.languageSentenceDialogue),
          ),
        ],
        onChanged: (value) => _style = value!,
      ),
      const SizedBox(height: 12),
      AppSelectField<SentenceTopic>(
        initialValue: _topic,
        decoration: InputDecoration(labelText: l10n.languageSentenceTopic),
        items: [
          DropdownMenuItem(
            value: SentenceTopic.dailyLife,
            child: Text(l10n.languageSentenceDaily),
          ),
          DropdownMenuItem(
            value: SentenceTopic.travel,
            child: Text(l10n.languageSentenceTravel),
          ),
        ],
        onChanged: (value) => _topic = value!,
      ),
      const SizedBox(height: 12),
      AppSelectField<SentenceLevel?>(
        initialValue: _level,

        decoration: InputDecoration(
          labelText: l10n.languageDifficulty,
          hintText: l10n.languageSentenceMixed,
        ),
        items: [
          DropdownMenuItem<SentenceLevel?>(
            child: Text(l10n.languageSentenceMixed),
          ),
          DropdownMenuItem(
            value: SentenceLevel.beginner,
            child: Text(l10n.languageBeginner),
          ),
          DropdownMenuItem(
            value: SentenceLevel.intermediate,
            child: Text(l10n.languageIntermediate),
          ),
        ],
        onChanged: (value) => setState(() => _level = value),
      ),
      const SizedBox(height: 12),
      if (widget.batchAi case final ai?)
        FilledButton(
          onPressed: () => _generate(ai),
          child: Text(l10n.languageSentenceGenerate),
        ),
      OutlinedButton(
        onPressed: () async =>
            _start(await chooseSavedSentenceBatch(context, widget.store)),
        child: Text(l10n.languageSentenceSaved),
      ),
    ],
  );

  Widget _summary(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        l10n.languageSentenceDone,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(
        l10n.languageSentenceSelfRated(
          _results.where((r) => r.$4 == SentenceRating.understood).length,
          _results.length,
        ),
      ),
      for (final skill
          in _results.map((r) => r.$1).whereType<SentenceSkill>().toSet()) ...[
        const SizedBox(height: 12),
        Text(
          sentenceSkillLabel(l10n, skill),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final assisted in [false, true])
          if (_results.any(
            (r) => r.$1 == skill && r.$2 != null && r.$3 == assisted,
          ))
            Text(_checkSummary(l10n, skill, assisted)),
      ],
      const SizedBox(height: 8),
      Text(l10n.languageSentenceSmallSample),
      const SizedBox(height: 16),
      if (widget.batchAi case final ai?)
        FilledButton(
          onPressed: _planning
              ? null
              : () async {
                  setState(() => _planning = true);
                  SentencePlan? plan;
                  await act(context, () async {
                    final history = await widget.store
                        .sentenceEvidence("en")
                        .first;
                    plan = suggestSentences(history);
                  });
                  if (!mounted) return;
                  setState(() => _planning = false);
                  if (plan != null) await _generate(ai, plan: plan);
                },
          child: Text(l10n.languageSentencePrepareRecommendation),
        ),
      OutlinedButton(
        onPressed: () => setState(() => _batch = null),
        child: Text(l10n.languageSentenceAnother),
      ),
    ],
  );

  String _checkSummary(
    AppLocalizations l10n,
    SentenceSkill skill,
    bool assisted,
  ) {
    final checks = _results.where(
      (r) => r.$1 == skill && r.$2 != null && r.$3 == assisted,
    );
    final correct = checks.where((r) => r.$2!).length;
    return assisted
        ? l10n.languageSentenceAssisted(correct, checks.length)
        : l10n.languageSentenceIndependent(correct, checks.length);
  }
}

class _SentenceStep extends StatefulWidget {
  const _SentenceStep({
    super.key,
    required this.batch,
    required this.card,
    required this.position,
    required this.store,
    required this.explanation,
    required this.onFinished,
    this.feedbackLanguage,
    this.batchAi,
  });

  final SentenceBatch batch;
  final SentenceBatchAi? batchAi;
  final SentenceCard card;
  final int position;
  final LanguageLearningStore store;
  final SentenceExplanation explanation;
  final String? feedbackLanguage;
  final void Function(SentenceSkill?, bool?, bool, SentenceRating) onFinished;

  @override
  State<_SentenceStep> createState() => _SentenceStepState();
}

class _SentenceStepState extends State<_SentenceStep> {
  late var _card = widget.card;
  final _help = <SentenceHelp>{};
  final _helpWhenChecked = <SentenceHelp>{};
  int? _choice;
  bool _checked = false;
  bool _saving = false;
  bool _showCheck = false;
  String? _explanation, _error;
  CancelToken? _pending;

  @override
  void dispose() {
    _pending?.cancel();
    super.dispose();
  }

  Future<void> _explain({required bool simpler}) async {
    if (_saving || _pending != null) return;
    final token = CancelToken();
    setState(() {
      _pending = token;
      _error = null;
    });
    try {
      final text = await widget.explanation.explain(
        card: _card,
        glossLanguage:
            widget.feedbackLanguage ??
            Localizations.localeOf(context).languageCode,
        simpler: simpler,
        cancel: token,
      );
      if (!mounted || token.isCancelled) return;
      setState(() {
        _help.add(SentenceHelp.explanation);
        _explanation = text;
      });
    } catch (error) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        _error = error is AiFailure
            ? failureText(context.l10n, error)
            : context.l10n.languageSentenceExplainError;
      });
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  Future<void> _prepareCheck() async {
    final ai = widget.batchAi;
    if (ai == null || _pending != null || _saving) return;
    final token = CancelToken();
    setState(() {
      _pending = token;
      _error = null;
    });
    try {
      final candidate = await ai.checkSaved(
        _card,
        cancel: token,
        glossLanguage:
            widget.feedbackLanguage ??
            Localizations.localeOf(context).languageCode,
      );
      if (!mounted || token.isCancelled) return;
      final checked = await widget.store.attachQuickSentenceCheck(
        candidate,
        token,
      );
      if (mounted && !token.isCancelled) {
        setState(() {
          _card = checked;
          _showCheck = true;
        });
      }
    } catch (error) {
      if (mounted && !token.isCancelled) {
        setState(
          () => _error = error is AiFailure
              ? failureText(context.l10n, error)
              : context.l10n.languageSentenceExplainError,
        );
      }
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  Future<void> _finish(SentenceRating rating) async {
    if (_saving) return;
    _pending?.cancel();
    setState(() => _saving = true);
    await act(context, () async {
      await widget.store.recordSentence(
        batchId: widget.batch.id,
        card: _card,
        rating: rating,
        helpUsed: _help,
        selectedIndex: _checked ? _choice : null,
        helpBeforeAnswer: _helpWhenChecked,
      );
      if (mounted) {
        widget.onFinished(
          _card.skill,
          _checked ? _choice == _card.correctIndex : null,
          _helpWhenChecked.isNotEmpty,
          rating,
        );
      }
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme;
    final card = _card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.languageSentenceProgress(
            widget.position,
            widget.batch.cards.length,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.batch.generatedBy case final model?) ...[
          Text(sentenceSource(l10n, model)),
          Text(l10n.languageSentenceGeneratedNotice, style: style.bodySmall),
        ],
        quickSelectableText(
          card.text,
          style: style.headlineSmall,
          onLookup: () => setState(() => _help.add(SentenceHelp.explanation)),
        ),
        if (card.id.startsWith("quick:") &&
            card.choices.isEmpty &&
            card.text.length <= 1200 &&
            widget.batchAi != null &&
            widget.explanation.provider is! MockChatProvider)
          TextButton(
            onPressed: _pending == null && !_saving ? _prepareCheck : null,
            child: Text(l10n.languageSentenceGenerateCheck),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _saving || _help.contains(SentenceHelp.hint)
                  ? null
                  : () => setState(() => _help.add(SentenceHelp.hint)),
              child: Text(l10n.languageSentenceHint),
            ),
            OutlinedButton(
              onPressed: _saving || _help.contains(SentenceHelp.translation)
                  ? null
                  : () => setState(() => _help.add(SentenceHelp.translation)),
              child: Text(
                widget.batch.generatedBy == null
                    ? l10n.languageSentenceTranslation
                    : l10n.languageSentenceMeaning,
              ),
            ),
            OutlinedButton(
              onPressed: _saving || _pending != null
                  ? null
                  : () => _explain(simpler: _explanation != null),
              child: Text(
                _explanation == null
                    ? l10n.languageSentenceExplain
                    : l10n.languageSentenceSimpler,
              ),
            ),
            if (_pending case final pending?)
              TextButton(
                onPressed: pending.isCancelled
                    ? null
                    : () => setState(() => pending.cancel()),
                child: Text(l10n.cancel),
              ),
          ],
        ),
        if (widget.explanation.provider is! MockChatProvider)
          Text(l10n.languageSentenceExplainNotice, style: style.bodySmall),
        if (_pending != null) const LinearProgressIndicator(),
        if (_help.contains(SentenceHelp.hint)) ...[
          const SizedBox(height: 8),
          Text(card.hint),
        ],
        if (_help.contains(SentenceHelp.translation)) ...[
          const SizedBox(height: 8),
          SelectableText(card.translation),
        ],
        if (_explanation case final text?) ...[
          const SizedBox(height: 8),
          SelectableText(text),
        ],
        if (_error case final error?) Text(error),
        const SizedBox(height: 16),
        if (_showCheck) ...[
          Text(card.question, style: style.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < card.choices.length; i++)
                ChoiceChip(
                  label: Text(card.choices[i]),
                  selected: _choice == i,
                  onSelected: _checked || _saving
                      ? null
                      : (_) => setState(() => _choice = i),
                ),
            ],
          ),
          if (!_checked)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton(
                onPressed: _choice == null || _saving
                    ? null
                    : () => setState(() {
                        _checked = true;
                        _helpWhenChecked.addAll(_help);
                      }),
                child: Text(l10n.languageSentenceCheckAnswer),
              ),
            )
          else ...[
            Text(
              _choice == card.correctIndex
                  ? l10n.languageSentenceCorrect
                  : l10n.languageSentenceAnswer(
                      card.choices[card.correctIndex],
                    ),
            ),
            if (card.checkExplanation.isNotEmpty) Text(card.checkExplanation),
          ],
        ] else if (card.choices.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _showCheck = true),
              child: Text(l10n.languageSentenceCheck),
            ),
          ),
        const SizedBox(height: 16),
        Text(l10n.languageSentenceRate, style: style.titleMedium),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final rating in SentenceRating.values)
              OutlinedButton(
                onPressed: _saving || (_choice != null && !_checked)
                    ? null
                    : () => _finish(rating),
                child: Text(switch (rating) {
                  SentenceRating.unclear => l10n.languageSentenceUnclear,
                  SentenceRating.partial => l10n.languageSentencePartial,
                  SentenceRating.understood => l10n.languageSentenceUnderstood,
                }),
              ),
          ],
        ),
      ],
    );
  }
}

String sentenceSkillLabel(AppLocalizations l10n, SentenceSkill skill) =>
    switch (skill) {
      SentenceSkill.detail => l10n.languageSentenceDetail,
      SentenceSkill.sequence => l10n.languageSentenceSequence,
      SentenceSkill.condition => l10n.languageSentenceCondition,
      SentenceSkill.intention => l10n.languageSentenceIntention,
      SentenceSkill.cause => l10n.languageSkillCause,
      SentenceSkill.structure => l10n.languageSkillStructure,
      SentenceSkill.reference => l10n.languageSkillReference,
      SentenceSkill.collocation => l10n.languageSkillCollocation,
      SentenceSkill.discourse => l10n.languageSkillDiscourse,
      SentenceSkill.mainIdea => l10n.languageSkillMainIdea,
      SentenceSkill.inference => l10n.languageSkillInference,
    };
