import "package:drift/drift.dart" show Variable;

import "dart:async";

import "../../core/database/database.dart";
import "../../core/database/database_notifier.dart";
import "scratch_document.dart";
import "scratchpad_exception.dart";

/// Coalesced snapshots have a bounded save interval and a shutdown/backup barrier.
class ScratchStore extends DatabaseNotifier {
  ScratchStore(this.db, {this.createChatOwner, this.onChatOwnerSaved});
  final AppDatabase db;
  final Future<bool> Function(String id)? createChatOwner;
  final Future<void> Function(String id)? onChatOwnerSaved;
  final _pending = <String, String>{};
  Timer? _timer;
  Future<void>? _writes;
  ScratchpadError? failure;
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
    if (isDisposed) throw StateError("草稿已关闭。");
    if (!RegExp(r"^(chat|mistake|practice):[^\s]{1,200}$").hasMatch(key)) {
      throw const ScratchpadException(
        ScratchpadError.invalidContext,
        "草稿关联无效。",
      );
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
      final createdChats = <String>[];
      try {
        if (batch.isNotEmpty) {
          await db.transaction(() async {
            for (final e in batch.entries) {
              final split = e.key.indexOf(":");
              final type = e.key.substring(0, split);
              final id = e.key.substring(split + 1);
              final table = {
                "chat": "chat_sessions",
                "mistake": "mistakes",
                "practice": "practice_questions",
              }[type]!;
              // Only the current transient chat may supply a missing owner;
              // a queued autosave must not resurrect a deleted record.
              final owner = await db
                  .customSelect(
                    "SELECT 1 FROM $table WHERE id = ?",
                    variables: [Variable(id)],
                  )
                  .get();
              if (owner.isEmpty) {
                if (type != "chat" ||
                    e.value == ScratchDocument().encode() ||
                    await createChatOwner?.call(id) != true) {
                  continue;
                }
                createdChats.add(id);
              }
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
        failure = ScratchpadError.saveFailed;
        changed();
        rethrow;
      }
      for (final id in createdChats) {
        await onChatOwnerSaved?.call(id);
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
