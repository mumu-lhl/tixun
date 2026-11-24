import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../app/controller.dart";
import "../../app/preferences.dart";
import "../../core/ai/ai_usage_store.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "../../core/ui/app_menu.dart";
import "generation_ui.dart";
import "language_data.dart";
import "language_store.dart";
import "language_layout.dart";
import "vocabulary_ai.dart";
import "vocabulary_batch.dart";
import "vocabulary_editor.dart";
import "vocabulary_proposal_dialog.dart";

class VocabularyGroupsScreen extends ConsumerStatefulWidget {
  const VocabularyGroupsScreen({super.key});
  @override
  ConsumerState<VocabularyGroupsScreen> createState() =>
      _VocabularyGroupsState();
}

class _VocabularyGroupsState extends ConsumerState<VocabularyGroupsScreen> {
  VocabularyMode _mode = VocabularyMode.study;
  late final _store = ref.read(appControllerProvider).language;
  Stream<List<LearningVocabularyGroup>> _groups() => _store.groups("en");

  Future<void> _generate([LearningVocabularyGroup? group]) {
    final c = ref.read(appControllerProvider);
    return showVocabularyProposal(
      context,
      store: _store,
      ai: VocabularyAi(
        languageGenerationProvider(context, c),
        usageStore: AiUsageStore(c.db),
        prompts: c.prompts,
      ),
      config: c.config,
      group: group,
      initialLevel:
          c.preferences.languageStudy.level == EnglishStudyLevel.intermediate
          ? VocabularyLevel.intermediate
          : VocabularyLevel.beginner,
      feedbackLanguage:
          c.preferences.languageStudy.feedbackLanguage ==
              LanguageFeedbackLanguage.app
          ? null
          : c.preferences.languageStudy.feedbackLanguage.name,
    );
  }

  Future<void> _delete(LearningVocabularyGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.languageDeleteGroup),
        content: Text(ctx.l10n.languageDeleteGroupConfirm(group.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.delete),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      await act(context, () => _store.deleteGroup(group.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.languageGroups),
        actions: [
          IconButton(
            key: const Key("create-vocabulary-group"),
            tooltip: l10n.languageCreateGroup,
            onPressed: _generate,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: SegmentedButton<VocabularyMode>(
                  segments: [
                    ButtonSegment(
                      value: VocabularyMode.study,
                      label: Text(l10n.languageLearnMode),
                      icon: const Icon(Icons.menu_book_outlined),
                    ),
                    ButtonSegment(
                      value: VocabularyMode.recall,
                      label: Text(l10n.languagePracticeMode),
                      icon: const Icon(Icons.school_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (values) =>
                      setState(() => _mode = values.single),
                ),
              ),
            ],
          ),
        ),
      ),
      body: LanguageDataBuilder<List<LearningVocabularyGroup>>(
        load: _groups,
        builder: (context, groups) => LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.clamp(0.0, 1200.0);
            final available = width - (constraints.maxWidth < 560 ? 36 : 48);
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            // Keep two columns on ordinary phones, but give large text room.
            final minWidth = (width < 560 ? 156 : 240) * scale.clamp(1.0, 2.5);
            final columns = ((available + 12) / (minWidth + 12)).floor().clamp(
              1,
              4,
            );
            return languagePage(
              maxWidth: 1200,
              children: [
                if (groups.isEmpty) Text(l10n.languageNoGroups),
                for (var i = 0; i < groups.length; i += columns)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var column = 0; column < columns; column++) ...[
                          if (column > 0) const SizedBox(width: 12),
                          Expanded(
                            child: i + column < groups.length
                                ? _groupCard(context, groups[i + column])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _groupCard(BuildContext context, LearningVocabularyGroup group) {
    final l10n = context.l10n;
    return Card(
      key: ValueKey("vocabulary-group-${group.id}"),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VocabularyBatch(
              store: _store,
              language: "en",
              mode: _mode,
              group: group,
              ai: VocabularyAi(
                languageGenerationProvider(
                  context,
                  ref.read(appControllerProvider),
                ),
                usageStore: AiUsageStore(ref.read(appControllerProvider).db),
                prompts: ref.read(appControllerProvider).prompts,
              ),
              config: ref.read(appControllerProvider).config,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vocabularyGroupLabel(
                        l10n,
                        VocabularyGroupType.values.byName(group.groupType),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  PopupMenuButton<String>(
                    key: ValueKey("vocabulary-menu-${group.id}"),
                    tooltip: l10n.languageGroupActions,
                    popUpAnimationStyle: menuAnimation(context),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: "add",
                        child: Text(l10n.languageAdd),
                      ),
                      PopupMenuItem(
                        value: "expand",
                        child: Text(l10n.languageAiExpand),
                      ),
                      PopupMenuItem(value: "delete", child: Text(l10n.delete)),
                    ],
                    onSelected: (value) async {
                      switch (value) {
                        case "add":
                          await addVocabularyEntry(
                            context,
                            _store,
                            "en",
                            group: group,
                          );
                        case "expand":
                          await _generate(group);
                        case "delete":
                          await _delete(group);
                      }
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  group.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
