import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/controller.dart';
import '../../app/preferences.dart';
import '../../core/ai/ai_usage_store.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'language_store.dart';
import 'next_practice.dart';
import 'reading_practice.dart';
import 'sentence_batch_ai.dart';
import 'sentence_content.dart';
import 'sentence_explanation.dart';
import 'sentence_practice.dart';
import 'sentence_store.dart';
import 'study_settings_dialog.dart';
import 'vocabulary_ai.dart';
import 'vocabulary_batch.dart';
import 'vocabulary_editor.dart';
import 'vocabulary_proposal_dialog.dart';
import 'writing_ai.dart';
import 'writing_practice.dart';

const _language = 'en';

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

  late final _groups = _store.groups(_language);
  late final _evidence = _store.recentEvidence(_language);
  late final _sentenceEvidence = _store.sentenceEvidence(_language);
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

  void _practiceSentences([SentenceBatch? batch]) {
    final controller = ref.read(appControllerProvider);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SentencePractice(
          store: _store,
          initialBatch: batch,
          initialLevel: switch (_preferences.languageStudy.level) {
            EnglishStudyLevel.mixed => null,
            EnglishStudyLevel.beginner => SentenceLevel.beginner,
            EnglishStudyLevel.intermediate => SentenceLevel.intermediate,
          },
          feedbackLanguage: _feedbackLanguage,
          batchAi: SentenceBatchAi(
            provider: controller.provider,
            config: controller.config,
            usageStore: AiUsageStore(controller.db),
          ),
          explanation: SentenceExplanation(
            store: _store,
            provider: controller.provider,
            config: controller.config,
            usageStore: AiUsageStore(controller.db),
          ),
        ),
      ),
    );
  }

  void _practiceReading(EnglishReadingSkill skill) {
    final practice = ref.read(appControllerProvider).practice;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReadingPractice(store: practice, skill: skill),
      ),
    );
  }

  void _practiceWriting() {
    final controller = ref.read(appControllerProvider);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WritingPractice(
          store: _store,
          feedbackLanguage: _feedbackLanguage,
          ai: WritingAi(
            store: _store,
            provider: controller.provider,
            config: controller.config,
            usageStore: AiUsageStore(controller.db),
          ),
        ),
      ),
    );
  }

  Future<void> _generate(LearningVocabularyGroup? group) {
    final controller = ref.read(appControllerProvider);
    return showVocabularyProposal(
      context,
      store: _store,
      ai: VocabularyAi(
        controller.provider,
        usageStore: AiUsageStore(controller.db),
      ),
      config: controller.config,
      group: group,
      initialLevel:
          _preferences.languageStudy.level == EnglishStudyLevel.intermediate
          ? VocabularyLevel.intermediate
          : VocabularyLevel.beginner,
      feedbackLanguage: _feedbackLanguage,
    );
  }

  Widget _nextPractice(int due) {
    final l10n = context.l10n;
    if (due > 0) return Text(l10n.languageNextReview);
    return StreamBuilder<List<LearningSentenceAttempt>>(
      stream: _sentenceEvidence,
      builder: (context, snapshot) {
        final suggestion = suggestSentences(snapshot.data ?? const []);
        if (suggestion == null) return const SizedBox.shrink();
        return Card(
          child: ListTile(
            leading: const Icon(Icons.tips_and_updates_outlined),
            title: Text(
              l10n.languageNextSkill(
                sentenceSkillLabel(l10n, suggestion.skill),
              ),
            ),
            subtitle: Text(
              l10n.languageNextSkillReason(
                suggestion.correct,
                suggestion.checked,
              ),
            ),
            onTap: () => _practiceSentences(suggestion.batch),
          ),
        );
      },
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
              context.canPop() ? context.pop() : context.go('/study'),
        ),
        title: Text(l10n.languageLearning),
        actions: [
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
                  StreamBuilder<int>(
                    stream: _due,
                    builder: (context, snapshot) {
                      final count = snapshot.data;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (count != null) _nextPractice(count),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (count != null) Text(l10n.languageDue(count)),
                              if (snapshot.hasError)
                                Text(l10n.couldNotCompleteTheAction),
                              FilledButton.icon(
                                onPressed: count == null || count == 0
                                    ? null
                                    : _review,
                                icon: const Icon(Icons.schedule),
                                label: Text(l10n.languageReview),
                              ),
                              OutlinedButton(
                                onPressed: () => _openBatch(
                                  context,
                                  _store,
                                  VocabularyMode.context,
                                ),
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
                  Text(l10n.languageExamSkills, style: theme.titleLarge),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final skill in EnglishReadingSkill.values)
                        OutlinedButton(
                          onPressed: () => _practiceReading(skill),
                          child: Text(skill.label(l10n)),
                        ),
                      OutlinedButton(
                        onPressed: _practiceWriting,
                        child: Text(l10n.languageWriting),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.languageGroups, style: theme.titleLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            addVocabularyEntry(context, _store, _language),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.languageAddEntry),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _generate(null),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: Text(l10n.languageAiGenerate),
                      ),
                    ],
                  ),
                  StreamBuilder<List<LearningVocabularyGroup>>(
                    stream: _groups,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(l10n.couldNotCompleteTheAction);
                      }
                      final groups = snapshot.data;
                      if (groups == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (groups.isEmpty) return Text(l10n.languageNoGroups);
                      return Column(
                        children: [
                          for (final group in groups)
                            Card(
                              key: ValueKey(group.id),
                              child: _Group(
                                group: group,
                                store: _store,
                                onGenerate: () => _generate(group),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.languageEvidence, style: theme.titleLarge),
                  StreamBuilder<List<LearningEvidenceData>>(
                    stream: _evidence,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(l10n.couldNotCompleteTheAction);
                      }
                      final records = snapshot.data;
                      if (records == null) return const SizedBox.shrink();
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

class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.store,
    required this.onGenerate,
  });

  final LearningVocabularyGroup group;
  final LanguageLearningStore store;
  final VoidCallback onGenerate;

  Future<void> _delete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.languageDeleteGroup),
        content: Text(l10n.languageDeleteGroupConfirm(group.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (context.mounted && confirmed == true) {
      await act(context, () => store.deleteGroup(group.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpansionTile(
      title: Text(group.title),
      subtitle: Text(
        vocabularyGroupLabel(
          l10n,
          VocabularyGroupType.values.byName(group.groupType),
        ),
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () =>
                  addVocabularyEntry(context, store, _language, group: group),
              child: Text(l10n.languageAddEntry),
            ),
            OutlinedButton(
              onPressed: onGenerate,
              child: Text(l10n.languageAiExpand),
            ),
            OutlinedButton(
              onPressed: () => _openBatch(
                context,
                store,
                VocabularyMode.study,
                group: group,
              ),
              child: Text(l10n.languageStudyGroup),
            ),
            OutlinedButton(
              onPressed: () => _openBatch(
                context,
                store,
                VocabularyMode.recall,
                group: group,
              ),
              child: Text(l10n.languagePracticeGroup),
            ),
            OutlinedButton(
              onPressed: () => _openBatch(
                context,
                store,
                VocabularyMode.context,
                group: group,
              ),
              child: Text(l10n.languageNewContexts),
            ),
            TextButton(
              onPressed: () => _delete(context),
              child: Text(l10n.languageDeleteGroup),
            ),
          ],
        ),
      ],
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
