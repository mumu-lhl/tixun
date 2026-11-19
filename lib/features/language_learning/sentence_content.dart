import 'package:uuid/uuid.dart';

enum SentenceStyle { written, dialogue }

enum SentenceTopic { travel, dailyLife }

enum SentenceLevel { beginner, intermediate }

enum SentenceSkill {
  detail,
  sequence,
  condition,
  intention,
  cause,
  structure,
  reference,
  collocation,
  discourse,
}

enum SentenceHelp {
  hint(1),
  translation(2),
  explanation(4);

  const SentenceHelp(this.flag);
  final int flag;

  static int encode(Set<SentenceHelp> values) =>
      values.fold(0, (bits, value) => bits | value.flag);
}

enum SentenceRating { unclear, partial, understood }

class SentenceCard {
  const SentenceCard({
    required this.id,
    required this.text,
    required this.translation,
    required this.hint,
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.skill,
    required this.level,
    this.checkExplanation = '',
    this.revision = 1,
    this.language = 'en',
  });

  const SentenceCard.study({
    required this.id,
    required this.text,
    required this.translation,
    required this.hint,
    required this.level,
    this.revision = 1,
    this.language = 'en',
    this.skill,
  }) : choices = const [],
       question = '',
       checkExplanation = '',
       correctIndex = -1;

  final String id,
      text,
      translation,
      hint,
      question,
      language,
      checkExplanation;
  final int revision, correctIndex;
  final List<String> choices;
  final SentenceSkill? skill;
  final SentenceLevel level;
}

class SentenceBatch {
  SentenceBatch(Iterable<SentenceCard> cards, {this.generatedBy})
    : id = const Uuid().v4(),
      cards = List.unmodifiable(cards);

  final String id;
  final List<SentenceCard> cards;
  final String? generatedBy;
}
