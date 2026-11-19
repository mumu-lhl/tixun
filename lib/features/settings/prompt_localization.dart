import 'package:flutter/widgets.dart';

import '../../core/ai/prompt_settings.dart';
import '../../core/l10n/app_strings.dart';

String promptTitle(
  BuildContext context,
  PromptDefinition prompt,
) => switch (prompt.id) {
  'exam_scores' => context.l10n.extractExamQuestionMarks,
  'global' => context.l10n.generalTeachingStyle,
  'guided' => context.l10n.guidedLearning,
  'direct' => context.l10n.directAnswer,
  'exam' => context.l10n.examPractice,
  'knowledge' => context.l10n.knowledgeExplanations,
  'knowledge_writing' => context.l10n.knowledgeGenerationAndOrganization,
  'knowledge_editing' => context.l10n.knowledgeEditingAndMerging,
  'mistake_analysis' => context.l10n.mistakeAnalysis,
  'mistake' => context.l10n.mistakeExplanations,
  'quiz' => context.l10n.quizGeneration,
  'variant' => context.l10n.correctionsAndVariations,
  'split' => context.l10n.imageQuestionSplitting,
  'language_vocabulary' => context.l10n.languagePromptVocabularyTitle,
  'language_sentence_batch' => context.l10n.languagePromptSentenceBatchTitle,
  'language_sentence_check' => context.l10n.languagePromptSentenceCheckTitle,
  'language_explanation' => context.l10n.languagePromptExplanationTitle,
  'language_exam_generation' => context.l10n.languagePromptExamTitle,
  'language_writing_task' => context.l10n.languagePromptWritingTaskTitle,
  'language_writing' => context.l10n.languagePromptWritingFeedbackTitle,
  _ => prompt.title,
};

String promptDescription(BuildContext context, PromptDefinition prompt) =>
    switch (prompt.id) {
      'exam_scores' => context.l10n.extractAnUnverifiedBreakdownFrom,
      'global' => context.l10n.appliesToAllLearningRequests,
      'guided' => context.l10n.defaultTeachingStyleForRegular,
      'direct' => context.l10n.usedWhenDirectAnswerIs,
      'exam' => context.l10n.teachingStyleForExamPractice,
      'knowledge' => context.l10n.usedWhenOpeningAConversation,
      'knowledge_writing' => context.l10n.usedWhenGeneratingKnowledgeFrom,
      'knowledge_editing' => context.l10n.usedWhenEditingExistingKnowledge,
      'mistake_analysis' => context.l10n.usedWhenRequestingAComplete,
      'mistake' => context.l10n.usedForGuidedExplanationsFrom,
      'quiz' => context.l10n.requestsForQuickQuizzesAnd,
      'variant' => context.l10n.usedWhenStartingRelatedPractice,
      'split' => context.l10n.usedToRequestSplittingSuggestions,
      'language_vocabulary' => context.l10n.languagePromptVocabularyDesc,
      'language_sentence_batch' => context.l10n.languagePromptSentenceBatchDesc,
      'language_sentence_check' => context.l10n.languagePromptSentenceCheckDesc,
      'language_explanation' => context.l10n.languagePromptExplanationDesc,
      'language_exam_generation' => context.l10n.languagePromptExamDesc,
      'language_writing_task' => context.l10n.languagePromptWritingTaskDesc,
      'language_writing' => context.l10n.languagePromptWritingFeedbackDesc,
      _ => prompt.description,
    };

String promptGroupLabel(BuildContext context, PromptGroup group) =>
    switch (group) {
      PromptGroup.teaching => context.l10n.promptGroupTeaching,
      PromptGroup.knowledge => context.l10n.promptGroupKnowledge,
      PromptGroup.practice => context.l10n.promptGroupPractice,
      PromptGroup.language => context.l10n.promptGroupLanguage,
    };
