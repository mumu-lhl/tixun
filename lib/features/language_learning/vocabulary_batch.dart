import "dart:async";
import "dart:math";

import "package:material_ui/material_ui.dart";
import "package:uuid/uuid.dart";
import "package:dio/dio.dart";

import "../../core/database/database.dart";
import "../../core/ai/chat_provider.dart" show CancelGuard, MockChatProvider;
import "../../core/l10n/app_strings.dart";
import "../../core/l10n/generated/app_localizations.dart";
import "../../core/ui/actions.dart";
import "language_layout.dart";
import "language_store.dart";
import "lexical_form_screen.dart";
import "lexical_form_store.dart";
import "vocabulary_editor.dart";
import "vocabulary_example.dart";
import "vocabulary_ai.dart";

enum VocabularyMode { study, recall, recognition }

class VocabularyBatch extends StatefulWidget {
  const VocabularyBatch({
    super.key,
    required this.store,
    required this.language,
    required this.mode,
    this.group,
    this.dueBefore,
    this.ai,
    this.config,
  });

  final LanguageLearningStore store;
  final String language;
  final VocabularyAi? ai;
  final ProviderConfig? config;
  final VocabularyMode mode;
  final LearningVocabularyGroup? group;
  final DateTime? dueBefore;

  @override
  State<VocabularyBatch> createState() => _VocabularyBatchState();
}

class _VocabularyBatchState extends State<VocabularyBatch> {
  static const _uuid = Uuid();
  late Future<List<LanguageCard>> _batch = _load();
  bool? _recognized;
  int _current = 0;
  int _offset = 0;
  bool _showFlashcards = false;
  int _studyIndex = 0;
  String _attemptId = _uuid.v4();
  bool _revealed = false;
  bool _saving = false;
  LearningEvidenceData? _result;
  CancelToken? _regenerating;

  @override
  void dispose() {
    _regenerating?.cancel();
    super.dispose();
  }

  Future<List<LanguageCard>> _load() => widget.store.cards(
    language: widget.language,
    groupId: widget.group?.id,
    dueBefore: widget.dueBefore,
    offset: _offset,
  );

