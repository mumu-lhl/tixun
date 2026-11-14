import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import 'visual_store.dart';

final visualStoreProvider = ChangeNotifierProvider<VisualStore>(
  (ref) => ref.read(appControllerProvider).visual,
);

final visualsByMessageProvider = FutureProvider.autoDispose
    .family<List<StoredVisualScene>, String>((ref, messageId) {
      return ref.watch(visualStoreProvider).listByMessage(messageId);
    });

final visualsByQuestionProvider = FutureProvider.autoDispose
    .family<List<StoredVisualScene>, String>((ref, questionId) {
      return ref.watch(visualStoreProvider).listByQuestion(questionId);
    });

final visualsByStudyProvider = FutureProvider.autoDispose
    .family<
      List<StoredVisualScene>,
      ({String? knowledgeId, String? mistakeId})
    >((ref, f) {
      return ref
          .watch(visualStoreProvider)
          .listByStudy(knowledgeId: f.knowledgeId, mistakeId: f.mistakeId);
    });
