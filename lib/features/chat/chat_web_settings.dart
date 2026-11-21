import "package:material_ui/material_ui.dart";

import "../../app/controller.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";

enum _WebChoice { inherit, on, off }

Future<void> showChatWebSettings(
  BuildContext context,
  AppController controller,
) async {
  final sessionId = controller.selected?.id;
  if (sessionId == null) return;
  final selected = switch (controller.sessionWebOverride) {
    true => _WebChoice.on,
    false => _WebChoice.off,
    null => _WebChoice.inherit,
  };
  final supported = controller.webAvailable;
  final choice = await showDialog<_WebChoice>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(ctx.l10n.aiWebAccess),
      children: [
        if (!supported)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(ctx.l10n.webUnavailableForModel),
          ),
        for (final (value, label) in [
          (_WebChoice.inherit, ctx.l10n.useGlobalDefault),
          (_WebChoice.on, ctx.l10n.webEnableForChat),
          (_WebChoice.off, ctx.l10n.webDisableForChat),
        ])
          SimpleDialogOption(
            key: ValueKey("chat-web-${value.name}"),
            onPressed: () => Navigator.pop(ctx, value),
            child: Semantics(
              selected: value == selected,
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: value == selected ? const Icon(Icons.check) : null,
                  ),
                  Expanded(child: Text(label)),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  if (!context.mounted ||
      choice == null ||
      controller.selected?.id != sessionId) {
    return;
  }
  await act(
    context,
    () => controller.setSessionWebEnabled(switch (choice) {
      _WebChoice.inherit => null,
      _WebChoice.on => true,
      _WebChoice.off => false,
    }),
  );
}
