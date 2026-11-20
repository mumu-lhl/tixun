import "dart:async";
import "dart:convert";

import "package:a2ui_core/a2ui_core.dart";
import "package:a2ui_flutter/a2ui_flutter.dart";
// The official renderer uses legacy Material.
// ignore: deprecated_member_use
import "package:flutter/material.dart" as legacy;
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

import "../../app/controller.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/visual/model/visual_scene.dart";
import "a2ui_diagrams.dart";
import "a2ui_catalog.dart";
import "a2ui_store.dart";

/// A separate official renderer per mounted snapshot. Only the data model and
/// accepted user actions can write back to TiXun.
class ChatA2uiSurfaceCard extends ConsumerStatefulWidget {
  const ChatA2uiSurfaceCard({
    required this.row,
    required this.visualBuilder,
    super.key,
  });

  final ChatA2uiSurface row;
  final Widget? Function(String id) visualBuilder;

  @override
  ConsumerState<ChatA2uiSurfaceCard> createState() =>
      _ChatA2uiSurfaceCardState();
}

class _ChatA2uiSurfaceCardState extends ConsumerState<ChatA2uiSurfaceCard> {
  late final ChatA2uiStore _store;
  MessageProcessor<ComponentImplementation>? _processor;
  SurfaceModel<ComponentImplementation>? _surface;
  bool _actionPending = false;
  bool _promoting = false;
  Map<String, VisualScene> _diagrams = const {};
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(appControllerProvider).a2ui;
    final row = widget.row;
    if (row.protocol != chatA2uiProtocol || row.catalog != chatA2uiCatalogId) {
      return;
    }
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [chatA2uiCatalog],
    );
    try {
      final snapshot = readChatA2ui(row.messagesJson, row.id);
      _diagrams = readDiagramSnapshots(snapshot);
      processor.processMessages([snapshot.toJson()]);
      final surface = processor.model.getSurface(row.id)!;
      if (row.stateJson case final String state) {
        if (utf8.encode(state).length <= chatA2uiMaxState) {
          final decoded = jsonDecode(state);
          if (decoded is Map<String, dynamic>) {
            surface.dataModel.set("/", decoded);
          }
        }
      }
      surface.dataModel.subscribe<Object?>("/", (value) {
        // Encode now: the SDK owns and mutates the backing data.
        unawaited(_saveState(row, jsonEncode(value)));
      });
      surface.onAction.subscribe((action) => unawaited(_act(action)));
      _surface = surface;
      _processor = processor;
    } catch (_) {
      processor.dispose();
    }
  }

  Future<void> _saveState(ChatA2uiSurface row, String state) async {
    try {
      await _store.saveState(row, state);
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } on Exception {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  Future<void> _act(A2uiRendererAction action) async {
    if (!mounted ||
        _actionPending ||
        action.surfaceId != widget.row.id ||
        !chatA2uiActions.contains(action.name)) {
      return;
    }
    final text = action.context["text"];
    if (action.name == "open_practice"
        ? action.context.isNotEmpty
        : action.context.length != 1 ||
              text is! String ||
              text.trim().isEmpty ||
              text.length > 2400) {
      return;
    }
    final controller = ref.read(appControllerProvider);
    final row = widget.row;
    if (controller.selected?.id != row.sessionId || controller.busy) return;
    _actionPending = true;
    try {
      if (action.name == "copy_text") {
        await Clipboard.setData(ClipboardData(text: text as String));
        await _record(row, action);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.chatA2uiCopied)));
        }
      } else if (action.name == "ask_chat") {
        final approved = await showDialog<String>(
          context: context,
          builder: (_) => _A2uiChatConfirmation(text: text as String),
        );
        if (approved == null ||
            approved.isEmpty ||
            !mounted ||
            controller.selected?.id != row.sessionId ||
            controller.busy) {
          return;
        }
        await _record(row, action);
        if (!mounted ||
            controller.selected?.id != row.sessionId ||
            controller.busy) {
          return;
        }
        await controller.send("[TiXun A2UI ${row.id}]\n$approved");
      } else if (action.name == "open_practice") {
        final practice = await controller.practice.list(
          messageId: row.messageId,
        );
        if (!mounted ||
            controller.selected?.id != row.sessionId ||
            controller.busy) {
          return;
        }
        if (practice.length != 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.chatA2uiPracticeUnavailable)),
          );
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.chatA2uiOpenPractice),
            content: Text(
              practice.single.stem,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.chatA2uiOpenPractice),
              ),
            ],
          ),
        );
        if (confirmed != true ||
            !mounted ||
            controller.selected?.id != row.sessionId ||
            controller.busy) {
          return;
        }
        await _record(row, action);
        if (mounted &&
            controller.selected?.id == row.sessionId &&
            !controller.busy) {
          await context.push(
            "/practice/${Uri.encodeComponent(practice.single.id)}",
          );
        }
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatA2uiActionFailed)),
        );
      }
    } finally {
      _actionPending = false;
    }
  }

  Future<void> _promote(String componentId, VisualScene scene) async {
    if (!mounted || _promoting) return;
    _promoting = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.a2uiSaveDiagram),
          content: Text(context.l10n.a2uiSaveDiagramHelp),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.save),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      final c = ref.read(appControllerProvider);
      if (c.selected?.id != widget.row.sessionId) return;
      await c.visual.create(
        sceneJson: jsonEncode(scene.toJson()),
        title: scene.title,
        messageId: widget.row.messageId,
        source: "a2ui_promotion",
        promotionKey: "${widget.row.id}/$componentId",
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.a2uiDiagramSaved)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatA2uiActionFailed)),
        );
      }
    } finally {
      _promoting = false;
    }
  }

  Future<void> _record(ChatA2uiSurface row, A2uiRendererAction action) =>
      _store.recordAction(
        row,
        kind: action.name,
        componentId: action.sourceComponentId,
      );

  @override
  void dispose() {
    _processor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = _surface;
    if (surface == null) return Text(context.l10n.chatA2uiUnavailable);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.chatA2uiLabel, style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          // Use the app's compatibility theme. Legacy SDK inputs also need
          // their own Material ancestor for ink, selection and focus.
          legacy.Material(
            type: legacy.MaterialType.transparency,
            child: A2uiVisualScope(
              builder: widget.visualBuilder,
              child: A2uiDiagramScope(
                scenes: _diagrams,
                promote: _promote,
                child: A2uiSurface(surface: surface),
              ),
            ),
          ),
          if (_saveFailed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.chatA2uiStateFailed,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _A2uiChatConfirmation extends StatefulWidget {
  const _A2uiChatConfirmation({required this.text});
  final String text;

  @override
  State<_A2uiChatConfirmation> createState() => _A2uiChatConfirmationState();
}

class _A2uiChatConfirmationState extends State<_A2uiChatConfirmation> {
  late final _input = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.chatA2uiContinue),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.chatA2uiConfirm),
        const SizedBox(height: 12),
        TextField(
          controller: _input,
          maxLength: 2400,
          minLines: 2,
          maxLines: 5,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _input.text.trim()),
        child: Text(context.l10n.chatA2uiSend),
      ),
    ],
  );
}
