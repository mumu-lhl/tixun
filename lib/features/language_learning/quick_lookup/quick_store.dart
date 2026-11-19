import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/ai/chat_provider.dart' show CancelGuard;
import '../../../core/database/database.dart';
import '../language_store.dart';
import 'quick_models.dart';

typedef QuickCursor = ({int time, int rowId});
typedef QuickHistoryRow = ({
  String id,
  String actionId,
  String actionName,
  String input,
  String summary,
  QuickCursor cursor,
});

const quickPageSize = 30;

extension QuickLookupStore on LanguageLearningStore {
  Future<void> ensureQuickActions() => runOperation(() async {
    final now = DateTime.now();
    final missing = quickBuiltIns.keys.toSet();
    final rows = await db.select(db.languageQuickActions).get();
    missing.removeAll(rows.map((row) => row.id));
    if (missing.isEmpty) return;
    await db.batch((batch) {
      batch.insertAll(db.languageQuickActions, [
        for (final id in missing)
          quickActionDefaults(id, quickBuiltIns.keys.toList().indexOf(id), now),
      ], mode: InsertMode.insertOrIgnore);
    });
  });

  Future<List<LanguageQuickAction>> quickActions() =>
      (db.select(db.languageQuickActions)
            ..where((row) => row.deleted.equals(false))
            ..orderBy([
              (row) => OrderingTerm.asc(row.position),
              (row) => OrderingTerm.asc(row.id),
            ]))
          .get();

  Future<LanguageQuickAction> saveQuickAction(LanguageQuickAction value) =>
      runOperation(() async {
        validateQuickAction(value);
        return db.transaction(() async {
          final old = await (db.select(
            db.languageQuickActions,
          )..where((row) => row.id.equals(value.id))).getSingleOrNull();
          if (old?.deleted == true) {
            throw StateError('The lookup action has been deleted');
          }
          final now = DateTime.now();
          final last =
              await (db.select(db.languageQuickActions)
                    ..orderBy([(row) => OrderingTerm.desc(row.position)])
                    ..limit(1))
                  .getSingleOrNull();
          final saved = value.copyWith(
            name: value.name.trim(),
            description: value.description.trim(),
            inputHint: value.inputHint.trim(),
            prompt: value.prompt.trim(),
            deleted: false,
            position: old?.position ?? (last?.position ?? -1) + 1,
            revision: (old?.revision ?? 0) + 1,
            createdAt: old?.createdAt ?? now,
            updatedAt: now,
          );
          await db.into(db.languageQuickActions).insertOnConflictUpdate(saved);
          return saved;
        });
      });

  Future<void> setQuickActionEnabled(String id, bool enabled) =>
      runOperation(() async {
        await (db.update(
          db.languageQuickActions,
        )..where((row) => row.id.equals(id) & row.deleted.equals(false))).write(
          LanguageQuickActionsCompanion(
            enabled: Value(enabled),
            updatedAt: Value(DateTime.now()),
          ),
        );
      });

