import "package:material_ui/material_ui.dart";

import "../../app/controller.dart";
import "../../core/l10n/app_strings.dart";
import "drawing_menu.dart";

/// Keeps settings navigation inside the existing overflow route. Only selecting
/// a setting closes the route and delivers a value to PopupMenuButton.
class ChatActionsMenu extends PopupMenuEntry<String> {
  const ChatActionsMenu({
    required this.controller,
    required this.rootItems,
    super.key,
  });
  final AppController controller;
  final List<PopupMenuEntry<String>> Function(
    BuildContext context,
    List<PopupMenuEntry<String>> settings,
  )
  rootItems;

  @override
  double get height => 0;
  @override
  bool represents(String? value) => false;
  @override
  State<ChatActionsMenu> createState() => _ChatActionsMenuState();
}

class _ChatActionsMenuState extends State<ChatActionsMenu> {
  bool? a2ui;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final page = a2ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: page == null
          ? widget.rootItems(context, [
              for (final (isA2ui, label, icon) in [
                (false, context.l10n.aiDrawing, Icons.draw_outlined),
                (true, context.l10n.aiA2ui, Icons.widgets_outlined),
              ])
                _MenuNavigation(
                  key: Key(
                    isA2ui ? "chat-a2ui-settings" : "chat-drawing-settings",
                  ),
                  enabled: !c.busy && c.selected != null,
                  onOpen: () => setState(() => a2ui = isA2ui),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(icon),
                    title: Text(label),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
            ])
          : [
              _MenuNavigation(
                key: const Key("chat-menu-back"),
                onOpen: () => setState(() => a2ui = null),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.arrow_back),
                  title: Text(context.l10n.back),
                ),
              ),
              const PopupMenuDivider(),
              ...drawingMenuItems(context, c, a2ui: page),
            ],
    );
  }
}

class _MenuNavigation extends PopupMenuItem<String> {
  const _MenuNavigation({
    required this.onOpen,
    required super.child,
    super.enabled,
    super.key,
  });
  final VoidCallback onOpen;

  @override
  PopupMenuItemState<String, _MenuNavigation> createState() =>
      _MenuNavigationState();
}

class _MenuNavigationState extends PopupMenuItemState<String, _MenuNavigation> {
  @override
  void handleTap() => widget.onOpen();
}
