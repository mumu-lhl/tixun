import "package:material_ui/material_ui.dart";

import "exam_material.dart";
import "language_profile_screen.dart";
import "language_skills.dart";
import "language_store.dart";
import "lexical_form_screen.dart";
import "next_practice.dart";
import "sentence_store.dart";
import "vocabulary_batch.dart";

Future<void> openLanguageRecommendation(
  BuildContext context,
  LanguageLearningStore store,
  LanguageProfile profile,
  LanguageRecommendation plan,
  LanguageGoal goal, {
  required VoidCallback foundations,
  required VoidCallback writing,
  required void Function(ExamTarget) exam,
  required void Function(SentencePlan) sentences,
}) async {
  if (profile.language != "en") {
    foundations();
    return;
  }
  final skill = plan.skill;
  final sentenceSkill = sentenceSkillForAbility(skill);
  if (goal == LanguageGoal.exam) {
    if (skill == LanguageSkill.writingTask) {
      writing();
      return;
    }
    final kind = switch (skill) {
      LanguageSkill.insertion => ExamKind.sentenceInsertion,
      LanguageSkill.cloze => ExamKind.cloze,
      LanguageSkill.grammar => ExamKind.grammar,
      _ => ExamKind.reading,
    };
    exam(
      ExamTarget(
        kind: kind,
        level: plan.level,
        count: kind == ExamKind.sentenceInsertion ? 5 : plan.count,
        skill: sentenceSkill,
        profile: profile.exam,
      ),
    );
    return;
  }

  if (skill == LanguageSkill.formRecognition ||
      skill == LanguageSkill.formProduction) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LexicalFormsScreen(
          store,
          language: profile.language,
          initialProduction: skill == LanguageSkill.formProduction,
        ),
      ),
    );
    return;
  }
  if (sentenceSkill == null) {
    if (goal == LanguageGoal.foundations &&
        (await store.cards(language: profile.language)).isEmpty) {
      foundations();
      return;
    }
    if (!context.mounted) return;
    final mode = switch (skill) {
      LanguageSkill.wordRecognition => VocabularyMode.recognition,
      LanguageSkill.wordRecall => VocabularyMode.recall,
      _ => VocabularyMode.recall,
    };
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VocabularyBatch(
          store: store,
          language: profile.language,
          mode: mode,
        ),
      ),
    );
    return;
  }
  final evidence = await store.sentenceEvidence(profile.language).first;
  if (!context.mounted) return;
  sentences(sentencePlan(profile, plan, evidence.map((row) => row.sentence)));
}
