import 'package:tixun/core/l10n/app_error.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/database/database_notifier.dart';

/// Curriculum folders are shared by notes and mistakes, independent of text history.
class ModuleStore extends DatabaseNotifier {
  ModuleStore(this.db, this.onChange);
  final AppDatabase db;
  final void Function() onChange;
  @override
  void changed() {
    if (isDisposed) return;
    super.changed();
    onChange();
  }

  Stream<List<SubjectModule>> watch([String subject = '']) =>
      (db.select(db.subjectModules)
            ..where(
              (t) => subject.isEmpty
                  ? const Constant(true)
                  : t.subject.equals(subject),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.subject),
              (t) => OrderingTerm.asc(t.position),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .watch();
  Future<List<SubjectModule>> list(String subject) =>
      (db.select(db.subjectModules)
            ..where((t) => t.subject.equals(subject))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();
  Future<String> create(
    String subject,
    String name, {
    String? parentId,
    bool reuseExisting = true,
  }) => runOperation(() async {
    final title = name.trim(), discipline = subject.trim();
    if (title.isEmpty ||
        title.length > 80 ||
        discipline.isEmpty ||
        discipline.length > 40) {
      throw const AppFormatException(
        AppErrorCode.errorFolderNamesMustContain180,
        '目录名称需为 1–80 字，科目需为 1–40 字。',
      );
    }
    final id = await db.transaction(() async {
      final all = await list(discipline);
      if (parentId != null) {
        final parent = all.where((m) => m.id == parentId).firstOrNull;
        if (parent == null || parent.parentId != null) {
          throw const AppFormatException(
            AppErrorCode.errorASubmoduleMustBeUnderA,
            '子模块必须位于同科目的一级模块下。',
          );
        }
      }
      final existing = all
          .where(
            (m) =>
                m.parentId == parentId &&
                m.name.toLowerCase() == title.toLowerCase(),
          )
          .firstOrNull;
      if (existing != null) {
        // The AI create_subject_module tool documents reuse of an
        // existing directory; the UI create path opts out (see
        // ModuleManager.create) so a duplicate name is reported.
        if (!reuseExisting) {
          throw const AppFormatException(
            AppErrorCode.aDirectoryWithThisName,
            '已存在该目录。',
          );
        }
        return existing.id;
      }
      if (all.length >= 500) {
        throw const AppFormatException(
          AppErrorCode.errorEachSubjectCanHaveAtMost,
          '每个科目最多 500 个目录。',
        );
      }
      final key = const Uuid().v4();
      final position = all.fold(
        0,
        (n, m) => m.position >= n ? m.position + 1 : n,
      );
      await db
          .into(db.subjectModules)
          .insert(
            SubjectModulesCompanion.insert(
              id: key,
              subject: discipline,
              name: title,
              parentId: Value(parentId),
              position: position,
            ),
          );
      return key;
    });
    changed();
    return id;
  });
  Future<void> rename(String id, String name) => runOperation(() async {
    final title = name.trim();
    if (title.isEmpty || title.length > 80) {
      throw const AppFormatException(
        AppErrorCode.errorFolderNamesMustContain1802,
        '目录名称需为 1–80 字。',
      );
    }
    await (db.update(db.subjectModules)..where((t) => t.id.equals(id))).write(
      SubjectModulesCompanion(name: Value(title)),
    );
    changed();
  });
  Future<void> delete(String id) => runOperation(() async {
    await (db.delete(db.subjectModules)..where((t) => t.id.equals(id))).go();
    changed();
  });

  /// Moves a module one step among its siblings. Returns false at either
  /// end (and notifies nobody) instead of silently doing nothing.
  Future<bool> move(String id, int direction) => runOperation(() async {
    if (direction != -1 && direction != 1) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidSortDirection,
        '排序方向无效。',
      );
    }
    final moved = await db.transaction(() async {
      final row = await (db.select(
        db.subjectModules,
      )..where((t) => t.id.equals(id))).getSingle();
      final siblings = (await list(row.subject))
          .where((m) => m.parentId == row.parentId)
          .toList();
      final index = siblings.indexWhere((m) => m.id == id),
          target = siblings.indexWhere((m) => m.id == id) + direction;
      if (target < 0 || target >= siblings.length) return false;
      await (db.update(db.subjectModules)..where((t) => t.id.equals(id))).write(
        SubjectModulesCompanion(position: Value(siblings[target].position)),
      );
      await (db.update(
        db.subjectModules,
      )..where((t) => t.id.equals(siblings[target].id))).write(
        SubjectModulesCompanion(position: Value(siblings[index].position)),
      );
      return true;
    });
    if (moved) changed();
    return moved;
  });
  Future<Map<String, List<String>>> paths(
    Iterable<String> ids,
    bool mistake,
  ) async {
    final keys = ids.toSet().toList();
    if (keys.isEmpty) return {};
    final table = mistake ? 'mistake_module_links' : 'knowledge_module_links';
    final idColumn = mistake ? 'mistake_id' : 'knowledge_id';
    final placeholders = List.filled(keys.length, '?').join(',');
    final rows = await db
        .customSelect(
          'SELECT ml.$idColumn item, sm.name name, parent.name parent FROM $table ml JOIN subject_modules sm ON sm.id=ml.module_id LEFT JOIN subject_modules parent ON parent.id=sm.parent_id WHERE ml.$idColumn IN ($placeholders) ORDER BY sm.position',
          variables: keys.map(Variable.new).toList(),
        )
        .get();
    final result = <String, List<String>>{};
    for (final row in rows) {
      final name = row.read<String>('name'),
          parent = row.readNullable<String>('parent');
      (result[row.read<String>('item')] ??= []).add(
        parent == null ? name : '$parent / $name',
      );
    }
    return result;
  }

