import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/database.dart';
import 'language_store.dart';
import 'sentence_content.dart';

class SentenceBatchProposal {
  const SentenceBatchProposal({
    required this.id,
    required this.topic,
    required this.style,
    required this.glossLanguage,
    required this.model,
    required this.promptVersion,
    required this.isMock,
    required this.generatedAt,
    required this.cards,
    this.requestedCount,
  });

  final String id, glossLanguage, model;
  final SentenceTopic topic;
  final SentenceStyle style;
  final int promptVersion;
  final bool isMock;
  final DateTime generatedAt;
  final List<SentenceCard> cards;
  final int? requestedCount;
}

extension SentenceBatchStore on LanguageLearningStore {
  Future<void> saveSentenceBatch(
    SentenceBatchProposal proposal,
    Set<String> selected,
  ) => runOperation(() async {
    final cards = [
      for (final card in proposal.cards)
        if (selected.contains(card.id))
          {
            'id': card.id,
            'text': card.text,
            'hint': card.hint,
            'translation': card.translation,
            'level': card.level.name,
            'revision': card.revision,
            if (card.skill != null) 'skill': card.skill!.name,
            if (card.choices.isNotEmpty) ...{
              'question': card.question,
              'choices': card.choices,
              'correctIndex': card.correctIndex,
              'checkExplanation': card.checkExplanation,
            },
          },
    ];
    if (cards.isEmpty) return;
    await db
        .into(db.learningSentenceBatches)
        .insert(
          LearningSentenceBatchesCompanion.insert(
            id: proposal.id,
            language: 'en',
            topic: proposal.topic.name,
            style: proposal.style.name,
            glossLanguage: proposal.glossLanguage,
            model: proposal.model,
            promptVersion: proposal.promptVersion,
            isMock: proposal.isMock,
            cards: jsonEncode(cards),
            generatedAt: proposal.generatedAt,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    changed();
  });

  Future<List<LearningSentenceBatch>> savedSentenceBatches({int limit = 40}) =>
      (db.select(db.learningSentenceBatches)
            ..where(
              (row) => row.language.equals('en') & row.isMock.equals(false),
            )
            ..orderBy([
              (row) => OrderingTerm.desc(row.generatedAt),
              (row) => OrderingTerm.desc(row.rowId),
            ])
            ..limit(limit))
          .get();
}

SentenceBatch openSavedSentenceBatch(LearningSentenceBatch row) {
  final cards = jsonDecode(row.cards) as List<dynamic>;
  // Keep the content IDs stable while giving each run a fresh attempt ID.
  return SentenceBatch(
    cards.map((value) {
      final card = value as Map<String, dynamic>;
      return SentenceCard(
        id: card['id'] as String,
        text: card['text'] as String,
        hint: card['hint'] as String,
        translation: card['translation'] as String,
        level: SentenceLevel.values.byName(card['level'] as String),
        revision: card['revision'] as int,
        language: row.language,
        skill: SentenceSkill.values.asNameMap()[card['skill']],
        question: card['question'] as String? ?? '',
        choices: (card['choices'] as List?)?.cast<String>() ?? const [],
        correctIndex: card['correctIndex'] as int? ?? -1,
        checkExplanation: card['checkExplanation'] as String? ?? '',
      );
    }),
    generatedBy: row.isMock ? 'Mock' : row.model,
  );
}
