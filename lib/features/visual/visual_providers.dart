import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import 'visual_store.dart';
import '../library/library_providers.dart';

final visualStoreProvider = ChangeNotifierProvider<VisualStore>(
  (ref) => ref.read(appControllerProvider).visual,
);

final visualsByMessageProvider = FutureProvider.autoDispose
    .family<List<StoredVisualScene>, String>((ref, messageId) {
      return ref.watch(visualStoreProvider).listByMessage(messageId);
    });

final visualsBySessionProvider = FutureProvider.autoDispose
    .family<List<StoredVisualScene>, String>((ref, sessionId) {
      return ref.watch(visualStoreProvider).listBySession(sessionId);
    });

final visualsByStudyProvider = FutureProvider.autoDispose
    .family<
      List<StoredVisualScene>,
      ({String? knowledgeId, String? mistakeId})
    >((ref, f) {
      // Knowledge writes may add inline-owner links without revising a scene.
      ref.watch(studyStoreProvider);
      return ref
          .watch(visualStoreProvider)
          .listByStudy(knowledgeId: f.knowledgeId, mistakeId: f.mistakeId);
    });
