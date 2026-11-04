import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import 'practice_store.dart';

final practiceStoreProvider = ChangeNotifierProvider<PracticeStore>(
  (ref) => ref.read(appControllerProvider).practice,
);
final messageQuestionsProvider = FutureProvider.autoDispose
    .family<List<PracticeQuestion>, String>(
      (ref, id) => ref.watch(practiceStoreProvider).list(messageId: id),
    );
