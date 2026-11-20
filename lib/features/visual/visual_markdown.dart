import "dart:convert";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

import "../../app/controller.dart";
import "../../core/database/database.dart";
import "../a2ui/a2ui_markdown.dart";
import "../a2ui/a2ui_surface_card.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/markdown/visual_references.dart";
import "../../core/ui/learning_markdown.dart";
import "../../core/visual/model/visual_scene.dart";
import "visual_card.dart";
import "visual_providers.dart";

final _a2uiByMessage = StreamProvider.autoDispose
    .family<List<ChatA2uiSurface>, (String, String)>((ref, owner) {
      return ref
          .read(appControllerProvider)
          .a2ui
          .watchMessage(owner.$1, owner.$2);
    });

/// Resolves Markdown references against a single owner, not arbitrary IDs.
/// Private exam scenes have no public message links and cannot enter this set.
class VisualMarkdown extends ConsumerWidget {
  const VisualMarkdown(
    this.data, {
    this.sessionId,
    this.messageId,
    this.knowledgeId,
    this.streaming = false,
    super.key,
  }) : assert((sessionId == null) != (knowledgeId == null));

  final String data;
  final String? sessionId, messageId, knowledgeId;
  final bool streaming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = sessionId == null || messageId == null
        ? const <ChatA2uiSurface>[]
        : ref.watch(_a2uiByMessage((sessionId!, messageId!))).value ??
              const <ChatA2uiSurface>[];
    final surfaceIndex = {for (final row in surfaces) row.id: row};
    final usesSavedVisual = surfaces.any(
      (row) => row.messagesJson.contains('"component":"VisualSceneRef"'),
    );
    final status = surfaces.isEmpty || streaming
        ? null
        : ref.watch(
            appControllerProvider.select(
              (controller) => controller.messages
                  .where((message) => message.id == messageId)
                  .firstOrNull
                  ?.status,
            ),
          );
    // Private render destinations are minted only for parsed Markdown images.
    var renderScheme = "tixun-a2ui-inline";
    while (data.contains("$renderScheme:")) {
      renderScheme += "x";
    }
    final parts = chatA2uiMarkdown(
      data,
      surfaces,
      renderScheme: renderScheme,
      interrupted: const {"error", "stopped", "interrupted"}.contains(status),
    );
    final references = visualReferences(data);
    final owner = knowledgeId;
    final rows = owner != null
        ? ref
                  .watch(
                    visualsByStudyProvider((
                      knowledgeId: owner,
                      mistakeId: null,
                    )),
                  )
                  .value ??
              <StoredVisualScene>[]
        : references.isEmpty && !usesSavedVisual
        ? <StoredVisualScene>[]
        : ref.watch(visualsBySessionProvider(sessionId!)).value ??
              <StoredVisualScene>[];
    final attached = messageId == null
        ? <StoredVisualScene>[]
        : ref.watch(visualsByMessageProvider(messageId!)).value ??
              <StoredVisualScene>[];
    final scenes = <String, VisualScene>{};
    for (final row in [...rows, ...attached]) {
      try {
        scenes[row.id] = VisualScene.fromJson(
          (jsonDecode(row.sceneJson) as Map).cast<String, dynamic>(),
        );
      } catch (_) {
        // Invalid stored scenes never break the rest of an explanation.
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget? visualWidget(String id) {
          final scene = scenes[id];
          return scene == null
              ? null
              : VisualCard(scene: scene, key: ValueKey("inline-$id"));
        }

        Widget surfaceWidget(String id) {
          final surface = surfaceIndex[id];
          if (surface == null) return Text(context.l10n.chatA2uiUnavailable);
          return ChatA2uiSurfaceCard(
            key: ValueKey("a2ui-${surface.sessionId}-$id"),
            row: surface,
            visualBuilder: visualWidget,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, part) in parts.indexed)
              if (part.surfaceId case final String id)
                surfaceWidget(id)
              else
                LearningMarkdown(
                  part.markdown!,
                  key: ValueKey("markdown-$index"),
                  streaming: streaming && index == parts.length - 1,
                  visualBuilder: (uri) {
                    final surfaceId = chatA2uiReference(
                      uri,
                      scheme: renderScheme,
                    );
                    if (surfaceId != null && messageId != null) {
                      return SizedBox(
                        width: constraints.maxWidth,
                        child: surfaceWidget(surfaceId),
                      );
                    }
                    final id = visualReferenceId(uri.toString());
                    if (id == null) return null;
                    return SizedBox(
                      width: constraints.maxWidth,
                      child:
                          visualWidget(id) ??
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(context.l10n.inlineVisualUnavailable),
                          ),
                    );
                  },
                ),
            // Preserve legacy/unreferenced cards. Referenced figures appear only
            // in the body; earlier figures are not repeated below every message.
            if (owner == null)
              for (final row in attached)
                if (row.source != "a2ui_promotion" &&
                    !references.contains(row.id) &&
                    scenes[row.id] != null)
                  Padding(
                    key: ValueKey("fallback-${row.id}"),
                    padding: const EdgeInsets.only(top: 16),
                    child: VisualCard(scene: scenes[row.id]!),
                  ),
          ],
        );
      },
    );
  }
}
