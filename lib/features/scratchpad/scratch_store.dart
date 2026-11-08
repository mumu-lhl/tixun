import 'package:drift/drift.dart' show Variable;

import 'dart:async';

import '../../core/database/database.dart';
import '../../core/database/database_notifier.dart';
import 'scratch_document.dart';

/// Coalesced snapshots have a bounded save interval and a shutdown/backup barrier.
class ScratchStore extends DatabaseNotifier {
  ScratchStore(this.db);
  final AppDatabase db;
  final _pending = <String, String>{};
  Timer? _timer;
  Future<void>? _writes;
  String? failure;
  Future<ScratchDocument> load(String key) async {
    await flush();
    final row = await (db.select(
      db.scratchpads,
    )..where((s) => s.contextKey.equals(key))).getSingleOrNull();
    return row == null
        ? ScratchDocument()
        : ScratchDocument.decode(row.document);
  }

  void stage(String key, ScratchDocument document) {
    if (isDisposed) throw StateError('草稿已关闭。');
    if (!RegExp(r'^(chat|mistake|practice):[^\s]{1,200}$').hasMatch(key)) {
      throw const FormatException('草稿关联无效。');
    }
    final encoded = document.encode();
    // Apply the same bounds on writes and reads to avoid saving an unreadable draft.
    ScratchDocument.decode(encoded);
    _pending[key] = encoded;
    _timer ??= Timer(const Duration(milliseconds: 400), () {
      _timer = null;
      unawaited(flush().catchError((Object _) {}));
    });
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (isDisposed) return _writes ?? Future.value();
    final previous = _writes;
    final task = runOperation(() async {
      if (previous != null) await previous.catchError((Object _) {});
      final batch = Map<String, String>.of(_pending);
      _pending.clear();
      try {
        if (batch.isNotEmpty) {
          await db.transaction(() async {
            for (final e in batch.entries) {
              final split = e.key.indexOf(':');
              final table = {
                'chat': 'chat_sessions',
                'mistake': 'mistakes',
                'practice': 'practice_questions',
              }[e.key.substring(0, split)]!;
              // A queued autosave must never recreate data after its owner was permanently deleted.
              final owner = await db
                  .customSelect(
                    'SELECT 1 FROM $table WHERE id = ?',
                    variables: [Variable(e.key.substring(split + 1))],
                  )
                  .get();
              if (owner.isEmpty) continue;
              await db
                  .into(db.scratchpads)
                  .insertOnConflictUpdate(
                    ScratchpadsCompanion.insert(
                      contextKey: e.key,
                      document: e.value,
                      updatedAt: DateTime.now(),
                    ),
                  );
            }
          });
        }
        failure = null;
        changed();
      } catch (_) {
        for (final e in batch.entries) {
          _pending.putIfAbsent(e.key, () => e.value);
        }
        failure = '草稿保存失败，请重试后再退出。';
        changed();
        rethrow;
      }
    });
    _writes = task;
    return task;
  }

  @override
  void dispose() {
    if (isDisposed) return;
    _timer?.cancel();
    if (_pending.isNotEmpty) unawaited(flush().catchError((Object _) {}));
    super.dispose();
  }
}
