import 'package:flutter/widgets.dart';

import '../../core/ai/prompt_settings.dart';
import '../../core/l10n/app_strings.dart';

String promptTitle(BuildContext context, PromptDefinition prompt) =>
    switch (prompt.id) {
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
      _ => prompt.description,
    };
