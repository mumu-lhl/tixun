part of "backup_service.dart";

Future<BackupPreview> _encode(
  String rootPath,
  String snapshotPath,
  String outPath,
) async {
  final root = Directory(rootPath), snapshot = File(snapshotPath);
  final info = _checkDatabase(snapshotPath);
  final paths = <String, File>{"database.sqlite": snapshot};
  final dir = Directory(p.join(root.path, "attachments"));
  if (await dir.exists()) {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const AppFormatException(
          AppErrorCode.errorTheAttachmentDirectoryContainsSymbolicLinks,
          "附件目录包含符号链接，无法安全备份。",
        );
      }
      if (type != FileSystemEntityType.file) continue;
      final name = p.posix.joinAll(
        p.split(p.relative(entity.path, from: root.path)),
      );
      _checkedPath(name);
      paths[name] = File(entity.path);
    }
  }
  if (paths.length > BackupService._maxEntries - 1) {
    throw const AppFormatException(
      AppErrorCode.errorTheNumberOfAttachmentsExceedsThe,
      "附件数量超过备份上限。",
    );
  }
  final manifestFiles = <Map<String, dynamic>>[];
  var bytes = 0;
  for (final entry in paths.entries) {
    final length = await entry.value.length();
    _checkSize(entry.key, length);
    bytes += length;
    if (bytes > BackupService._maxBytes) {
      throw const AppFormatException(
        AppErrorCode.errorTheUncompressedBackupExceedsThe8,
        "备份原始数据超过 8 GiB 上限。",
      );
    }
    manifestFiles.add({
      "path": entry.key,
      "size": length,
      "sha256": await _hash(entry.value),
    });
  }
  for (final path in info.references) {
    _checkedPath(path);
    if (!path.startsWith("attachments/") || !paths.containsKey(path)) {
      throw const AppFormatException(
        AppErrorCode.errorSomeImageAttachmentsAreMissingRepair,
        "有图片附件缺失；请修复后再备份，以免生成不完整副本。",
      );
    }
  }
  final now = DateTime.now().toUtc();
  final manifest = jsonEncode({
    "format": "tixun-backup",
    "version": BackupService.formatVersion,
    "schema": info.schema,
    "created_at": now.toIso8601String(),
    "files": manifestFiles,
    "counts": info.counts,
  });
  if (utf8.encode(manifest).length > BackupService._manifestLimit) {
    throw const AppFormatException(
      AppErrorCode.errorTheBackupManifestIsTooLarge,
      "备份清单过大。",
    );
  }
  // Photos are already compressed. STORE streams every file without retaining
  // a database-sized compression buffer; restore accepts only this format.
  final encoder = ZipFileEncoder()
    ..create(outPath, level: ZipFileEncoder.store);
  try {
    encoder.addArchiveFile(ArchiveFile.string("manifest.json", manifest));
    for (final entry in paths.entries) {
      await encoder.addFile(entry.value, entry.key, ZipFileEncoder.store);
    }
  } finally {
    await encoder.close();
  }
  return BackupPreview(now, info.schema, paths.length - 1, bytes, info.counts);
}

