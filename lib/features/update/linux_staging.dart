import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Linux staged in-app update support.
///
/// The swap only ever touches the application bundle directory (the
/// directory containing the running executable, see [bundleDirectory])
/// and its siblings: the `.new-<tag>` staging directory, the `.old`
/// backup directory and the `.pending.json` marker file.
///
/// User data lives elsewhere — [AppController.rootDirectory] resolves to
/// `<application-support>/tixun` — and is never touched by anything in
/// this file.
///
/// Behaviour is Linux-only, but the code is kept importable and testable
/// on any platform: platform-specific steps (e.g. chmod) are guarded
/// with [Platform.isLinux] inside the functions, not at import time.
/// The public functions resolve their paths from the real bundle
/// directory; the `...Into` / `...For` variants below take the bundle
/// directory as a parameter so tests can exercise the same logic against
/// temp directories without touching the real bundle.
class PendingUpdate {
  final String tag;
  final String stagedPath;

  const PendingUpdate({required this.tag, required this.stagedPath});
}

enum ApplyResult {
  nothingPending,
  failed,
  // NOTE: on success this API never returns — it restarts the process
  // (see [applyPendingUpdate]).
}

/// The directory containing the running executable.
Directory bundleDirectory() =>
    Directory(File(Platform.resolvedExecutable).parent.path);

/// Marker file for [bundleDir]: `<bundleDir>.pending.json`.
File _markerFile(Directory bundleDir) => File('${bundleDir.path}.pending.json');

/// Staging directory for [bundleDir] and [tag]:
/// `<bundleDir>.new-<tag>` — a sibling of the bundle dir, so the swap
/// is a rename on the same filesystem.
Directory _stagingDir(Directory bundleDir, String tag) =>
    Directory('${bundleDir.path}.new-${_sanitizeTag(tag)}');

/// Backup directory for [bundleDir]: `<bundleDir>.old`.
Directory _oldDir(Directory bundleDir) => Directory('${bundleDir.path}.old');

/// Tags come from release names; keep only filename-safe characters so
/// the staging directory name can never escape its parent.
String _sanitizeTag(String tag) =>
    tag.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

/// Extract [tarGzFile] (top level contains the `tixun` binary plus
/// `lib/` and `data/`) into a staging directory that is a sibling of
/// the bundle dir. After extracting, the `tixun` binary inside staging
/// is made executable (mode 0x1ED).
///
/// Returns the staging directory. Throws on failure, leaving no
/// half-extracted staging directory behind.
Future<Directory> stageLinuxUpdate({
  required File tarGzFile,
  required String tag,
}) => stageLinuxUpdateInto(
  bundleDir: bundleDirectory(),
  tarGzFile: tarGzFile,
  tag: tag,
);