  void _resetCard() {
    _recognized = null;
    _attemptId = _uuid.v4();
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
    _studyIndex = 0;
    _resetCard();
    _batch = _load();
  });

  Future<void> _save(Future<void> Function() operation) async {
    if (_saving) return;
    setState(() => _saving = true);
    await act(context, operation);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _regenerate(LanguageCard card) async {
    if (_saving || widget.ai == null || widget.config == null) return;
    final cancel = CancelToken();
    setState(() {
      _saving = true;
      _regenerating = cancel;
    });
    await act(context, () async {
      final result = await widget.ai!.revise(
        config: widget.config!,
        card: card,
        glossLanguage: Localizations.localeOf(context).languageCode,
        cancel: cancel,
      );
      cancel.checkCancelled();
      if (result.generation != null) {
        await widget.store.reviseVocabulary(
          card,
          result.entry,
          result.generation!,
        );
      }
      if (mounted) setState(() => _batch = _load());
    });
    if (mounted) {
      setState(() {
        _saving = false;
        _regenerating = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = widget.group?.title ?? l10n.languageReview;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.ai != null &&
              widget.ai!.provider is! MockChatProvider &&
              widget.mode == VocabularyMode.study)
            FutureBuilder<List<LanguageCard>>(
              future: _batch,
              builder: (context, snapshot) {
                final cards = snapshot.data ?? const <LanguageCard>[];
                return IconButton(
                  tooltip: l10n.languageRegenerateCompare,
                  onPressed: _saving || cards.isEmpty
                      ? null
                      : () => _regenerate(
                          cards[_studyIndex.clamp(0, cards.length - 1)],
                        ),
                  icon: const Icon(Icons.refresh),
                );
              },
            ),
          if (_regenerating != null)
            IconButton(
              tooltip: l10n.cancel,
              onPressed: () => _regenerating?.cancel(),
              icon: const Icon(Icons.stop),
            ),
        ],
      ),
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
                      ? l10n.languageNoCards
                      : l10n.languageBatchComplete,
                ),
                if (canContinue) nextBatch,
              ],
            );
          } else if (widget.mode == VocabularyMode.study) {
            content = _study(cards, nextBatch: canContinue ? nextBatch : null);
          } else {
            final card = cards[_current];
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("${_current + 1} / ${cards.length}"),
                const SizedBox(height: 12),
                if (widget.mode == VocabularyMode.recall)
                  _recall(card)
                else
                  _recognition(card, cards),
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
          final page = languagePage(
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
          if (widget.mode == VocabularyMode.study &&
              _showFlashcards &&
              cards.isNotEmpty) {
            return Column(
              children: [
                Expanded(child: page),
                _studyNavigation(
                  cards,
                  nextBatch: canContinue ? nextBatch : null,
                ),
              ],
            );
          }
          return page;
        },
      ),
    );
  }

  Widget _study(List<LanguageCard> cards, {Widget? nextBatch}) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(l10n.languageVocabularyList),
              ),
              ButtonSegment(
                value: true,
                label: Text(l10n.languageVocabularyFlashcards),
              ),
            ],
            selected: {_showFlashcards},
            onSelectionChanged: (values) =>
                setState(() => _showFlashcards = values.single),
          ),
        ),
        if (_showFlashcards) ...[
          _VocabularyFlashcard(
            key: ValueKey(cards[_studyIndex].sense.id),
            card: cards[_studyIndex],
            store: widget.store,
            revealed: true,
          ),
        ] else
          for (final card in cards)
            Card(
              key: ValueKey(card.sense.id),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(card.item.form),
                subtitle: Text(card.sense.meaning),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: VocabularyDetails(card: card, store: widget.store),
                  ),
                ],
              ),
            ),
        if (!_showFlashcards) ?nextBatch,
      ],
    );
  }

  Widget _studyNavigation(List<LanguageCard> cards, {Widget? nextBatch}) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const Key("flashcard-navigation"),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: l10n.languagePrevious,
                    onPressed: (_saving || _studyIndex == 0)
                        ? null
                        : () => setState(() => _studyIndex--),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text("${_studyIndex + 1} / ${cards.length}"),
                  ),
                  IconButton.filledTonal(
                    tooltip: l10n.languageNext,
                    onPressed: (_saving || _studyIndex == cards.length - 1)
                        ? null
                        : () => setState(() => _studyIndex++),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.languageRandomCard,
                    onPressed: _saving || cards.length < 2
                        ? null
                        : () => setState(() {
                            final index = Random().nextInt(cards.length - 1);
                            _studyIndex = index < _studyIndex
                                ? index
                                : index + 1;
                          }),
                    icon: const Icon(Icons.shuffle),
                  ),
                ],
              ),
            ),
            if (nextBatch != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: nextBatch),
          ],
        ),
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
      spacing: 16,
      children: [
        _VocabularyFlashcard(
          key: ValueKey(_attemptId),
          card: card,
          store: widget.store,
          revealed: _revealed,
        ),
        if (_revealed)
          Wrap(
            alignment: WrapAlignment.center,
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
          )
        else
          FilledButton(
            onPressed: () => setState(() => _revealed = true),
            child: Text(l10n.languageReveal),
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

class _VocabularyFlashcard extends StatefulWidget {
  const _VocabularyFlashcard({
    super.key,
    required this.card,
    required this.store,
    required this.revealed,
  });

  final LanguageCard card;
  final LanguageLearningStore store;
  final bool revealed;

  @override
  State<_VocabularyFlashcard> createState() => _VocabularyFlashcardState();
}

class _VocabularyFlashcardState extends State<_VocabularyFlashcard> {
  bool _translation = false;
  LanguageCard get card => widget.card;
  LanguageLearningStore get store => widget.store;
  bool get revealed => widget.revealed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sense = card.sense;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          color: colors.surfaceContainerHigh,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 260),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                Column(
                  spacing: 4,
                  children: [
                    Text(
                      card.item.form,
                      style: theme.textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (sense.partOfSpeech case final partOfSpeech?)
                      Text(
                        partOfSpeech,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
                if (revealed) ...[
                  SizedBox(
                    width: 40,
                    child: Divider(height: 1, color: colors.outlineVariant),
                  ),
                  Text(
                    sense.meaning,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (sense.example != null)
                    VocabularyExampleText(
                      card: card,
                      store: store,
                      textAlign: TextAlign.center,
                    ),
                  if (_translation && sense.exampleTranslation != null)
                    Text(
                      sense.exampleTranslation!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (sense.exampleTranslation != null)
                        OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _translation = !_translation),
                          icon: const Icon(Icons.translate, size: 18),
                          label: Text(
                            _translation
                                ? context.l10n.languageTranslationHide
                                : context.l10n.languageTranslationReveal,
                          ),
                        ),
                      if (card.item.language == "en")
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => LexicalFormsScreen(
                                store,
                                language: card.item.language,
                                card: card,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.spellcheck, size: 18),
                          label: Text(context.l10n.languageForms),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VocabularyDetails extends StatelessWidget {
  const VocabularyDetails({super.key, required this.card, this.store});

  final LanguageCard card;
  final LanguageLearningStore? store;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lexicalTypeLabel(
            l10n,
            LexicalType.values.byName(card.item.lexicalType),
          ),
        ),
        if (card.sense.partOfSpeech case final partOfSpeech?)
          Text(partOfSpeech),
        if (card.sense.source == "ai")
          Text(l10n.languageAiSource(card.sense.aiModel ?? "")),
        if (card.sense.source == "mock") Text(l10n.languageAiMockSource),
        if (store case final store? when card.item.language == "en")
          _VocabularyFormsLink(store: store, card: card),
        _VocabularyExample(card: card, store: store),
      ],
    );
  }
}

class _VocabularyFormsLink extends StatelessWidget {
  const _VocabularyFormsLink({required this.store, required this.card});

  final LanguageLearningStore store;
  final LanguageCard card;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            LexicalFormsScreen(store, language: card.item.language, card: card),
      ),
    ),
    child: Text(context.l10n.languageForms),
  );
}

class _VocabularyExample extends StatefulWidget {
  const _VocabularyExample({required this.card, this.store});

  final LanguageCard card;
  final LanguageLearningStore? store;

  @override
  State<_VocabularyExample> createState() => _VocabularyExampleState();
}

class _VocabularyExampleState extends State<_VocabularyExample> {
  bool _translation = false;

  @override
  Widget build(BuildContext context) {
    final sense = widget.card.sense;
    const alignment = TextAlign.start;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sense.example != null)
          VocabularyExampleText(
            card: widget.card,
            store: widget.store,
            textAlign: alignment,
          ),
        if (sense.exampleTranslation case final translation?)
          if (_translation)
            Text(translation, textAlign: alignment)
          else
            TextButton(
              onPressed: () => setState(() => _translation = true),
              child: Text(
                context.l10n.languageTranslationReveal,
                textAlign: alignment,
              ),
            ),
      ],
    );
  }
}