Future<BackupPreview> _decode(String inputPath, String targetPath) async {
  final inputFile = File(inputPath);
  if (await inputFile.length() > BackupService._maxBytes + 128 * 1024 * 1024) {
    throw const AppFormatException(
      AppErrorCode.errorTheBackupFileIsTooLarge,
      "备份文件过大。",
    );
  }
  final input = InputFileStream(inputPath);
  try {
    // Validate the central directory before any content is read. In particular,
    // reject duplicate paths and Unix symlinks before ZipDecoder visits them.
    final directory = ZipDirectory()..read(input, verify: true);
    if (directory.fileHeaders.isEmpty ||
        directory.fileHeaders.length > BackupService._maxEntries) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidNumberOfFilesInThe,
        "备份文件数量无效。",
      );
    }
    final names = <String>{};
    var total = 0;
    for (final h in directory.fileHeaders) {
      final name = h.filename;
      _checkedPath(name);
      _checkSize(name, h.uncompressedSize);
      if (!names.add(name) ||
          h.compressionMethod != 0 ||
          h.compressedSize != h.uncompressedSize ||
          ((h.externalFileAttributes >> 16) & 0xf000) == 0xa000) {
        throw const AppFormatException(
          AppErrorCode.errorTheBackupContainsDuplicateFilesLinks,
          "备份含重复文件、链接或不支持的压缩方式。",
        );
      }
      total += h.uncompressedSize;
      if (total > BackupService._maxBytes + BackupService._manifestLimit) {
        throw const AppFormatException(
          AppErrorCode.errorTheExpandedBackupIsTooLarge,
          "备份展开内容过大。",
        );
      }
    }
    input.position = 0;
    final archive = ZipDecoder().decodeStream(
      input,
      verify: true,
      throwOnError: true,
    );
    final entry = archive.findFile("manifest.json");
    if (entry == null) {
      throw const AppFormatException(
        AppErrorCode.errorTheBackupManifestIsMissing,
        "缺少备份清单。",
      );
    }
    final manifest = (jsonDecode(utf8.decode(entry.readBytes()!)) as Map)
        .cast<String, dynamic>();
    if (manifest["format"] != "tixun-backup" ||
        manifest["version"] != BackupService.formatVersion ||
        manifest["schema"] is! int ||
        manifest["schema"] < 1 ||
        manifest["schema"] > AppDatabase.latestSchemaVersion) {
      throw const AppFormatException(
        AppErrorCode.errorTheBackupFormatOrDatabaseVersion,
        "备份格式或数据库版本不受支持，请检查应用版本。",
      );
    }
    final date = DateTime.tryParse(manifest["created_at"] as String? ?? "");
    if (date == null || manifest["files"] is! List) {
      throw const AppFormatException(
        AppErrorCode.errorTheBackupManifestIsIncomplete,
        "备份清单不完整。",
      );
    }
    final expected = <String, Map<String, dynamic>>{};
    for (final raw in manifest["files"] as List) {
      final m = (raw as Map).cast<String, dynamic>();
      if (m["path"] is! String ||
          m["size"] is! int ||
          m["sha256"] is! String ||
          !RegExp(r"^[a-f0-9]{64}$").hasMatch(m["sha256"] as String)) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidBackupChecksumInformation,
          "备份校验信息无效。",
        );
      }
      final name = m["path"] as String;
      _checkedPath(name);
      _checkSize(name, m["size"] as int);
      if (name == "manifest.json" || expected.containsKey(name)) {
        throw const AppFormatException(
          AppErrorCode.errorTheBackupManifestContainsDuplicatePaths,
          "备份清单路径重复。",
        );
      }
      expected[name] = m;
    }
    if (!expected.containsKey("database.sqlite") ||
        expected.length != archive.length - 1 ||
        !names.containsAll(expected.keys)) {
      throw const AppFormatException(
        AppErrorCode.errorTheBackupManifestDoesNotMatch,
        "备份清单与文件不一致。",
      );
    }
    final target = Directory(targetPath);
    await target.create(recursive: true);
    var actualBytes = 0;
    for (final f in archive) {
      if (f.name == "manifest.json") continue;
      final record = expected[f.name];
      if (!f.isFile ||
          f.isSymbolicLink ||
          record == null ||
          record["size"] != f.size) {
        throw const AppFormatException(
          AppErrorCode.errorTheBackupFileInformationDoesNot,
          "备份文件信息不一致。",
        );
      }
      final output = File(
        p.join(
          target.path,
          f.name == "database.sqlite" ? "tixun.sqlite" : f.name,
        ),
      );
      if (!p.isWithin(target.path, output.path)) {
        throw const AppFormatException(
          AppErrorCode.errorTheAttachmentPathIsOutsideThe,
          "附件路径越界。",
        );
      }
      await output.parent.create(recursive: true);
      final stream = OutputFileStream(output.path);
      try {
        f.writeContent(stream);
      } finally {
        await stream.close();
      }
      if (await output.length() != record["size"] ||
          await _hash(output) != record["sha256"]) {
        throw const AppFormatException(
          AppErrorCode.errorBackupIntegrityVerificationFailedExistingData,
          "备份完整性校验失败，未修改现有数据。",
        );
      }
      actualBytes += await output.length();
    }
    final info = _checkDatabase(p.join(target.path, "tixun.sqlite"));
    if (info.schema != manifest["schema"]) {
      throw const AppFormatException(
        AppErrorCode.errorTheDatabaseVersionDoesNotMatch,
        "数据库与备份版本不一致。",
      );
    }
    for (final relative in info.references) {
      _checkedPath(relative);
      if (!relative.startsWith("attachments/") ||
          !expected.containsKey(relative)) {
        throw const AppFormatException(
          AppErrorCode.errorTheBackupIsMissingAttachmentsReferenced,
          "备份缺少数据库引用的附件。",
        );
      }
    }
    return BackupPreview(
      date,
      info.schema,
      expected.length - 1,
      actualBytes,
      info.counts,
    );
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const AppFormatException(
      AppErrorCode.errorCannotReadTheBackupItMay,
      "无法读取备份，文件可能损坏或格式不受支持。",
    );
  } finally {
    await input.close();
  }
}

