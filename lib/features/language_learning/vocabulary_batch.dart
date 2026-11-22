import "dart:async";

import "package:material_ui/material_ui.dart";

import "language_layout.dart";

import "package:uuid/uuid.dart";

import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/l10n/generated/app_localizations.dart";
import "../../core/ui/actions.dart";
import "language_store.dart";
import "lexical_form_screen.dart";
import "lexical_form_store.dart";
import "vocabulary_editor.dart";

enum VocabularyMode { study, recall, context, recognition }

class VocabularyBatch extends StatefulWidget {
  const VocabularyBatch({
    super.key,
    required this.store,
    required this.language,
    required this.mode,
    this.group,
    this.dueBefore,
  });

  final LanguageLearningStore store;
  final String language;
  final VocabularyMode mode;
  final LearningVocabularyGroup? group;
  final DateTime? dueBefore;

  @override
  State<VocabularyBatch> createState() => _VocabularyBatchState();
}

class _VocabularyBatchState extends State<VocabularyBatch> {
  static const _uuid = Uuid();
  final _answer = TextEditingController();
  late Future<List<LanguageCard>> _batch = _load();
  bool? _recognized;
  int _current = 0;
  int _offset = 0;
  String _attemptId = _uuid.v4();
  bool _revealed = false;
  bool _saving = false;
  LearningEvidenceData? _result;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<List<LanguageCard>> _load() => widget.store.cards(
    language: widget.language,
    groupId: widget.group?.id,
    dueBefore: widget.dueBefore,
    contextsOnly: widget.mode == VocabularyMode.context,
    offset: _offset,
  );

  void _resetCard() {
    _recognized = null;
    _attemptId = _uuid.v4();
    _answer.clear();
    _revealed = false;
    _result = null;
  }

  void _advance() => setState(() {
    _current++;
    _resetCard();
  });

  void _nextBatch() => setState(() {
    _offset += languageBatchSize;
    _current = 0;
    _resetCard();
    _batch = _load();
  });

