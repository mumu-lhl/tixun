import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/visual/model/visual_scene.dart';
import '../visual/visual_card.dart';
import '../visual/visual_providers.dart';

/// The visual scenes attached to one assistant message, rendered under
/// the message text (analogue of [MessageQuestions] for quiz cards).
/// Shows nothing while loading, on error, or when the message has no
/// scenes; a scene whose stored JSON no longer parses is skipped.
class MessageVisuals extends ConsumerWidget {
  const MessageVisuals(this.messageId, {super.key});
  final String messageId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(visualsByMessageProvider(messageId))
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (rows) {
          final scenes = <(String, VisualScene)>[];
          for (final row in rows) {
            try {
              scenes.add((
                row.id,
                VisualScene.fromJson(
                  (jsonDecode(row.sceneJson) as Map).cast<String, dynamic>(),
                ),
              ));
            } catch (_) {
              // A stored scene that no longer parses must not break the
              // message; it stays in the database for inspection.
              continue;
            }
          }
          if (scenes.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              for (final (id, scene) in scenes)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: VisualCard(scene: scene, key: ValueKey(id)),
                ),
            ],
          );
        },
      );
}