  Future<void> deleteQuickAction(String id) => runOperation(() async {
    await (db.update(
      db.languageQuickActions,
    )..where((row) => row.id.equals(id) & row.builtIn.equals(false))).write(
      LanguageQuickActionsCompanion(
        deleted: const Value(true),
        enabled: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  });

  Future<void> moveQuickAction(String id, int offset) => runOperation(() async {
    await db.transaction(() async {
      final actions = await quickActions();
      final index = actions.indexWhere((row) => row.id == id);
      final destination = index + offset;
      if (index < 0 || destination < 0 || destination >= actions.length) return;
      actions.insert(destination, actions.removeAt(index));
      final now = DateTime.now();
      await db.batch((batch) {
        for (var i = 0; i < actions.length; i++) {
          if (actions[i].position == i) continue;
          final id = actions[i].id;
          batch.update(
            db.languageQuickActions,
            LanguageQuickActionsCompanion(
              position: Value(i),
              updatedAt: Value(now),
            ),
            where: (row) => row.id.equals(id),
          );
        }
      });
    });
  });

  Future<Map<String, String>> deletedQuickActionLabels() async {
    final rows = await db.customSelect('''
      SELECT l.action_id, l.action_name, max(l.rowid)
      FROM language_quick_lookups l
      JOIN language_quick_actions a ON a.id = l.action_id
      WHERE a.deleted
      GROUP BY l.action_id
      ORDER BY max(l.rowid) DESC
    ''').get();
    return {
      for (final row in rows)
        row.read<String>('action_id'): row.read<String>('action_name'),
    };
  }

  Future<LanguageQuickLookup?> quickLookup(String id) => (db.select(
    db.languageQuickLookups,
  )..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<LanguageQuickLookup?> cachedQuickLookup(String key) =>
      (db.select(db.languageQuickLookups)
            ..where((row) => row.cacheKey.equals(key))
            ..orderBy([
              (row) => OrderingTerm.desc(row.createdAt),
              (row) => OrderingTerm.desc(row.rowId),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<LanguageQuickLookup> saveQuickLookup(
    QuickQuery query,
    QuickAnswer answer, {
    required ProviderConfig config,
    required String key,
    CancelToken? cancel,
  }) => runOperation(
    () => db.transaction(() async {
      cancel?.checkCancelled();
      final id = const Uuid().v4();
      final row = await db
          .into(db.languageQuickLookups)
          .insertReturning(
            LanguageQuickLookupsCompanion.insert(
              id: id,
              actionId: query.actionId,
              actionName: query.actionName,
              actionRevision: query.actionRevision,
              schemaRevision: quickSchemaRevision,
              prompt: query.prompt,
              input: query.input,
              sourceLanguage: query.sourceLanguage,
              targetLanguage: query.targetLanguage,
              glossLanguage: query.glossLanguage,
              level: query.level,
              detailed: query.detailed,
              summary: answer.summary,
              content: answer.content,
              candidates: answer.candidates.encode(),
              provider: config.kind,
              model: config.model,
              cacheKey: key,
              createdAt: DateTime.now(),
            ),
          );
      cancel?.checkCancelled();
      return row;
    }),
  );

  Future<void> deleteQuickLookup(String id) => runOperation(() async {
    await (db.delete(
      db.languageQuickLookups,
    )..where((row) => row.id.equals(id))).go();
  });

  Future<List<QuickHistoryRow>> quickHistory({
    String? actionId,
    String search = '',
    QuickCursor? before,
  }) async {
    final trimmed = search.replaceAll('\x00', '').trim();
    final query = trimmed.length <= quickSearchLimit
        ? trimmed
        : trimmed.substring(0, quickSearchLimit);
    final conditions = <String>[];
    final parameters = <Variable>[];
    if (actionId != null) {
      conditions.add('action_id = ?');
      parameters.add(Variable(actionId));
    }
    if (query.isNotEmpty) {
      if (query.runes.length >= 3) {
        conditions.add(
          'rowid IN (SELECT rowid FROM language_quick_search WHERE language_quick_search MATCH ?)',
        );
        final escaped = query.replaceAll('"', '""');
        parameters.add(Variable('"$escaped"'));
      } else {
        conditions.add('''
          (instr(lower(input), lower(?)) > 0
           OR instr(lower(summary), lower(?)) > 0
           OR instr(lower(content), lower(?)) > 0)
        ''');
        parameters.addAll(List.generate(3, (_) => Variable(query)));
      }
    }
    if (before != null) {
      conditions.add('(created_at, rowid) < (?, ?)');
      parameters.addAll([Variable(before.time), Variable(before.rowId)]);
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await db.customSelect('''
      SELECT rowid, id, action_id, action_name, input, summary, created_at
      FROM language_quick_lookups
      $where
      ORDER BY created_at DESC, rowid DESC
      LIMIT $quickPageSize
    ''', variables: parameters).get();
    return [
      for (final row in rows)
        (
          id: row.read<String>('id'),
          actionId: row.read<String>('action_id'),
          actionName: row.read<String>('action_name'),
          input: row.read<String>('input'),
          summary: row.read<String>('summary'),
          cursor: (
            time: row.read<int>('created_at'),
            rowId: row.read<int>('rowid'),
          ),
        ),
    ];
  }
}
