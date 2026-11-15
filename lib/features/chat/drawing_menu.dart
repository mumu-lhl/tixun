import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/app_menu.dart';

/// Per-chat, in-memory drawing policy. No preference or history writes.
class DrawingMenu extends ConsumerWidget {
  const DrawingMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final enabled = c.sessionDrawingEnabled;
    final override = c.sessionDrawingOverride;
    return PopupMenuButton<String>(
      key: const Key('chat-drawing-menu'),
      popUpAnimationStyle: menuAnimation(context),
      enabled: !c.busy && c.selected != null,
      tooltip:
          '${enabled ? context.l10n.chatDrawingEnabled : context.l10n.chatDrawingDisabled}'
          '${override == null ? context.l10n.followDefaultLabel : ''}',
      icon: Icon(
        enabled ? Icons.draw : Icons.draw_outlined,
        color: enabled ? Theme.of(context).colorScheme.primary : null,
      ),
      onSelected: (value) =>
          c.setSessionDrawingEnabled(value == 'default' ? null : value == 'on'),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(context.l10n.chatDrawingHelp),
        ),
        CheckedPopupMenuItem(
          key: const Key('chat-drawing-default'),
          value: 'default',
          checked: override == null,
          child: Text(context.l10n.useGlobalDefault),
        ),
        CheckedPopupMenuItem(
          key: const Key('chat-drawing-on'),
          value: 'on',
          checked: override == true,
          child: Text(context.l10n.enableDrawingForThisChat),
        ),
        CheckedPopupMenuItem(
          key: const Key('chat-drawing-off'),
          value: 'off',
          checked: override == false,
          child: Text(context.l10n.disableDrawingForThisChat),
        ),
      ],
    );
  }
}
