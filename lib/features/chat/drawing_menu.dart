import 'package:material_ui/material_ui.dart';

import '../../app/controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';

/// Temporary drawing choices embedded in the chat title's overflow menu.
List<PopupMenuEntry<String>> drawingMenuItems(
  BuildContext context,
  AppController controller,
) {
  final override = controller.sessionDrawingOverride;
  final enabled = controller.sessionDrawingEnabled;
  final canChange = !controller.busy && controller.selected != null;
  return [
    PopupMenuItem<String>(
      value: 'tool-call-limit',
      child: Text(
        '${context.l10n.maxToolCalls}: ${controller.maxToolCalls == 0 ? context.l10n.toolCallsUnlimited : controller.maxToolCalls}',
      ),
    ),
    const PopupMenuDivider(),
    PopupMenuItem<String>(
      enabled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${enabled ? context.l10n.chatDrawingEnabled : context.l10n.chatDrawingDisabled}'
            '${override == null ? context.l10n.followDefaultLabel : ''}',
          ),
          const SizedBox(height: 4),
          Text(context.l10n.chatDrawingHelp),
        ],
      ),
    ),
    CheckedPopupMenuItem(
      key: const Key('chat-drawing-default'),
      value: 'drawing-default',
      enabled: canChange,
      checked: override == null,
      child: Text(context.l10n.useGlobalDefault),
    ),
    CheckedPopupMenuItem(
      key: const Key('chat-drawing-on'),
      value: 'drawing-on',
      enabled: canChange,
      checked: override == true,
      child: Text(context.l10n.enableDrawingForThisChat),
    ),
    CheckedPopupMenuItem(
      key: const Key('chat-drawing-off'),
      value: 'drawing-off',
      enabled: canChange,
      checked: override == false,
      child: Text(context.l10n.disableDrawingForThisChat),
    ),
  ];
}

/// Returns false for other overflow actions; the controller locks active runs.
bool handleDrawingMenuSelection(
  BuildContext context,
  AppController controller,
  String value,
) {
  switch (value) {
    case 'drawing-default':
      act(context, () => controller.setSessionDrawingEnabled(null));
    case 'drawing-on':
      act(context, () => controller.setSessionDrawingEnabled(true));
    case 'drawing-off':
      act(context, () => controller.setSessionDrawingEnabled(false));
    default:
      return false;
  }
  return true;
}
