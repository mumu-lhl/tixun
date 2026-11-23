import "dart:convert";

import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:drift/drift.dart";
import "package:uuid/uuid.dart";

import "../../core/ai/chat_provider.dart";
import "../../core/database/database.dart";

typedef GenerationComparison = Future<bool> Function(
  LanguageGenerationRun original,
  LanguageGenerationRun candidate,
  CancelToken cancel,
);

String _digest(String content) =>
    sha256.convert(utf8.encode(content)).toString();

class GenerationOriginal {
  const GenerationOriginal({
    required this.output,
    required this.model,
    this.kind,
    this.contentId,
  });
  final String output, model;
  final String? kind, contentId;
}

class LanguageGenerationStore {
  const LanguageGenerationStore(this.db);
  final AppDatabase db;
  static const _uuid = Uuid();

  Stream<List<LanguageGenerationRun>> watch() =>
      (db.select(db.languageGenerationRuns)..orderBy([
            (r) => OrderingTerm.desc(r.createdAt),
            (r) => OrderingTerm.desc(r.rowId),
          ]))
          .watch();

  Future<LanguageGenerationRun?> active(String taskId) async {
    final task = await (db.select(
      db.languageGenerationTasks,
    )..where((r) => r.id.equals(taskId))).getSingleOrNull();
    if (task?.activeRunId == null) return null;
    return (db.select(
      db.languageGenerationRuns,
    )..where((r) => r.id.equals(task!.activeRunId!))).getSingleOrNull();
  }

