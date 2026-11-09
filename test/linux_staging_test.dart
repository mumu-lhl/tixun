import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tixun/features/update/linux_staging.dart';

/// Build a minimal update tar.gz in memory: a `tixun` binary plus
/// `lib/` and `data/` entries.
List<int> _buildUpdateTarGz({List<int>? binaryBytes}) {
  final archive = Archive();
  final binary = binaryBytes ?? utf8.encode('#!/bin/sh\necho new\n');
  archive.addFile(ArchiveFile('tixun', binary.length, binary));
  final lib = utf8.encode('fake-lib');
  archive.addFile(ArchiveFile('lib/libfoo.so', lib.length, lib));
  final data = utf8.encode('hello');
  archive.addFile(ArchiveFile('data/x.txt', data.length, data));
  return GZipEncoder().encode(TarEncoder().encode(archive));
}

Future<Directory> _tempBundle() async {
  final root = await Directory.systemTemp.createTemp('tixun-staging-');
  final bundle = Directory(p.join(root.path, 'tixun-bundle'));
  await bundle.create();
  await File(p.join(bundle.path, 'tixun')).writeAsString('old binary');
  return bundle;
}

void main() {
  test('bundleDirectory is the parent of the running executable', () {
    expect(
      bundleDirectory().path,
      File(Platform.resolvedExecutable).parent.path,
    );
  });

  test('stage extracts tar.gz and makes the binary executable', () async {
    final bundle = await _tempBundle();
    addTearDown(() => bundle.parent.delete(recursive: true));
    final tarGz = File(p.join(bundle.parent.path, 'update.tar.gz'));
    await tarGz.writeAsBytes(_buildUpdateTarGz());

    final staging = await stageLinuxUpdateInto(
      bundleDir: bundle,
      tarGzFile: tarGz,
      tag: 'v0.6.0',
    );

    expect(staging.path, '${bundle.path}.new-v0.6.0');
    expect(
      await File(p.join(staging.path, 'tixun')).readAsString(),
      contains('echo new'),
    );
    expect(
      await File(p.join(staging.path, 'lib', 'libfoo.so')).exists(),
      isTrue,
    );
    expect(
      await File(p.join(staging.path, 'data', 'x.txt')).readAsString(),
      'hello',
    );
    // 0x1ED == 0755.
    final mode = FileStat.statSync(p.join(staging.path, 'tixun')).mode;
    expect(mode & 0x1FF, 0x1ED);
    // The real bundle is untouched.
    expect(
      await File(p.join(bundle.path, 'tixun')).readAsString(),
      'old binary',
    );
  });

  test('stage sanitizes an unsafe tag', () async {
    final bundle = await _tempBundle();
    addTearDown(() => bundle.parent.delete(recursive: true));
    final tarGz = File(p.join(bundle.parent.path, 'update.tar.gz'));
    await tarGz.writeAsBytes(_buildUpdateTarGz());

    final staging = await stageLinuxUpdateInto(
      bundleDir: bundle,
      tarGzFile: tarGz,
      tag: 'v1.0/x y',
    );

    expect(staging.path, '${bundle.path}.new-v1.0_x_y');
    expect(
      p.split(staging.path).length,
      p.split(bundle.parent.path).length + 1,
    );
  });

  test('stage failure leaves no half-extracted staging dir', () async {
    final bundle = await _tempBundle();
    addTearDown(() => bundle.parent.delete(recursive: true));
    final bad = File(p.join(bundle.parent.path, 'bad.tar.gz'));
    await bad.writeAsBytes(utf8.encode('not a gzip at all'));

    await expectLater(
      stageLinuxUpdateInto(bundleDir: bundle, tarGzFile: bad, tag: 'v0.6.0'),
      throwsA(anything),
    );
    expect(await Directory('${bundle.path}.new-v0.6.0').exists(), isFalse);
  });

  test('stage rejects an archive missing the tixun binary', () async {
    final bundle = await _tempBundle();
    addTearDown(() => bundle.parent.delete(recursive: true));
    final archive = Archive();
    final data = utf8.encode('hello');
    archive.addFile(ArchiveFile('data/x.txt', data.length, data));
    final tarGz = File(p.join(bundle.parent.path, 'update.tar.gz'));
    await tarGz.writeAsBytes(
      GZipEncoder().encode(TarEncoder().encode(archive)),
    );

    await expectLater(
      stageLinuxUpdateInto(bundleDir: bundle, tarGzFile: tarGz, tag: 'v0.6.0'),
      throwsA(anything),
    );
    expect(await Directory('${bundle.path}.new-v0.6.0').exists(), isFalse);
  });

  test('mark/read round-trip', () async {
    final bundle = await _tempBundle();
    addTearDown(() => bundle.parent.delete(recursive: true));
    const stagedPath = '/tmp/nowhere/tixun.new-v0.6.0';

    await markPendingUpdateFor(
      bundleDir: bundle,
      tag: 'v0.6.0',
      stagedPath: stagedPath,
    );

    final pending = readPendingUpdateFor(bundleDir: bundle);
    expect(pending, isNotNull);
    expect(pending!.tag, 'v0.6.0');
    expect(pending.stagedPath, stagedPath);
    // Marker lives next to the bundle dir, not inside it.
    expect(await File('${bundle.path}.pending.json').exists(), isTrue);
    expect(await File(p.join(bundle.path, '.pending.json')).exists(), isFalse);
  });

  test(
    'readPendingUpdate with a corrupt marker returns null and deletes it',
    () async {
      final bundle = await _tempBundle();
      addTearDown(() => bundle.parent.delete(recursive: true));
      final marker = File('${bundle.path}.pending.json');
      await marker.writeAsString('{not json');

      expect(readPendingUpdateFor(bundleDir: bundle), isNull);
      expect(await marker.exists(), isFalse);
    },
  );

  test('readPendingUpdate returns null when no marker exists', () async {
    final bundle = await _tempBundle();
    addTearDown(() => bundle.parent.delete(recursive: true));
    expect(readPendingUpdateFor(bundleDir: bundle), isNull);
  });

  test('discardPendingUpdate removes marker + staging', () async {
    final bundle = await _tempBundle();
    addTearDown(() => bundle.parent.delete(recursive: true));
    final tarGz = File(p.join(bundle.parent.path, 'update.tar.gz'));
    await tarGz.writeAsBytes(_buildUpdateTarGz());
    final staging = await stageLinuxUpdateInto(
      bundleDir: bundle,
      tarGzFile: tarGz,
      tag: 'v0.6.0',
    );
    await markPendingUpdateFor(
      bundleDir: bundle,
      tag: 'v0.6.0',
      stagedPath: staging.path,
    );

    await discardPendingUpdateFor(bundleDir: bundle);

    expect(readPendingUpdateFor(bundleDir: bundle), isNull);
    expect(await staging.exists(), isFalse);
    // The real bundle is untouched.
    expect(
      await File(p.join(bundle.path, 'tixun')).readAsString(),
      'old binary',
    );
  });

  test('swap renames bundle to .old and staging to bundle', () async {
    final bundle = await _tempBundle();
    addTearDown(() => bundle.parent.delete(recursive: true));
    final staging = Directory('${bundle.path}.new-v0.6.0');
    await staging.create();
    await File(p.join(staging.path, 'tixun')).writeAsString('new binary');

    final ok = await swapBundleDirectories(
      bundleDir: bundle,
      stagingDir: staging,
    );

    expect(ok, isTrue);
    expect(
      await File(p.join(bundle.path, 'tixun')).readAsString(),
      'new binary',
    );
    expect(await Directory('${bundle.path}.old').exists(), isTrue);
    expect(
      await File(p.join('${bundle.path}.old', 'tixun')).readAsString(),
      'old binary',
    );
    expect(await staging.exists(), isFalse);
  });

  test(
    'swap deletes a previous .old and fails cleanly without staging',
    () async {
      final bundle = await _tempBundle();
      addTearDown(() => bundle.parent.delete(recursive: true));
      final staleOld = Directory('${bundle.path}.old');
      await staleOld.create();
      await File(p.join(staleOld.path, 'stale.txt')).writeAsString('stale');
      final missingStaging = Directory('${bundle.path}.new-v0.6.0');

      final ok = await swapBundleDirectories(
        bundleDir: bundle,
        stagingDir: missingStaging,
      );

      expect(ok, isFalse);
      // Bundle untouched, stale .old left alone (nothing was swapped).
      expect(
        await File(p.join(bundle.path, 'tixun')).readAsString(),
        'old binary',
      );
      expect(await staleOld.exists(), isTrue);
    },
  );

  test('swap restores .old when the bundle dir is missing instead of deleting the only copy', () async {
    final bundle = await _tempBundle();
    addTearDown(() => bundle.parent.delete(recursive: true));
    final oldDir = Directory('${bundle.path}.old');
    await bundle.rename(oldDir.path);
    final staging = Directory('${bundle.path}.new-v0.6.0');
    await staging.create();
    await File(p.join(staging.path, 'tixun')).writeAsString('new binary');

    final ok = await swapBundleDirectories(
      bundleDir: bundle,
      stagingDir: staging,
    );

    expect(ok, isFalse);
    // The old bundle is back in place; the swap did not run.
    expect(
      await File(p.join(bundle.path, 'tixun')).readAsString(),
      'old binary',
    );
    expect(await oldDir.exists(), isFalse);
    expect(await staging.exists(), isTrue);
  });

  test(
    'swap restores .old when the bundle dir is missing and staging is gone too',
    () async {
      final bundle = await _tempBundle();
      addTearDown(() => bundle.parent.delete(recursive: true));
      final oldDir = Directory('${bundle.path}.old');
      await bundle.rename(oldDir.path);

      final ok = await swapBundleDirectories(
        bundleDir: bundle,
        stagingDir: Directory('${bundle.path}.new-v0.6.0'),
      );

      expect(ok, isFalse);
      expect(
        await File(p.join(bundle.path, 'tixun')).readAsString(),
        'old binary',
      );
      expect(await oldDir.exists(), isFalse);
    },
  );

  test(
    'stage rejects a symbolic link entry instead of making a directory',
    () async {
      final bundle = await _tempBundle();
      addTearDown(() => bundle.parent.delete(recursive: true));
      final archive = Archive();
      final binary = utf8.encode('#!/bin/sh\necho new\n');
      archive.addFile(ArchiveFile('tixun', binary.length, binary));
      archive.addFile(ArchiveFile('evil-link', 0, [])..symbolicLink = 'tixun');
      final tarGz = File(p.join(bundle.parent.path, 'update.tar.gz'));
      await tarGz.writeAsBytes(
        GZipEncoder().encode(TarEncoder().encode(archive)),
      );

      await expectLater(
        stageLinuxUpdateInto(
          bundleDir: bundle,
          tarGzFile: tarGz,
          tag: 'v0.6.0',
        ),
        throwsFormatException,
      );
      expect(await Directory('${bundle.path}.new-v0.6.0').exists(), isFalse);
    },
  );

  test(
    'stage rejects an archive over the size cap without reading it',
    () async {
      final bundle = await _tempBundle();
      addTearDown(() => bundle.parent.delete(recursive: true));
      final huge = File(p.join(bundle.parent.path, 'huge.tar.gz'));
      final handle = await huge.open(mode: FileMode.write);
      await handle.truncate(256 * 1024 * 1024 + 1);
      await handle.close();

      await expectLater(
        stageLinuxUpdateInto(bundleDir: bundle, tarGzFile: huge, tag: 'v0.6.0'),
        throwsFormatException,
      );
      expect(await Directory('${bundle.path}.new-v0.6.0').exists(), isFalse);
    },
  );

  test('cleanupOldBundle deletes .old only', () async {
    final bundle = await _tempBundle();
    addTearDown(() => bundle.parent.delete(recursive: true));
    final oldDir = Directory('${bundle.path}.old');
    await oldDir.create();
    await File(p.join(oldDir.path, 'tixun')).writeAsString('old binary');

    await cleanupOldBundleFor(bundleDir: bundle);

    expect(await oldDir.exists(), isFalse);
    expect(
      await File(p.join(bundle.path, 'tixun')).readAsString(),
      'old binary',
    );
    // No-op when there is no .old.
    await cleanupOldBundleFor(bundleDir: bundle);
  });
}
