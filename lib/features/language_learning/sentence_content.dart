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

SentenceBatch localSentenceBatch({
  required SentenceTopic topic,
  required SentenceStyle style,
  SentenceLevel? level,
  required int count,
}) {
  final candidates = (switch ((topic, style)) {
    (SentenceTopic.travel, SentenceStyle.written) => _travelWritten,
    (SentenceTopic.travel, SentenceStyle.dialogue) => _travelDialogue,
    (SentenceTopic.dailyLife, SentenceStyle.written) => _dailyWritten,
    (SentenceTopic.dailyLife, SentenceStyle.dialogue) => _dailyDialogue,
  }).where((card) => level == null || card.level == level).toList()..shuffle();
  return SentenceBatch(candidates.take(count));
}

const _travelWritten = [
  SentenceCard(
    id: 'travel-written-gate',
    text: 'The flight to Rome now leaves from Gate 14 instead of Gate 6.',
    translation: '飞往罗马的航班现在从 14 号登机口出发，不再使用 6 号登机口。',
    hint: '“Instead of” introduces what has been replaced.',
    question: 'Where should passengers go now?',
    choices: ['Gate 6', 'Gate 14', 'The ticket desk'],
    correctIndex: 1,
    skill: SentenceSkill.detail,
    level: SentenceLevel.beginner,
  ),
  SentenceCard(
    id: 'travel-written-platform',
    text: 'Once the passengers have left the train, please let the next group board.',
    translation: '等乘客下车后，请让下一批乘客上车。',
    hint: 'Look for which action needs to finish before the other starts.',
    question: 'What should happen first?',
    choices: [
      'Passengers get off.',
      'The next group gets on.',
      'The train leaves.',
    ],
    correctIndex: 0,
    skill: SentenceSkill.sequence,
    level: SentenceLevel.intermediate,
  ),
];
const _travelDialogue = [
  SentenceCard(
    id: 'travel-dialogue-window',
    text: 'A: Is anyone sitting by the window?\nB: No, go ahead.',
    translation: '甲：靠窗的座位有人吗？\n乙：没有，你坐吧。',
    hint: '“Go ahead” gives permission in this situation.',
    question: 'What does B mean?',
    choices: [
      'A should leave.',
      'The window is open.',
      'A can take that seat.',
    ],
    correctIndex: 2,
    skill: SentenceSkill.intention,
    level: SentenceLevel.beginner,
  ),
  SentenceCard(
    id: 'travel-dialogue-bus',
    text: 'A: Will we make the last bus?\nB: Only if we leave right now.',
    translation: '甲：我们能赶上末班车吗？\n乙：只有现在就出发才有可能。',
    hint: '“Only if” marks a necessary condition.',
    question: 'What must happen for them to catch the bus?',
    choices: [
      'They need to leave now.',
      'They have to wait here.',
      'They need another ticket.',
    ],
    correctIndex: 0,
    skill: SentenceSkill.condition,
    level: SentenceLevel.intermediate,
  ),
];
const _dailyWritten = [
  SentenceCard(
    id: 'daily-written-library',
    text: 'On Saturdays, the library closes at noon rather than at six.',
    translation: '图书馆周六中午关门，不是六点。',
    hint:
        '“Rather than” contrasts the actual closing time with a different one.',
    question: 'When does the library close on Saturdays?',
    choices: ['At six', 'At noon', 'At midnight'],
    correctIndex: 1,
    skill: SentenceSkill.detail,
    level: SentenceLevel.beginner,
  ),
  SentenceCard(
    id: 'daily-written-package',
    text: 'Leave the parcel at reception unless the office door is open.',
    translation: '如果办公室的门没开，就把包裹放在前台。',
    hint: '“Unless” introduces an exception to the instruction.',
    question: 'When should you leave the parcel at reception?',
    choices: [
      'When reception is closed.',
      'When the office door is open.',
      'When the office door is not open.',
    ],
    correctIndex: 2,
    skill: SentenceSkill.condition,
    level: SentenceLevel.intermediate,
  ),
];
const _dailyDialogue = [
  SentenceCard(
    id: 'daily-dialogue-tea',
    text: 'A: Would you like some more tea?\nB: I am fine, thanks.',
    translation: '甲：要再来点茶吗？\n乙：不用了，谢谢。',
    hint: 'Listen for whether B accepts the offer.',
    question: 'What does B mean?',
    choices: [
      'B does not want more tea.',
      'B has not tried the tea.',
      'B wants another cup.',
    ],
    correctIndex: 0,
    skill: SentenceSkill.intention,
    level: SentenceLevel.beginner,
  ),
  SentenceCard(
    id: 'daily-dialogue-dinner',
    text: 'A: Is everything ready for dinner?\nB: Almost. Let me set the table before we serve the soup.',
    translation: '甲：晚餐都准备好了吗？\n乙：差不多了。先让我摆好餐具，再上汤。',
    hint: '“Before” links two actions in order.',
    question: 'What does B want to do first?',
    choices: ['Serve the soup.', 'Wash the dishes.', 'Set the table.'],
    correctIndex: 2,
    skill: SentenceSkill.sequence,
    level: SentenceLevel.intermediate,
  ),
];
