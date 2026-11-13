import '../../core/ui/app_menu.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/ai/ai_options.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/reasoning_labels.dart';

class ReasoningMenu extends ConsumerWidget {
  const ReasoningMenu({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final effective = c.sessionConfig;
    final options = AiOptions(c.config);
    final override = options.supportsOverride(c.sessionReasoning)
        ? c.sessionReasoning
        : '';
    final labels = {
      '': context.l10n.useGlobalDefault,
      'off': reasoningOffLabel(context, options, choice: true),
      for (final level in options.reasoningEfforts)
        level: reasoningEffortLabel(context, options, level),
    };
    final label = effective.thinking
        ? reasoningEffortLabel(context, options, effective.effort)
        : reasoningOffLabel(context, options);
    return PopupMenuButton<String>(
      popUpAnimationStyle: menuAnimation(context),
      key: const Key('reasoning-menu'),
      tooltip: context.l10n.reasoningForThisConversation(
        l10nArgument((label)),
        l10nArgument((override.isEmpty ? context.l10n.followDefaultLabel : '')),
      ),
      icon: Icon(
        Icons.psychology_outlined,
        // Highlight only when reasoning actually runs: thinking=true with
        // effort='none' shows the '不推理' label and must not look active.
        color: AiOptions(effective).reasoningEnabled
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
      onSelected: (value) {
        if (value == 'prompts') {
          context.go('/settings/prompts');
          return;
        }
        act(context, () => c.setSessionReasoning(value));
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            c.config.supportsThinking
                ? context.l10n.thisConversationOnlyHigherEffort
                : context.l10n.thisModelHasNotDeclared,
          ),
        ),
        for (final entry in labels.entries)
          CheckedPopupMenuItem(
            key: Key('reasoning-${entry.key.isEmpty ? 'default' : entry.key}'),
            value: entry.key,
            checked: override == entry.key,
            enabled:
                !c.busy &&
                c.selected != null &&
                (entry.key.isEmpty ||
                    entry.key == 'off' ||
                    c.config.supportsThinking),
            child: Text(entry.value),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'prompts',
          child: Text(context.l10n.managePrompts),
        ),
      ],
    );
  }
}
