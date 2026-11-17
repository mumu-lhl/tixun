import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/markdown/visual_references.dart';
import '../../core/ui/learning_markdown.dart';
import '../../core/visual/model/visual_scene.dart';
import 'visual_card.dart';
import 'visual_providers.dart';

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
        : references.isEmpty
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.isNotEmpty)
              LearningMarkdown(
                data,
                streaming: streaming,
                visualBuilder: (uri) {
                  final id = visualReferenceId(uri.toString());
                  if (id == null) return null;
                  final scene = scenes[id];
                  return SizedBox(
                    width: constraints.maxWidth,
                    child: scene == null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(context.l10n.inlineVisualUnavailable),
                          )
                        : VisualCard(scene: scene, key: ValueKey('inline-$id')),
                  );
                },
              ),
            // Preserve legacy/unreferenced cards. Referenced figures appear only
            // in the body; earlier figures are not repeated below every message.
            if (owner == null)
              for (final row in attached)
                if (!references.contains(row.id) && scenes[row.id] != null)
                  Padding(
                    key: ValueKey('fallback-${row.id}'),
                    padding: const EdgeInsets.only(top: 16),
                    child: VisualCard(scene: scenes[row.id]!),
                  ),
          ],
        );
      },
    );
  }
}
