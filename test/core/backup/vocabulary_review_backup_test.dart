import "dart:convert";
import "dart:io";

import "package:archive/archive_io.dart";
import "package:crypto/crypto.dart";
import "package:drift_dev/api/migrations_native.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/backup/backup_service.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/features/language_learning/fsrs.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/vocabulary_review_settings.dart";

import "../../generated_migrations/schema.dart";

void main() {
  test(
    "v30 migration and backup keep legacy ratings and original deadlines",
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final v30 = await verifier.schemaAt(30);
      final raw = v30.rawDatabase;
      raw.execute(
        "INSERT INTO learning_vocabulary_groups(id,language,title,group_type,created_at) VALUES('g','en','Travel','topic',1)",
      );
      raw.execute(
        "INSERT INTO learning_lexical_items(id,language,form,normalized_form,lexical_type,created_at) VALUES('i','en','ticket','ticket','word',1)",
      );
      raw.execute(
        "INSERT INTO learning_lexical_senses(id,item_id,meaning,source,created_at) VALUES('s','i','车票','user',1)",
      );
      raw.execute(
        "INSERT INTO learning_group_items(group_id,sense_id) VALUES('g','s')",
      );
      raw.execute(
        "INSERT INTO learning_review_schedules(sense_id,due_at,interval_days,repetitions,updated_at) VALUES('s',172801,2,3,1)",
      );
      raw.execute(
        "INSERT INTO learning_evidence(id,sense_id,skill,rating,answer_revealed,group_prompt,occurred_at) VALUES('old','s','meaningRecall','fuzzy',1,1,1)",
      );
      raw.execute("PRAGMA user_version = 30");
      final directory = await Directory.systemTemp.createTemp(
        "tixun-fsrs-backup-",
      );
      addTearDown(() => directory.delete(recursive: true));
      final legacy = File("${directory.path}/legacy.sqlite");
      raw.execute("VACUUM INTO ?", [legacy.path]);
      final oldBackup = File("${directory.path}/old.tixun-backup");
      final bytes = await legacy.readAsBytes();
      final zip = ZipFileEncoder()
        ..create(oldBackup.path, level: ZipFileEncoder.store);
      zip.addArchiveFile(
        ArchiveFile.string(
          "manifest.json",
          jsonEncode({
            "format": "tixun-backup",
            "version": BackupService.formatVersion,
            "schema": 30,
            "created_at": "2026-01-01T00:00:00Z",
            "files": [
              {
                "path": "database.sqlite",
                "size": bytes.length,
                "sha256": sha256.convert(bytes).toString(),
              },
            ],
          }),
        ),
      );
      await zip.addFile(legacy, "database.sqlite", ZipFileEncoder.store);
      await zip.close();

      final db = AppDatabase(v30.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      final preserved = await db.select(db.learningReviewSchedules).getSingle();
      expect(preserved.dueAt.millisecondsSinceEpoch, 172801000);
      expect(preserved.repetitions, 3);
      expect(preserved.fsrsVersion, isNull);
      expect(preserved.stability, isNull);
      final oldEvidence = await db.select(db.learningEvidence).getSingle();
      expect(oldEvidence.rating, "fuzzy");
      expect(oldEvidence.recallKind, isNull);

      final live = Directory("${directory.path}/live");
      final imported = await BackupService.prepare(oldBackup, live);
      addTearDown(imported.discard);
      final restored = AppDatabase.file(
        File("${imported.data.path}/tixun.sqlite"),
      );
      addTearDown(restored.close);
      expect(
        await restored.select(restored.learningReviewSchedules).getSingle(),
        preserved,
      );
      expect(
        await restored.select(restored.learningEvidence).getSingle(),
        oldEvidence,
      );
      expect(
        await loadVocabularyReviewSettings(restored),
        defaultVocabularyReviewSettings,
      );
      expect(
        (await restored.select(restored.learningGroupItems).getSingle())
            .groupId,
        "g",
      );

      final store = LanguageLearningStore(restored);
      addTearDown(store.dispose);
      final settings = (
        enabled: true,
        retentionPercent: 97,
        maximumInterval: 1,
      );
      await saveVocabularyReviewSettings(restored, settings);
      final now = preserved.dueAt.toUtc();
      await store.recordRecall(
        attemptId: "new",
        senseId: "s",
        rating: RecallRating.good,
        groupPrompt: false,
        now: now,
      );
      final active = await restored
          .select(restored.learningReviewSchedules)
          .getSingle();
      expect(active.fsrsVersion, Fsrs.version);
      expect(active.stability, 2.3065);
      expect(active.repetitions, 4);
      expect(active.dueAt.toUtc(), now.add(const Duration(days: 1)));
      final archive = File("${directory.path}/new.tixun-backup");
      await BackupService.export(
        restored,
        AttachmentStore(imported.data),
        archive,
      );
      final roundTrip = await BackupService.prepare(archive, live);
      addTearDown(roundTrip.discard);
      final reopened = AppDatabase.file(
        File("${roundTrip.data.path}/tixun.sqlite"),
      );
      addTearDown(reopened.close);
      expect(await loadVocabularyReviewSettings(reopened), settings);
      expect(
        await reopened.select(reopened.learningReviewSchedules).getSingle(),
        active,
      );
      final evidence = {
        for (final row
            in await reopened.select(reopened.learningEvidence).get())
          row.id: row,
      };
      expect(evidence["old"], oldEvidence);
      expect(evidence["new"]!.recallKind, "scheduled");
      expect(
        (await reopened.customSelect("PRAGMA foreign_key_check").get()),
        isEmpty,
      );
    },
  );
}
