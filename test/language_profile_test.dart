import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/features/language_learning/exam_material.dart';
import 'package:tixun/features/language_learning/exam_store.dart';
import 'package:tixun/features/language_learning/language_profile_store.dart';
import 'package:tixun/features/language_learning/language_skills.dart';
import 'package:tixun/features/language_learning/language_store.dart';
import 'package:tixun/features/language_learning/lexical_form.dart';
import 'package:tixun/features/language_learning/lexical_form_store.dart';
import 'package:tixun/features/language_learning/sentence_content.dart';
import 'package:tixun/features/language_learning/sentence_store.dart';

import 'support/exam_bundled.dart';

void main() {
  late AppDatabase db;
  late LanguageLearningStore store;
  setUp(() {
    db = AppDatabase.memory();
    store = LanguageLearningStore(db);
  });
  tearDown(() async {
    store.dispose();
    await db.close();
  });

  test('inflections share a lemma without creating cards and forms keep distinct evidence', () async {
    for (final group in ['Verbs', 'Review']) {
      await store.saveEntries(
        language: 'en',
        groupTitle: group,
        groupType: VocabularyGroupType.topic,
        entries: const [
          VocabularyEntry(
            form: 'go',
            meaning: '去',
            forms: [
              LexicalFormDraft('went', Inflection.past),
              LexicalFormDraft('gone', Inflection.pastParticiple),
            ],
          ),
          VocabularyEntry(
            form: 'see',
            meaning: '看见',
            forms: [LexicalFormDraft('saw', Inflection.past)],
          ),
          VocabularyEntry(
            form: 'saw',
            meaning: '锯子',
            forms: [LexicalFormDraft('saws', Inflection.plural)],
          ),
          VocabularyEntry(
            form: 'study',
            meaning: '学习',
            forms: [
              LexicalFormDraft('studied', Inflection.past),
              LexicalFormDraft('studied', Inflection.pastParticiple),
            ],
          ),
        ],
      );
    }
    expect(await db.select(db.learningLexicalForms).get(), hasLength(6));
    expect(await store.dueCount('en').first, 4);
    final exercises = await store.formPractice('en');
    final saw = exercises.singleWhere((e) => e.form.surface == 'saw');
    expect(saw.item.form, 'see');
    expect(
      await store.recordFormPractice(
        attemptId: 'r',
        exercise: saw,
        answer: 'see',
        production: false,
      ),
      isTrue,
    );
    expect(
      await store.recordFormPractice(
        attemptId: 'p',
        exercise: saw,
        answer: 'saw',
        production: true,
      ),
      isTrue,
    );
    expect(
      await store.recordFormPractice(
        attemptId: 'p2',
        exercise: saw,
        answer: 'seen',
        production: true,
      ),
      isFalse,
    );
    final profile = await store.readLanguageProfile('en');
    expect(profile.skills[LanguageSkill.formRecognition]!.independent, 1);
    final production = profile.skills[LanguageSkill.formProduction]!;
    expect(production.independent, 1);
    expect(production.count(EvidenceKind.repeat), 1);
    expect(production.uncertain, isTrue);
    expect(profile.skills[LanguageSkill.wordRecall]!.observations, isEmpty);
    expect(
      (await store.readLanguageProfile('ja')).skills.values
          .every((r) => r.observations.isEmpty),
      isTrue,
    );
  });

  test('first verified exam, assisted sentence and unverified content retain distinct provenance', () async {
    final target = ExamTarget(
      kind: ExamKind.grammar,
      count: 5,
      level: SentenceLevel.beginner,
    );
    final fixture = bundledExamPapers(ExamKind.grammar).single.paper;
    final saved = await store.saveExamMaterial(
      target: target,
      paper: fixture,
      source: ExamSource.aiGenerated,
      id: 'paper',
      model: 'Fixture',
      promptVersion: 1,
    );
    final reviewed = await store.markExamAiReviewed(saved);
    final result = await store.submitExam(
      material: reviewed,
      attemptId: 'first',
      responses: fixture.items.map((i) => i.answers.first).toList(),
      confidence: ExamConfidence.certain,
      hintUsed: false,
    );
    final card = SentenceCard(
      id: 'sentence',
      text: 'I went yesterday.',
      translation: '',
      hint: '',
      question: 'When?',
      choices: const ['Yesterday', 'Tomorrow'],
      correctIndex: 0,
      skill: SentenceSkill.sequence,
      level: SentenceLevel.beginner,
    );
    for (final (id, helps) in [
      ('alone', <SentenceHelp>{}),
      ('repeat', <SentenceHelp>{SentenceHelp.hint}),
    ]) {
      await store.recordSentence(
        batchId: id,
        card: card,
        rating: SentenceRating.understood,
        helpUsed: helps,
        helpBeforeAnswer: helps,
        selectedIndex: 0,
      );
    }
    var profile = await store.readLanguageProfile('en');
    expect(profile.skills[LanguageSkill.grammar]!.independent, 5);
    expect(profile.skills[LanguageSkill.grammar]!.uncertain, true);
    expect(profile.skills[LanguageSkill.sequence]!.tentative, 1);
    expect(
      profile.skills[LanguageSkill.sequence]!.count(EvidenceKind.repeat),
      1,
    );
    await store.flagExamResponse(result, 0);
    profile = await store.readLanguageProfile('en');
    expect(profile.skills[LanguageSkill.grammar]!.independent, 0);
    expect(
      profile.skills[LanguageSkill.grammar]!.count(EvidenceKind.disputed),
      5,
    );
  });

  test('recommendation favors weak evidence, rotates recent work, and supports a difficulty override', () {
    final now = DateTime(2026);
    LanguageProfile profile(List<LanguageObservation> observations) =>
        LanguageProfile(
          language: 'en',
          exam: ExamProfile.zhejiang2026,
          due: 2,
          evidence: observations,
          hasApplications: false,
          hasForms: false,
        );
    final weak = [
      for (var i = 0; i < 3; i++)
        LanguageObservation(
          id: 'weak-$i',
          skill: LanguageSkill.condition,
          kind: EvidenceKind.independent,
          at: now.subtract(Duration(days: i)),
          basis: 'item',
          correct: false,
        ),
    ];
    final active = [
      for (var i = 0; i < 3; i++)
        LanguageObservation(
          id: 'other-$i',
          skill: LanguageSkill.sequence,
          kind: EvidenceKind.independent,
          at: now.add(Duration(days: i + 1)),
          basis: 'item',
          correct: true,
        ),
    ];
    expect(
      recommendLanguage(
        profile([...weak, ...active]),
        LanguageGoal.communication,
      ).skill,
      LanguageSkill.condition,
    );
    final rotated = recommendLanguage(
      profile(weak),
      LanguageGoal.communication,
      difficulty: SentenceLevel.intermediate,
    );
    expect(rotated.skill, isNot(LanguageSkill.condition));
    expect(rotated.level, SentenceLevel.intermediate);
    expect(
      recommendLanguage(profile([]), LanguageGoal.exam).skill,
      LanguageSkill.reading,
    );
  });
}
