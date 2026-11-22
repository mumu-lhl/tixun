import "dart:async";

import "package:material_ui/material_ui.dart";

import "../../app/controller.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";

List<PopupMenuEntry<String>> drawingMenuItems(
  BuildContext context,
  AppController controller,
) {
  final override = controller.sessionDrawingOverride;
  final enabled = controller.sessionDrawingEnabled;
  final canChange = !controller.busy && controller.selected != null;
  return [
    PopupMenuItem<String>(
      value: "tool-call-limit",
      child: Text(
        "${context.l10n.maxToolCalls}: ${controller.maxToolCalls == 0 ? context.l10n.toolCallsUnlimited : controller.maxToolCalls}",
      ),
    ),
    const PopupMenuDivider(),
    PopupMenuItem<String>(
      enabled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${enabled ? context.l10n.chatDrawingEnabled : context.l10n.chatDrawingDisabled}"
            '${override == null ? context.l10n.followDefaultLabel : ''}',
          ),
          const SizedBox(height: 4),
          Text(context.l10n.chatDrawingHelp),
        ],
      ),
    ),
    CheckedPopupMenuItem(
      key: const Key("chat-drawing-default"),
      value: "drawing-default",
      enabled: canChange,
      checked: override == null,
      child: Text(context.l10n.useInheritedDefault),
    ),
    CheckedPopupMenuItem(
      key: const Key("chat-drawing-on"),
      value: "drawing-on",
      enabled: canChange,
      checked: override == true,
      child: Text(context.l10n.enableDrawingForThisChat),
    ),
    CheckedPopupMenuItem(
      key: const Key("chat-drawing-off"),
      value: "drawing-off",
      enabled: canChange,
      checked: override == false,
      child: Text(context.l10n.disableDrawingForThisChat),
    ),
    const PopupMenuDivider(),
    for (final (suffix, setting, label) in [
      ("default", null, context.l10n.a2uiUseDefault),
      ("on", true, context.l10n.enableA2uiForChat),
      ("off", false, context.l10n.disableA2uiForChat),
    ])
      CheckedPopupMenuItem(
        key: Key("chat-a2ui-$suffix"),
        value: "a2ui-$suffix",
        enabled: canChange,
        checked: controller.sessionA2uiOverride == setting,
        child: Text(label),
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
    case "drawing-default":
      unawaited(act(context, () => controller.setSessionDrawingEnabled(null)));
    case "drawing-on":
      unawaited(act(context, () => controller.setSessionDrawingEnabled(true)));
    case "drawing-off":
      unawaited(act(context, () => controller.setSessionDrawingEnabled(false)));
    case "a2ui-default":
      unawaited(act(context, () => controller.setSessionA2uiEnabled(null)));
    case "a2ui-on":
      unawaited(act(context, () => controller.setSessionA2uiEnabled(true)));
    case "a2ui-off":
      unawaited(act(context, () => controller.setSessionA2uiEnabled(false)));
    default:
      return false;
  }
  return true;
}