  Future<LanguageGenerationRun> capture({
    required String feature,
    required AiRequest request,
    required ProviderConfig config,
    required String output,
    required String format,
    required CancelToken cancel,
    GenerationComparison? compare,
    GenerationOriginal? original,
  }) async {
    // Model and prompt deliberately do not identify the task: changing either
    // must allow comparison against the same input. Input stays byte-exact.
    final input = jsonEncode([
      for (final m in request.messages) {"role": m.role.name, "text": m.text},
    ]);
    var identityInput = input;
    if (feature == "language_exam_generation") {
      final messages = jsonDecode(input) as List;
      for (final m in messages) {
        final data = jsonDecode(m["text"] as String) as Map;
        data.remove("excludeTitles");
        m["text"] = jsonEncode(data);
      }
      identityInput = jsonEncode(messages);
    }
    final taskId = _digest(jsonEncode([feature, identityInput]));
    final promptId = _digest(request.instructions);
    final id = _uuid.v4();
    var previous = await active(taskId);
    await db.transaction(() async {
      cancel.checkCancelled();
      await db
          .into(db.languagePromptSnapshots)
          .insert(
            LanguagePromptSnapshotsCompanion.insert(
              id: promptId,
              content: request.instructions,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await db
          .into(db.languageGenerationTasks)
          .insert(
            LanguageGenerationTasksCompanion.insert(
              id: taskId,
              feature: feature,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      if (previous == null && original != null) {
        final legacyId = _uuid.v4();
        final source = original.kind == null || original.contentId == null
            ? null
            : await currentContentRun(original.kind!, original.contentId!);
        await db
            .into(db.languageGenerationRuns)
            .insert(
              LanguageGenerationRunsCompanion.insert(
                id: legacyId,
                taskId: taskId,
                inputJson: source?.inputJson ?? "null",
                promptId: Value(source?.promptId),
                provider: Value(source?.provider),
                endpoint: Value(source?.endpoint),
                thinking: Value(source?.thinking),
                effort: Value(source?.effort),
                model: original.model,
                optionsJson: jsonEncode({
                  "imported": true,
                  if (source != null) "derivedFrom": source.id,
                }),
                output: original.output,
                format: format,
                createdAt: DateTime.now(),
              ),
            );
        await (db.update(
          db.languageGenerationTasks,
        )..where((r) => r.id.equals(taskId) & r.activeRunId.isNull())).write(
          LanguageGenerationTasksCompanion(activeRunId: Value(legacyId)),
        );
        if (original.kind != null && original.contentId != null) {
          await link(original.kind!, original.contentId!, legacyId);
        }
      }
      await db
          .into(db.languageGenerationRuns)
          .insert(
            LanguageGenerationRunsCompanion.insert(
              id: id,
              taskId: taskId,
              promptId: Value(promptId),
              inputJson: input,
              provider: Value(config.kind),
              endpoint: Value(config.baseUrl),
              model: config.model,
              thinking: Value(AiOptions(config).reasoningEnabled),
              effort: Value(config.effort),
              optionsJson: jsonEncode({
                "supportsThinking": config.supportsThinking,
                "maxOutputTokens": request.maxOutputTokens,
              }),
              output: output,
              format: format,
              createdAt: DateTime.now(),
            ),
          );
    });
    previous ??= await active(taskId);
    final candidate = await (db.select(
      db.languageGenerationRuns,
    )..where((r) => r.id.equals(id))).getSingle();
    cancel.checkCancelled();
    final useNew =
        previous == null ||
        compare == null ||
        await compare(previous, candidate, cancel);
    cancel.checkCancelled();
    final chosen = useNew ? candidate : previous;
    await db.transaction(() async {
      cancel.checkCancelled();
      // An older request finishing its dialog must not replace a newer choice.
      final tasks = db.languageGenerationTasks;
      final updated =
          await (db.update(tasks)..where(
                (r) =>
                    r.id.equals(taskId) &
                    (previous == null
                        ? r.activeRunId.isNull()
                        : r.activeRunId.equals(previous.id)),
              ))
              .write(
                LanguageGenerationTasksCompanion(activeRunId: Value(chosen.id)),
              );
      if (updated == 0) return;
      await db
          .into(db.languageGenerationChoices)
          .insert(
            LanguageGenerationChoicesCompanion.insert(
              id: _uuid.v4(),
              taskId: taskId,
              previousRunId: Value(previous?.id),
              candidateRunId: candidate.id,
              chosenRunId: chosen.id,
              createdAt: DateTime.now(),
            ),
          );
    });
    return (await active(taskId))!;
  }

  Future<String?> linkedContent(String kind, String? runId) async {
    if (runId == null) return null;
    final row =
        await (db.select(db.languageGenerationLinks)
              ..where((r) => r.kind.equals(kind) & r.runId.equals(runId))
              ..limit(1))
            .getSingleOrNull();
    return row?.contentId;
  }

  Future<LanguageGenerationRun?> currentContentRun(
    String kind,
    String contentId,
  ) async {
    final links = db.languageGenerationLinks;
    final runs = db.languageGenerationRuns;
    final row =
        await (db.select(runs).join([
                innerJoin(
                  links,
                  links.runId.equalsExp(runs.id),
                  useColumns: false,
                ),
              ])
              ..where(
                links.kind.equals(kind) & links.contentId.equals(contentId),
              )
              ..orderBy([
                OrderingTerm.desc(links.selectionOrder),
                OrderingTerm.desc(links.rowId),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row?.readTable(runs);
  }

  Future<void> link(String kind, String contentId, String? runId) async {
    if (runId == null) return;
    await db.transaction(() async {
      final links = db.languageGenerationLinks;
      final previous =
          await (db.select(links)
                ..where(
                  (l) => l.kind.equals(kind) & l.contentId.equals(contentId),
                )
                ..orderBy([(l) => OrderingTerm.desc(l.selectionOrder)])
                ..limit(1))
              .getSingleOrNull();
      await db
          .into(links)
          .insertOnConflictUpdate(
            LanguageGenerationLinksCompanion.insert(
              kind: kind,
              contentId: contentId,
              runId: runId,
              selectionOrder: (previous?.selectionOrder ?? 0) + 1,
            ),
          );
    });
  }

  /// Export one consistent, read-only snapshot. Credentials and private
  /// reasoning never enter these tables or this archive.
  Future<String> exportJsonl() => db.transaction(() async {
    final prompts = await db.select(db.languagePromptSnapshots).get();
    final tasks = await db.select(db.languageGenerationTasks).get();
    final runs = await db.select(db.languageGenerationRuns).get();
    final choices = await db.select(db.languageGenerationChoices).get();
    final links = await db.select(db.languageGenerationLinks).get();
    return "${[
      jsonEncode({"type": "manifest", "version": 1}),
      for (final p in prompts) jsonEncode({"type": "prompt", ...p.toJson()}),
      for (final t in tasks) jsonEncode({"type": "task", ...t.toJson()}),
      for (final r in runs) jsonEncode({"type": "run", ...r.toJson()}),
      for (final c in choices) jsonEncode({"type": "choice", ...c.toJson()}),
      for (final l in links) jsonEncode({"type": "link", ...l.toJson()}),
    ].join("\n")}\n";
  });

  Future<String> exportCsv() => db.transaction(() async {
    final tasks = {
      for (final t in await db.select(db.languageGenerationTasks).get())
        t.id: t,
    };
    final runs = await db.select(db.languageGenerationRuns).get();
    String cell(Object? value) {
      var s = value?.toString() ?? "";
      if (RegExp(r"^[=+@\-\t\r]").hasMatch(s)) s = "'$s";
      return '"${s.replaceAll('"', '""')}"';
    }

    return '${[
      ['run_id', 'task_id', 'feature', 'provider', 'model', 'thinking', 'effort', 'prompt_id', 'adopted', 'created_at'].map(cell).join(','),
      for (final r in runs) [r.id, r.taskId, tasks[r.taskId]?.feature, r.provider, r.model, r.thinking, r.effort, r.promptId, tasks[r.taskId]?.activeRunId == r.id, r.createdAt.toUtc().toIso8601String()].map(cell).join(','),
    ].join('\r\n')}\r\n';
  });
}
