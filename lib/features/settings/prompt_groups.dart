import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ai/prompt_settings.dart';
import '../../core/l10n/app_strings.dart';
import '../language_learning/language_store.dart';
import '../language_learning/quick_lookup/quick_action_editor.dart';
import 'prompt_localization.dart';

class PromptGroups extends StatelessWidget {
  const PromptGroups({
    super.key,
    required this.settings,
    required this.language,
    required this.query,
  });

  final PromptSettings settings;
  final LanguageLearningStore language;
  final String query;

  @override
  Widget build(BuildContext context) {
    final keyword = query.toLowerCase();
    bool matches(String value) => value.toLowerCase().contains(keyword);
    final groups = <Widget>[];
    for (final group in PromptGroup.values) {
      final title = promptGroupLabel(context, group);
      final rows = [
        for (final prompt in promptDefinitions)
          if (prompt.group == group &&
              (matches(title) ||
                  matches(promptTitle(context, prompt)) ||
                  matches(promptDescription(context, prompt)) ||
                  matches(settings.text(prompt.id))))
            _prompt(context, prompt),
        if (group == PromptGroup.language &&
            (matches(title) ||
                matches(context.l10n.quickActions) ||
                matches(context.l10n.quickLookup) ||
                matches(context.l10n.languagePromptQuickActionsDesc)))
          ListTile(
            key: const Key('prompt-quick-actions'),
            leading: const Icon(Icons.manage_search_outlined),
            title: Text(context.l10n.quickActions),
            subtitle: Text(context.l10n.languagePromptQuickActionsDesc),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => QuickActionManager(language),
              ),
            ),
          ),
      ];
      if (rows.isEmpty) continue;
      final icon = switch (group) {
        PromptGroup.teaching => Icons.forum_outlined,
        PromptGroup.knowledge => Icons.book_outlined,
        PromptGroup.practice => Icons.fact_check_outlined,
        PromptGroup.language => Icons.translate,
      };
      groups.add(
        Card(
          child: keyword.isEmpty
              ? ExpansionTile(
                  key: PageStorageKey('prompt-group-${group.name}'),
                  initiallyExpanded: group == PromptGroup.teaching,
                  leading: Icon(icon),
                  title: Text(title),
                  children: rows,
                )
              : Column(
                  children: [
                    ListTile(leading: Icon(icon), title: Text(title)),
                    ...rows,
                  ],
                ),
        ),
      );
    }

    return groups.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(24),
            child: Text(context.l10n.noMatchingPrompts),
          )
        : Column(spacing: 8, children: groups);
  }

  Widget _prompt(BuildContext context, PromptDefinition prompt) => ListTile(
    key: Key('prompt-${prompt.id}'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    title: Text(promptTitle(context, prompt)),
    subtitle: Text(
      '${settings.overrides.containsKey(prompt.id) ? context.l10n.customized : context.l10n.defaultLabel} · ${promptDescription(context, prompt)}',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push('/settings/prompts/${prompt.id}'),
  );
}
