import "dart:async";

import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

import "../../../core/l10n/app_strings.dart";
import "quick_models.dart";

Widget quickSelectableText(
  String text, {
  TextStyle? style,
  VoidCallback? onLookup,
}) => SelectableText(
  text,
  style: style,
  contextMenuBuilder: (context, editable) =>
      quickSelectionToolbar(context, editable, onLookup: onLookup),
);

Widget quickSelectionToolbar(
  BuildContext context,
  EditableTextState editable, {
  VoidCallback? onLookup,
}) {
  final value = editable.textEditingValue;
  final selected = value.selection.isValid && !value.selection.isCollapsed
      ? value.selection.textInside(value.text).trim()
      : "";
  final router = GoRouter.maybeOf(context);
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editable.contextMenuAnchors,
    buttonItems: [
      ...editable.contextMenuButtonItems,
      if (router != null &&
          selected.isNotEmpty &&
          selected.length <= quickInputLimit)
        ContextMenuButtonItem(
          label: context.l10n.quickLookup,
          onPressed: () {
            ContextMenuController.removeAny();
            onLookup?.call();
            unawaited(router.push("/language/quick", extra: selected));
          },
        ),
    ],
  );
}
