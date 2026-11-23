import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

import "../../app/controller.dart";
import "../../app/preferences.dart";
import "../../core/ai/ai_usage_store.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "language_course.dart";
import "language_data.dart";
import "language_profile_screen.dart";
import "language_recommendation.dart";
import "language_skills.dart";
import "language_store.dart";
import "next_practice.dart";
import "exam_ai.dart";
import "exam_lab.dart";
import "exam_labels.dart";
import "exam_material.dart";
import "sentence_batch_ai.dart";
import "sentence_content.dart";
import "sentence_explanation.dart";
import "sentence_practice.dart";
import "study_settings_dialog.dart";
import "vocabulary_batch.dart";
import "vocabulary_groups_screen.dart";
import "writing_lab.dart";
import "writing_task_ai.dart";
import "written_exam_lab.dart";
import "generation_ui.dart";

const _language = "en";

class LanguageLearningScreen extends ConsumerStatefulWidget {
  const LanguageLearningScreen({super.key});

  @override
  ConsumerState<LanguageLearningScreen> createState() =>
      _LanguageLearningScreenState();
}

class _LanguageLearningScreenState
    extends ConsumerState<LanguageLearningScreen> {
  late final _store = ref.read(appControllerProvider).language;
  AppPreferences get _preferences =>
      ref.read(appControllerProvider).preferences;
  String? get _feedbackLanguage {
    final value = _preferences.languageStudy.feedbackLanguage;
    return value == LanguageFeedbackLanguage.app ? null : value.name;
  }

  Stream<List<LearningEvidenceData>> _loadEvidence() =>
      _store.recentEvidence(_language);
  late Stream<int> _due = _store.dueCount(_language);
  late final Timer _dueRefresh;

  @override
  void initState() {
    super.initState();
    _dueRefresh = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshDue(),
    );
  }

  @override
  void dispose() {
    _dueRefresh.cancel();
    super.dispose();
  }

  void _refreshDue() => setState(() => _due = _store.dueCount(_language));

  Future<void> _review() async {
    await _openBatch(
      context,
      _store,
      VocabularyMode.recall,
      dueBefore: DateTime.now(),
    );
    if (mounted) _refreshDue();
  }

  void _practiceContexts() => _openSentences(contextUnderstanding: true);

  void _practiceSentences([SentencePlan? plan]) => _openSentences(plan: plan);

  void _openSentences({SentencePlan? plan, bool contextUnderstanding = false}) {
    final controller = ref.read(appControllerProvider);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SentencePractice(
          store: _store,
          contextUnderstanding: contextUnderstanding,
          recommendation: plan,
          initialLevel: switch (_preferences.languageStudy.level) {
            EnglishStudyLevel.mixed => null,
            EnglishStudyLevel.beginner => SentenceLevel.beginner,
            EnglishStudyLevel.intermediate => SentenceLevel.intermediate,
          },
          feedbackLanguage: _feedbackLanguage,
          batchAi: SentenceBatchAi(
            provider: languageGenerationProvider(context, controller),
            config: controller.config,
            usageStore: AiUsageStore(controller.db),
            prompts: controller.prompts,
          ),
          explanation: SentenceExplanation(
            store: _store,
            provider: languageGenerationProvider(context, controller),
            config: controller.config,
            usageStore: AiUsageStore(controller.db),
            prompts: controller.prompts,
          ),
        ),
      ),
    );
  }

  void _practiceExam(ExamKind kind, {ExamTarget? recommendation}) {
    final controller = ref.read(appControllerProvider);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExamLab(
          ai: ExamAi(
            provider: languageGenerationProvider(context, controller),
            config: controller.config,
            store: _store,
            usageStore: AiUsageStore(controller.db),
            prompts: controller.prompts,
          ),
          kind: kind,
          recommendation: recommendation,
          glossLanguage: _feedbackLanguage,
        ),
      ),
    );
  }

  void _practiceWriting() {
    final controller = ref.read(appControllerProvider);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WritingLab(
          glossLanguage: _feedbackLanguage,
          ai: WritingTaskAi(
            store: _store,
            provider: languageGenerationProvider(context, controller),
            config: controller.config,
            usageStore: AiUsageStore(controller.db),
            prompts: controller.prompts,
          ),
        ),
      ),
    );
  }

  void _foundations([String language = _language]) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LanguageCourse(
            store: _store,
            initialLanguage: language,
            openProfile: (language) =>
                _openProfile(LanguageGoal.foundations, language),
          ),
        ),
      );

  void _openProfile([
    LanguageGoal goal = LanguageGoal.communication,
    String language = _language,
  ]) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (profileContext) => LanguageProfileScreen(
        store: _store,
        language: language,
        goal: goal,
        onReview: _review,
        onPractice: (profile, plan, selectedGoal) => act(
          profileContext,
          () => openLanguageRecommendation(
            profileContext,
            _store,
            profile,
            plan,
            selectedGoal,
            foundations: () => _foundations(language),
            writing: _practiceWriting,
            exam: (target) =>
                _practiceExam(target.kind, recommendation: target),
            sentences: _practiceSentences,
          ),
        ),
      ),
    ),
  );

  void _writtenMock() {
    final controller = ref.read(appControllerProvider);
    final usage = AiUsageStore(controller.db);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WrittenExamLab(
          ai: ExamAi(
            provider: languageGenerationProvider(context, controller),
            config: controller.config,
            store: _store,
            usageStore: usage,
            prompts: controller.prompts,
          ),
          writing: WritingTaskAi(
            provider: languageGenerationProvider(context, controller),
            config: controller.config,
            store: _store,
            usageStore: usage,
            prompts: controller.prompts,
          ),
          openProfile: () => _openProfile(LanguageGoal.exam),
          glossLanguage: _feedbackLanguage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go("/study"),
        ),
        title: Text(l10n.languageLearning),
        actions: [
          IconButton(
            tooltip: l10n.languageGenerationHistory,
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LanguageGenerationHistoryScreen(
                  db: ref.read(appControllerProvider).db,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => editLanguageStudy(context, _preferences),
            icon: const Icon(Icons.tune),
            tooltip: l10n.languageStudySettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.languageEnglish, style: theme.headlineMedium),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openProfile,
                    icon: const Icon(Icons.tips_and_updates_outlined),
                    label: Text(l10n.languageRecommendedPractice),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<int>(
                    stream: _due,
                    builder: (context, snapshot) {
                      final count = snapshot.data;
                      final hasDue = count != null && count > 0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (count != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(l10n.languageDue(count)),
                            ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (snapshot.hasError)
                                TextButton.icon(
                                  onPressed: () => setState(
                                    () => _due = _store.dueCount(_language),
                                  ),
                                  icon: const Icon(Icons.refresh),
                                  label: Text(l10n.retry),
                                ),
                              if (hasDue)
                                OutlinedButton.icon(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 52),
                                  ),
                                  onPressed: _review,
                                  icon: const Icon(Icons.schedule),
                                  label: Text(l10n.languageReview),
                                ),
                              OutlinedButton(
                                style: const ButtonStyle(
                                  minimumSize: WidgetStatePropertyAll(
                                    Size(0, 52),
                                  ),
                                ),
                                onPressed: _practiceContexts,
                                child: Text(l10n.languageNewContexts),
                              ),
                              OutlinedButton(
                                onPressed: _practiceSentences,
                                child: Text(l10n.languageSentencePractice),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.push("/language/quick"),
                        icon: const Icon(Icons.manage_search),
                        label: Text(l10n.quickLookup),
                      ),
                      TextButton(
                        onPressed: _foundations,
                        child: Text(l10n.languageCourses),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.explore_outlined),
                          title: Text(l10n.languageExamRecommendations),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openProfile(LanguageGoal.exam),
                        ),
                        ListTile(
                          leading: const Icon(Icons.assignment_outlined),
                          title: Text(l10n.languageWrittenMock),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _writtenMock,
                        ),
                        ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          title: Text(l10n.languageExamSkills),
                          leading: const Icon(Icons.school_outlined),
                          children: [
                            for (final skill in ExamKind.values)
                              ListTile(
                                title: Text(examKindLabel(l10n, skill)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _practiceExam(skill),
                              ),
                            ListTile(
                              title: Text(l10n.languageWriting),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _practiceWriting,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.style_outlined),
                      title: Text(l10n.languageGroups),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const VocabularyGroupsScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.languageEvidence, style: theme.titleLarge),
                  LanguageDataBuilder<List<LearningEvidenceData>>(
                    load: _loadEvidence,
                    builder: (context, records) {
                      if (records.isEmpty) return Text(l10n.languageNoEvidence);
                      final recall = records
                          .where((row) => row.rating != null)
                          .length;
                      final contexts = records.where(
                        (row) => row.correct != null && !row.answerRevealed,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.languageRecallEvidence(recall)),
                          Text(
                            l10n.languageContextEvidence(
                              contexts
                                  .where((row) => row.correct == true)
                                  .length,
                              contexts.length,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openBatch(
  BuildContext context,
  LanguageLearningStore store,
  VocabularyMode mode, {
  LearningVocabularyGroup? group,
  DateTime? dueBefore,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => VocabularyBatch(
      store: store,
      language: _language,
      mode: mode,
      group: group,
      dueBefore: dueBefore,
    ),
  ),
);
