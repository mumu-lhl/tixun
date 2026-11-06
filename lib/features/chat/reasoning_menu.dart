import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/ui/actions.dart';

const reasoningLabels = {
  '': '跟随全局默认',
  'off': '关闭思考',
  'low': '低',
  'high': '高',
  'max': '最高',
};

class ReasoningMenu extends ConsumerWidget {
  const ReasoningMenu({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final effective = c.sessionConfig;
    final label = effective.thinking
        ? reasoningLabels[effective.effort] ?? effective.effort
        : '关闭';
    return PopupMenuButton<String>(
      key: const Key('reasoning-menu'),
      tooltip: '本会话思考强度：$label${c.sessionReasoning.isEmpty ? '（跟随默认）' : ''}',
      icon: Icon(
        Icons.psychology_outlined,
        color: effective.thinking
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
            c.config.supportsThinking ? '仅影响本会话；强度越高通常越慢' : '当前模型未声明支持思考参数',
          ),
        ),
        for (final entry in reasoningLabels.entries)
          CheckedPopupMenuItem(
            key: Key('reasoning-${entry.key.isEmpty ? 'default' : entry.key}'),
            value: entry.key,
            checked: c.sessionReasoning == entry.key,
            enabled:
                !c.busy &&
                c.selected != null &&
                (entry.key.isEmpty ||
                    entry.key == 'off' ||
                    c.config.supportsThinking),
            child: Text(entry.value),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'prompts', child: Text('管理提示词')),
      ],
    );
  }
}
