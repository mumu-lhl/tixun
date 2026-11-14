import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/visual/model/visual_scene.dart';
import 'visual_card.dart';
import 'visual_providers.dart';

/// The visuals linked to one study owner (a knowledge item or a mistake),
/// rendered as [VisualCard]s.
///
/// Which section a visual belongs to follows its `source`: 'original'
/// renders under the original material, 'ai' under the AI analysis,
/// 'student' under the student's own analysis. [source] restricts the
/// section to one group; null renders every group, original first, then
/// AI, then student, then anything else. A group with no visuals renders
/// nothing. When [panelTitle] is given, the cards render inside a panel
/// with that title (same shape as the detail screen's `_panel`); without
/// it, the bare list renders, for placement inside an existing section.
/// Study visuals show the scene's current state (they are living
/// figures, not frozen quiz snapshots).
class StudyVisuals extends ConsumerWidget {
  const StudyVisuals({
    required this.knowledgeId,
    required this.mistakeId,
    this.source,
    this.panelTitle,
    super.key,
  });
  final String? knowledgeId;
  final String? mistakeId;
  final String? source;
  final String? panelTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(
        visualsByStudyProvider((
          knowledgeId: knowledgeId,
          mistakeId: mistakeId,
        )),
      )
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (scenes) {
          final groups = <String, List<VisualScene>>{};
          for (final stored in scenes) {
            if (source != null && stored.source != source) continue;
            VisualScene? scene;
            try {
              scene = VisualScene.fromJson(
                jsonDecode(stored.sceneJson) as Map<String, dynamic>,
              );
            } catch (_) {
              // An unparsable scene never breaks the detail screen.
              continue;
            }
            groups.putIfAbsent(stored.source, () => []).add(scene);
          }
          if (groups.isEmpty) return const SizedBox.shrink();
          const order = ['original', 'ai', 'student'];
          final keys = groups.keys.toList()
            ..sort((a, b) {
              final ai = order.indexOf(a), bi = order.indexOf(b);
              if (ai == -1 && bi == -1) return a.compareTo(b);
              if (ai == -1) return 1;
              if (bi == -1) return -1;
              return ai.compareTo(bi);
            });
          final list = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final key in keys)
                for (final scene in groups[key]!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: VisualCard(scene: scene),
                  ),
            ],
          );
          final title = panelTitle;
          if (title == null) return list;
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  list,
                ],
              ),
            ),
          );
        },
      );
}