  Future<void> _save(Future<void> Function() operation) async {
    if (_saving) return;
    setState(() => _saving = true);
    await act(context, operation);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title =
        widget.group?.title ??
        (widget.mode == VocabularyMode.context
            ? l10n.languageNewContexts
            : l10n.languageReview);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<LanguageCard>>(
        future: _batch,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton(
                onPressed: () => setState(() => _batch = _load()),
                child: Text(l10n.retry),
              ),
            );
          }
          final cards = snapshot.requireData;
          final canContinue =
              widget.dueBefore == null && cards.length == languageBatchSize;
          final nextBatch = OutlinedButton(
            onPressed: _nextBatch,
            child: Text(l10n.languageNextBatch),
          );
          final Widget content;
          if (cards.isEmpty || _current >= cards.length) {
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _offset == 0 && cards.isEmpty
                      ? (widget.mode == VocabularyMode.context
                            ? l10n.languageNoContexts
                            : l10n.languageNoCards)
                      : l10n.languageBatchComplete,
                ),
                if (canContinue) nextBatch,
              ],
            );
          } else if (widget.mode == VocabularyMode.study) {
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final card in cards)
                  Card(
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(card.item.form),
                      subtitle: Text(card.sense.meaning),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: VocabularyDetails(
                            card: card,
                            store: widget.store,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (canContinue) nextBatch,
              ],
            );
          } else {
            final card = cards[_current];
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("${_current + 1} / ${cards.length}"),
                const SizedBox(height: 12),
                if (widget.mode == VocabularyMode.recall)
                  _recall(card)
                else if (widget.mode == VocabularyMode.recognition)
                  _recognition(card, cards)
                else
                  _context(card),
                const SizedBox(height: 12),
                if (_result == null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: _saving ? null : _advance,
                      child: Text(l10n.languageSkip),
                    ),
                  ),
              ],
            );
          }
          return languagePage(
            gap: 0,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: content,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _recognition(LanguageCard card, List<LanguageCard> pool) {
    final l10n = context.l10n;
    final others = pool
        .where(
          (entry) =>
              entry.item.normalizedForm != card.item.normalizedForm &&
              entry.sense.meaning != card.sense.meaning,
        )
        .map((entry) => entry.sense.meaning)
        .toSet()
        .take(3);
    final choices = [card.sense.meaning, ...others]..sort();
    if (choices.length < 2) return Text(l10n.languageNoRecognitionOptions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(card.item.form, style: Theme.of(context).textTheme.headlineMedium),
        if (_recognized case final correct?) ...[
          Text(correct ? l10n.languageCorrect : card.sense.meaning),
          TextButton(onPressed: _advance, child: Text(l10n.languageNext)),
        ] else
          for (final choice in choices)
            OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => _save(() async {
                      final result = await widget.store
                          .recordMeaningRecognition(
                            card,
                            choice,
                            attemptId: _attemptId,
                            usedHelp: widget.group != null,
                          );
                      if (mounted) setState(() => _recognized = result);
                    }),
              child: Text(choice),
            ),
      ],
    );
  }

  Widget _recall(LanguageCard card) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(card.item.form, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        if (_revealed) ...[
          Text(
            card.sense.meaning,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          VocabularyDetails(
            key: ValueKey(_attemptId),
            card: card,
            store: widget.store,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final rating in RecallRating.values)
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => _save(() async {
                          await widget.store.recordRecall(
                            attemptId: _attemptId,
                            senseId: card.sense.id,
                            rating: rating,
                            groupPrompt: widget.group != null,
                          );
                          if (mounted) _advance();
                        }),
                  child: Text(_rating(l10n, rating)),
                ),
            ],
          ),
        ] else
          FilledButton(
            onPressed: () => setState(() => _revealed = true),
            child: Text(l10n.languageReveal),
          ),
      ],
    );
  }

  Widget _context(LanguageCard card) {
    final l10n = context.l10n;
    final result = _result;
    void submit() {
      if (_answer.text.trim().isEmpty) return;
      unawaited(
        _save(() async {
          final attempt = await widget.store.recordApplication(
            attemptId: _attemptId,
            senseId: card.sense.id,
            answer: _answer.text,
            usedHelp: false,
            groupPrompt: widget.group != null,
          );
          if (mounted) setState(() => _result = attempt);
        }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          card.sense.application!,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _answer,
          enabled: !_saving && result == null,
          decoration: InputDecoration(labelText: l10n.languageAnswer),
          onSubmitted: (_) => submit(),
        ),
        const SizedBox(height: 12),
        if (result != null) ...[
          Text(
            result.correct == true
                ? l10n.languageCorrect
                : l10n.languageIncorrect,
          ),
          Text(l10n.languageExpected(card.sense.applicationAnswer!)),
          FilledButton(onPressed: _advance, child: Text(l10n.languageNext)),
        ] else
          FilledButton(
            onPressed: _saving ? null : submit,
            child: Text(l10n.languageCheck),
          ),
      ],
    );
  }

  String _rating(AppLocalizations l10n, RecallRating rating) =>
      switch (rating) {
        RecallRating.forgot => l10n.languageForgot,
        RecallRating.fuzzy => l10n.languageFuzzy,
        RecallRating.remembered => l10n.languageRemembered,
        RecallRating.easy => l10n.languageEasy,
      };
}

class VocabularyDetails extends StatefulWidget {
  const VocabularyDetails({super.key, required this.card, this.store});

  final LanguageCard card;
  final LanguageLearningStore? store;

  @override
  State<VocabularyDetails> createState() => _VocabularyDetailsState();
}

class _VocabularyDetailsState extends State<VocabularyDetails> {
  bool _translation = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final card = widget.card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lexicalTypeLabel(
            l10n,
            LexicalType.values.byName(card.item.lexicalType),
          ),
        ),
        if (card.sense.source == "ai")
          Text(l10n.languageAiSource(card.sense.aiModel ?? "")),
        if (card.sense.source == "mock") Text(l10n.languageAiMockSource),
        if (widget.store case final store? when card.item.language == "en")
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LexicalFormsScreen(
                  store,
                  language: card.item.language,
                  card: card,
                ),
              ),
            ),
            child: Text(l10n.languageForms),
          ),
        if (card.sense.example case final example?) Text(example),
        if (card.sense.exampleTranslation case final translation?)
          if (_translation)
            Text(translation)
          else
            TextButton(
              onPressed: () => setState(() => _translation = true),
              child: Text(l10n.languageTranslationReveal),
            ),
      ],
    );
  }
}