Future<Directory> stageLinuxUpdateInto({
  required Directory bundleDir,
  required File tarGzFile,
  required String tag,
}) async {
  final staging = _stagingDir(bundleDir, tag);
  if (await staging.exists()) {
    await staging.delete(recursive: true);
  }
  try {
    final gzBytes = await tarGzFile.readAsBytes();
    final tarBytes = GZipDecoder().decodeBytes(gzBytes);
    final archive = TarDecoder().decodeBytes(tarBytes);
    await staging.create(recursive: true);
    for (final entry in archive) {
      final relative = p.normalize(entry.name);
      // Reject absolute paths and anything escaping the staging dir.
      if (p.isAbsolute(relative) ||
          relative == '..' ||
          relative.startsWith('../') ||
          p.split(relative).contains('..')) {
        throw FormatException('Unsafe entry in update archive: ${entry.name}');
      }
      final outPath = p.join(staging.path, relative);
      if (entry.isFile) {
        final outFile = File(outPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(entry.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
    final binary = File(p.join(staging.path, 'tixun'));
    if (!await binary.exists()) {
      throw StateError('Update archive does not contain a tixun binary.');
    }
    if (Platform.isLinux) {
      final result = await Process.run('chmod', ['755', binary.path]);
      if (result.exitCode != 0) {
        throw StateError(
          'Failed to make staged tixun binary executable: ${result.stderr}',
        );
      }
    }
    return staging;
  } catch (_) {
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    rethrow;
  }
}

/// Write the pending-update marker as a sibling of the bundle dir
/// (`<bundleDir>.pending.json`, keys `tag` and `stagedPath`). The marker
/// survives the swap because it lives outside the bundle dir, and it
/// never lives in the user data dir.
Future<void> markPendingUpdate({
  required String tag,
  required String stagedPath,
}) => markPendingUpdateFor(
  bundleDir: bundleDirectory(),
  tag: tag,
  stagedPath: stagedPath,
);

Future<void> markPendingUpdateFor({
  required Directory bundleDir,
  required String tag,
  required String stagedPath,
}) async {
  final marker = _markerFile(bundleDir);
  await marker.writeAsString(
    jsonEncode({'tag': tag, 'stagedPath': stagedPath}),
  );
}

/// Sync read of the marker file; null when absent or unparsable.
/// An unparsable marker is treated as absent AND deleted.
PendingUpdate? readPendingUpdate() =>
    readPendingUpdateFor(bundleDir: bundleDirectory());

PendingUpdate? readPendingUpdateFor({required Directory bundleDir}) {
  final marker = _markerFile(bundleDir);
  if (!marker.existsSync()) return null;
  try {
    final decoded = jsonDecode(marker.readAsStringSync());
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    final tag = decoded['tag'];
    final stagedPath = decoded['stagedPath'];
    if (tag is! String ||
        tag.isEmpty ||
        stagedPath is! String ||
        stagedPath.isEmpty) {
      throw const FormatException();
    }
    return PendingUpdate(tag: tag, stagedPath: stagedPath);
  } catch (_) {
    try {
      marker.deleteSync();
    } catch (_) {
      // Best effort: a stale corrupt marker must not block startup.
    }
    return null;
  }
}

/// Swap [bundleDir] with [stagingDir]: delete any previous `.old`,
/// rename bundle -> `.old`, rename staging -> bundle.
///
/// Returns false on any failure, in which case it attempts to restore
/// (rename `.old` back if the bundle dir is missing). The marker and
/// staging directory are left untouched so the caller can retry.
Future<bool> swapBundleDirectories({
  required Directory bundleDir,
  required Directory stagingDir,
}) async {
  final oldDir = _oldDir(bundleDir);
  try {
    if (!await stagingDir.exists()) return false;
    if (await oldDir.exists()) {
      await oldDir.delete(recursive: true);
    }
    await bundleDir.rename(oldDir.path);
    try {
      await stagingDir.rename(bundleDir.path);
    } catch (_) {
      // Second rename failed: put the old bundle back.
      await oldDir.rename(bundleDir.path);
      return false;
    }
    return true;
  } catch (_) {
    // Attempt to restore the old bundle if the bundle dir is missing.
    try {
      if (!await bundleDir.exists() && await oldDir.exists()) {
        await oldDir.rename(bundleDir.path);
      }
    } catch (_) {
      // Nothing more we can do; the marker is kept for a manual retry.
    }
    return false;
  }
}

/// If a pending update is marked, swap it in, delete the marker, then
/// spawn the new binary (same path as before — the bundle dir path is
/// unchanged, only its contents were swapped) and exit this process.
///
/// On success this function never returns. On any failure mid-swap it
/// attempts to restore the old bundle, returns [ApplyResult.failed],
/// and keeps the marker + staging directory so the user can retry from
/// Settings. Returns [ApplyResult.nothingPending] when no marker exists.
Future<ApplyResult> applyPendingUpdate() async {
  final pending = readPendingUpdate();
  if (pending == null) return ApplyResult.nothingPending;
  final bundleDir = bundleDirectory();
  final stagingDir = Directory(pending.stagedPath);
  final swapped = await swapBundleDirectories(
    bundleDir: bundleDir,
    stagingDir: stagingDir,
  );
  if (!swapped) return ApplyResult.failed;
  try {
    await _markerFile(bundleDir).delete();
  } catch (_) {
    // Best effort: the new process still launches the swapped bundle.
  }
  await Process.start(
    Platform.resolvedExecutable,
    [],
    mode: ProcessStartMode.detached,
  );
  exit(0);
}

/// Delete `<bundleDir>.old` if it exists. Called once per startup AFTER
/// the apply check, so only the new binary ever deletes `.old` — which
/// proves the new launch succeeded.
Future<void> cleanupOldBundle() =>
    cleanupOldBundleFor(bundleDir: bundleDirectory());

Future<void> cleanupOldBundleFor({required Directory bundleDir}) async {
  final oldDir = _oldDir(bundleDir);
  if (await oldDir.exists()) {
    await oldDir.delete(recursive: true);
  }
}

/// Remove the marker + staging directory (user cancels the staged
/// update). A corrupt marker is removed as well; its staging path is
/// then unknown and left alone.
Future<void> discardPendingUpdate() =>
    discardPendingUpdateFor(bundleDir: bundleDirectory());

Future<void> discardPendingUpdateFor({required Directory bundleDir}) async {
  final marker = _markerFile(bundleDir);
  String? stagedPath;
  if (marker.existsSync()) {
    try {
      final decoded = jsonDecode(marker.readAsStringSync());
      if (decoded is Map<String, dynamic>) {
        final value = decoded['stagedPath'];
        if (value is String && value.isNotEmpty) stagedPath = value;
      }
    } catch (_) {
      // Corrupt marker: still delete it below.
    }
    try {
      await marker.delete();
    } catch (_) {}
  }
  if (stagedPath != null) {
    final staging = Directory(stagedPath);
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
  }
}