  Future<List<String>> ids(String id, bool mistake) async {
    if (mistake) {
      return (await (db.select(
            db.mistakeModuleLinks,
          )..where((t) => t.mistakeId.equals(id))).get())
          .map((r) => r.moduleId)
          .toList()
        ..sort();
    }
    return (await (db.select(
          db.knowledgeModuleLinks,
        )..where((t) => t.knowledgeId.equals(id))).get())
        .map((r) => r.moduleId)
        .toList()
      ..sort();
  }

  Future<void> assign(
    String id,
    bool mistake,
    List<String> moduleIds, {
    List<String>? expected,
  }) => runOperation(() async {
    final values = moduleIds.toSet().toList()..sort();
    if (values.length > 20 || values.any((s) => s.isEmpty || s.length > 80)) {
      throw const AppFormatException(
        AppErrorCode.errorEachMaterialCanBeLinkedTo,
        '每条资料最多关联 20 个模块。',
      );
    }
    await db.transaction(() async {
      final table = mistake ? 'mistakes' : 'knowledge_items';
      final item = await db
          .customSelect(
            'SELECT subject FROM $table WHERE id=? AND deleted=0',
            variables: [Variable(id)],
          )
          .getSingleOrNull();
      if (item == null) {
        throw const AppFormatException(
          AppErrorCode.errorTheMaterialDoesNotExistOr,
          '资料不存在或已在回收区。',
        );
      }
      final current = await ids(id, mistake);
      if (expected != null) {
        final previous = expected.toSet().toList()..sort();
        if (previous.join(',') != current.join(',')) {
          throw const AppFormatException(
            AppErrorCode.errorTheCategoryWasChangedElsewhereReopen,
            '分类已被其他操作更新，请重新打开后选择。',
          );
        }
      }
      for (final moduleId in values) {
        final module = await (db.select(
          db.subjectModules,
        )..where((t) => t.id.equals(moduleId))).getSingleOrNull();
        if (module == null || module.subject != item.read<String>('subject')) {
          throw const AppFormatException(
            AppErrorCode.errorOnlyModulesOrSubmodulesInThe,
            '只能关联同科目的模块或子模块。',
          );
        }
      }
      if (mistake) {
        await (db.delete(
          db.mistakeModuleLinks,
        )..where((t) => t.mistakeId.equals(id))).go();
        for (final key in values) {
          await db
              .into(db.mistakeModuleLinks)
              .insert(
                MistakeModuleLinksCompanion.insert(
                  mistakeId: id,
                  moduleId: key,
                ),
              );
        }
      } else {
        await (db.delete(
          db.knowledgeModuleLinks,
        )..where((t) => t.knowledgeId.equals(id))).go();
        for (final key in values) {
          await db
              .into(db.knowledgeModuleLinks)
              .insert(
                KnowledgeModuleLinksCompanion.insert(
                  knowledgeId: id,
                  moduleId: key,
                ),
              );
        }
      }
    });
    changed();
  });
  Future<void> link(String id, bool mistake, String moduleId) => runOperation(
    () => db.transaction(() async {
      final current = await ids(id, mistake);
      await assign(id, mistake, [...current, moduleId], expected: current);
    }),
  );
}

String modulePath(SubjectModule module, List<SubjectModule> all) {
  final parent = all.where((m) => m.id == module.parentId).firstOrNull;
  return parent == null ? module.name : '${parent.name} / ${module.name}';
}
