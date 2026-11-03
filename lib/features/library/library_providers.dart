import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../app/controller.dart';
import 'study_store.dart';

final studyStoreProvider = ChangeNotifierProvider<StudyStore>((ref) {
  final c = ref.read(appControllerProvider);
  return c.study;
});
final knowledgeDetailProvider = FutureProvider.autoDispose
    .family<KnowledgeDetail, String>(
      (ref, id) => ref.watch(studyStoreProvider).knowledgeDetail(id),
    );
final mistakeDetailProvider = FutureProvider.autoDispose
    .family<MistakeDetail, String>(
      (ref, id) => ref.watch(studyStoreProvider).mistakeDetail(id),
    );

final studyCountsProvider = FutureProvider<({int knowledge, int mistakes})>((
  ref,
) async {
  final db = ref.watch(studyStoreProvider).db;
  final knowledge =
      (await db
              .customSelect(
                'SELECT count(*) AS n FROM knowledge_items WHERE deleted = 0',
              )
              .getSingle())
          .read<int>('n');
  final mistakes =
      (await db
              .customSelect(
                'SELECT count(*) AS n FROM mistakes WHERE deleted = 0',
              )
              .getSingle())
          .read<int>('n');
  return (knowledge: knowledge, mistakes: mistakes);
});
