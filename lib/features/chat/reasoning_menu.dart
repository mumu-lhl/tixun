import '../../core/ui/app_menu.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/ai/ai_options.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';

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
      '': '跟随全局默认',
      'off': options.offChoiceLabel,
      for (final level in options.reasoningEfforts) level: options.label(level),
    };
    final label = effective.thinking
        ? context.tr(options.label(effective.effort))
        : context.tr(AiOptions(c.config).offLabel);
    return PopupMenuButton<String>(
      popUpAnimationStyle: menuAnimation(context),
      key: const Key('reasoning-menu'),
      tooltip: context.tr("本会话思考强度：{0}{1}", [
        label,
        override.isEmpty ? context.tr("（跟随默认）") : '',
      ]),
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
                ? context.tr("仅影响本会话；强度越高通常越慢")
                : context.tr("当前模型未声明支持思考参数"),
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
            child: Text(
              context.tr(
                entry.key == 'off'
                    ? AiOptions(c.config).offChoiceLabel
                    : entry.value,
              ),
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'prompts', child: Text(context.tr("管理提示词"))),
      ],
    );
  }
}