Future<void> _migrateAndCheck(Directory root) async {
  final db = AppDatabase.file(File(p.join(root.path, "tixun.sqlite")));
  try {
    final check = await db
        .customSelect("PRAGMA integrity_check(1)")
        .getSingle();
    if (check.data.values.single != "ok" ||
        (await db.customSelect("PRAGMA foreign_key_check").get()).isNotEmpty) {
      throw const AppFormatException(
        AppErrorCode.errorDatabaseIntegrityCheckFailed,
        "数据库完整性检查失败。",
      );
    }
    // Check declared columns too: a forged user_version must not skip tables.
    for (final table in db.allTables) {
      final columns = table.$columns.map((c) => 't."${c.$name}"').join(",");
      await db
          .customSelect(
            'SELECT $columns FROM "${table.actualTableName}" AS t LIMIT 0',
          )
          .get();
    }
    await (db.update(db.chatSessions))
        .write(const ChatSessionsCompanion(toolsEnabled: Value(false)));
    await db.customStatement("PRAGMA wal_checkpoint(TRUNCATE)");
  } finally {
    await db.close();
  }
}

void _checkedPath(String name) {
  if (name.isEmpty ||
      name.length > 512 ||
      name.contains("\\") ||
      name.contains(":") ||
      name.contains("\u0000") ||
      p.posix.isAbsolute(name) ||
      p.posix.normalize(name) != name ||
      name.split("/").any((s) => s == ".." || s == "." || s.isEmpty) ||
      !(name == "manifest.json" ||
          name == "database.sqlite" ||
          name.startsWith("attachments/"))) {
    throw const AppFormatException(
      AppErrorCode.errorInvalidAttachmentPathInTheBackup,
      "备份附件路径无效。",
    );
  }
}

void _checkSize(String name, int size) {
  final max = name == "database.sqlite"
      ? BackupService._databaseLimit
      : name == "manifest.json"
      ? BackupService._manifestLimit
      : BackupService._imageLimit;
  if (size < 0 || size > max) {
    throw const AppFormatException(
      AppErrorCode.errorAFileInTheBackupHas,
      "备份中的单个文件大小无效或超过上限。",
    );
  }
}

({int schema, Map<String, int> counts, List<String> references}) _checkDatabase(
  String path,
) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final version =
        db.select("PRAGMA user_version").single.values.single as int;
    if (version < 1 ||
        version > AppDatabase.latestSchemaVersion ||
        db.select("PRAGMA integrity_check(1)").single.values.single != "ok" ||
        db
            .select("SELECT * FROM pragma_foreign_key_check LIMIT 1")
            .isNotEmpty) {
      throw const AppFormatException(
        AppErrorCode.errorTheBackupDatabaseIsInvalidOr,
        "备份数据库无效或版本不受支持。",
      );
    }
    final tables = db
        .select("SELECT name FROM sqlite_master WHERE type='table'")
        .map((r) => r["name"] as String)
        .toSet();
    if (!tables.containsAll([
      "chat_sessions",
      "chat_messages",
      "attachments",
      "provider_configs",
      "preferences",
    ])) {
      throw const AppFormatException(
        AppErrorCode.errorThisDatabaseDoesNotBelongTo,
        "数据库不属于题训。",
      );
    }
    const counters = {
      "chat_sessions": "chats",
      "knowledge_items": "knowledge",
      "mistakes": "mistakes",
      "practice_questions": "questions",
      "practice_attempts": "attempts",
      "review_schedules": "reviews",
      "exam_events": "exams",
    };
    final counts = <String, int>{};
    for (final e in counters.entries) {
      counts[e.value] = tables.contains(e.key)
          ? db.select("SELECT count(*) n FROM ${e.key}").single["n"] as int
          : 0;
    }
    final refs = <String>[];
    for (final table in [
      "attachments",
      "study_attachments",
      "practice_images",
      "exam_attachments",
    ]) {
      if (tables.contains(table)) {
        refs.addAll(
          db
              .select("SELECT DISTINCT relative_path FROM $table")
              .map((r) => r["relative_path"] as String),
        );
      }
    }
    for (final table in ["attachments", "exam_attachments"]) {
      if (tables.contains(table) &&
          db
              .select("PRAGMA table_info($table)")
              .any((r) => r["name"] == "original_path")) {
        refs.addAll(
          db
              .select(
                "SELECT DISTINCT original_path FROM $table WHERE original_path IS NOT NULL",
              )
              .map((r) => r["original_path"] as String),
        );
      }
    }
    return (schema: version, counts: counts, references: refs);
  } finally {
    db.close();
  }
}

Future<String> _hash(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();
