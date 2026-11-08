import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../app/controller.dart';
import '../practice/practice_providers.dart';
import '../library/library_providers.dart';
import '../progress/learning_profile.dart';
import '../progress/learning_progress.dart';
import 'review_store.dart';

final reviewStoreProvider = ChangeNotifierProvider<ReviewStore>(
  (ref) => ref.read(appControllerProvider).review,
);
// Time-based queries refresh while the app is open, without a background service.
final reviewClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});
final dueCountProvider = FutureProvider<int>((ref) {
  ref.watch(reviewClockProvider);
  ref.watch(practiceStoreProvider);
  return ref.watch(reviewStoreProvider).dueCount();
});
final reviewListProvider = FutureProvider.autoDispose
    .family<List<ReviewItem>, ({String filter, String subject})>((ref, f) {
      ref.watch(reviewClockProvider);
      ref.watch(practiceStoreProvider);
      return ref
          .watch(reviewStoreProvider)
          .list(
            dueOnly: f.filter == 'due',
            paused: f.filter == 'paused',
            subject: f.subject,
          );
    });
final progressProvider = FutureProvider<LearningProgress>((ref) {
  ref.watch(practiceStoreProvider);
  ref.watch(studyStoreProvider);
  return LearningProgress.load(ref.read(appControllerProvider).db);
});
final learningProfileProvider = FutureProvider<LearningProfile>(
  (ref) => LearningProfile.load(ref.read(appControllerProvider).db),
);
