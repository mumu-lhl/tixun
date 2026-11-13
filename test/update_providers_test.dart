import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/update/update_models.dart';
import 'package:tixun/features/update/update_providers.dart';
import 'package:tixun/features/update/update_service.dart';

const _releaseV060 = ReleaseInfo(
  tag: 'v0.6.0',
  name: 'v0.6.0',
  prerelease: false,
  draft: false,
  assets: [],
);
const _releaseV070 = ReleaseInfo(
  tag: 'v0.7.0',
  name: 'v0.7.0',
  prerelease: false,
  draft: false,
  assets: [],
);

/// A stubbed update service: no network, deterministic outcomes.
class _FakeUpdateService extends UpdateService {
  UpdateCheckOutcome? checkOutcome;
  String? expectedSha;
  bool verifyResult = true;
  String? downloadedPath;
  bool verifyCalled = false;

  @override
  Future<UpdateCheckOutcome> check(
    UpdateChannel channel, {
    required String currentVersion,
    required String embeddedNightlyTag,
  }) async =>
      checkOutcome ??
      const UpdateCheckOutcome(
        kind: UpdateCheckKind.failed,
        message: UpdateMessage.checkFailed,
      );

  @override
  Future<File> downloadAsset({
    required ReleaseInfo release,
    required String assetName,
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    downloadedPath = savePath;
    final file = File(savePath);
    await file.create(recursive: true);
    await file.writeAsString('fake-update-bytes');
    return file;
  }

  @override
  Future<String?> fetchExpectedSha256(
    ReleaseInfo release,
    String assetName,
  ) async => expectedSha;

  @override
  Future<bool> verifySha256(File file, String expectedHash) async {
    verifyCalled = true;
    return verifyResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late _FakeUpdateService service;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tixun-update-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          (call) async {
            if (call.method == 'getAll') {
              return <String, dynamic>{
                'appName': 'TiXun',
                'packageName': 'dev.tixun',
                'version': '0.5.2',
                'buildNumber': '7',
                'buildSignature': '',
              };
            }
            return null;
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async {
            if (call.method == 'getTemporaryDirectory') return tempDir.path;
            return null;
          },
        );
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await tempDir.delete(recursive: true);
  });

  Future<ProviderContainer> makeContainer() async {
    final dir = await Directory.systemTemp.createTemp('tixun-update-ctrl');
    final c = AppController(
      AppDatabase.memory(),
      AttachmentStore(dir),
      MemoryKeyStore(),
      MockChatProvider(),
    );
    await c.initialize();
    service = _FakeUpdateService();
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith((ref) => c),
        updateServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await c.db.close();
      await dir.delete(recursive: true);
    });
    return container;
  }

  Future<void> checkAvailable(ProviderContainer container) async {
    service.checkOutcome = const UpdateCheckOutcome(
      kind: UpdateCheckKind.available,
      release: _releaseV060,
    );
    await container
        .read(updateStatusProvider.notifier)
        .checkForUpdate(manual: true);
    expect(container.read(updateStatusProvider).status, UpdateStatus.available);
  }

  test(
    'a missing checksum keeps the download instead of deleting it',
    () async {
      final container = await makeContainer();
      await checkAvailable(container);
      service.expectedSha = null;

      await container.read(updateStatusProvider.notifier).downloadAndPrepare();

      final state = container.read(updateStatusProvider);
      expect(state.status, UpdateStatus.failed);
      expect(state.message, UpdateMessage.checksumUnavailable);
      expect(service.verifyCalled, isFalse);
      expect(service.downloadedPath, isNotNull);
      expect(await File(service.downloadedPath!).exists(), isTrue);
      await File(service.downloadedPath!).delete();
    },
  );

  test('a real hash mismatch deletes the download', () async {
    final container = await makeContainer();
    await checkAvailable(container);
    service.expectedSha = 'deadbeef';
    service.verifyResult = false;

    await container.read(updateStatusProvider.notifier).downloadAndPrepare();

    final state = container.read(updateStatusProvider);
    expect(state.status, UpdateStatus.failed);
    expect(state.message, UpdateMessage.checksumFailed);
    expect(service.verifyCalled, isTrue);
    expect(service.downloadedPath, isNotNull);
    expect(await File(service.downloadedPath!).exists(), isFalse);
  });

  test('a re-check for the same release keeps a ready APK', () async {
    final container = await makeContainer();
    final apk = File('${tempDir.path}/kept.apk');
    await apk.writeAsString('already-downloaded');
    final notifier = container.read(updateStatusProvider.notifier);
    notifier.state = UpdateState(
      status: UpdateStatus.available,
      release: _releaseV060,
      readyToInstall: true,
      apkPath: apk.path,
    );
    service.checkOutcome = const UpdateCheckOutcome(
      kind: UpdateCheckKind.upToDate,
      release: _releaseV060,
    );

    await notifier.checkForUpdate(manual: true);

    final state = container.read(updateStatusProvider);
    expect(state.status, UpdateStatus.upToDate);
    expect(state.readyToInstall, isTrue);
    expect(state.apkPath, apk.path);
  });

  test('a re-check for a different release drops the ready APK', () async {
    final container = await makeContainer();
    final apk = File('${tempDir.path}/stale.apk');
    await apk.writeAsString('already-downloaded');
    final notifier = container.read(updateStatusProvider.notifier);
    notifier.state = UpdateState(
      status: UpdateStatus.available,
      release: _releaseV060,
      readyToInstall: true,
      apkPath: apk.path,
    );
    service.checkOutcome = const UpdateCheckOutcome(
      kind: UpdateCheckKind.available,
      release: _releaseV070,
    );

    await notifier.checkForUpdate(manual: true);

    final state = container.read(updateStatusProvider);
    expect(state.status, UpdateStatus.available);
    expect(state.release?.tag, 'v0.7.0');
    expect(state.readyToInstall, isFalse);
    expect(state.apkPath, isNull);
    // The file itself is left alone; only the ready state is dropped.
    expect(await apk.exists(), isTrue);
  });

  test('a re-check drops the ready APK when the cached file is gone', () async {
    final container = await makeContainer();
    final notifier = container.read(updateStatusProvider.notifier);
    notifier.state = UpdateState(
      status: UpdateStatus.available,
      release: _releaseV060,
      readyToInstall: true,
      apkPath: '${tempDir.path}/no-longer-there.apk',
    );
    service.checkOutcome = const UpdateCheckOutcome(
      kind: UpdateCheckKind.upToDate,
      release: _releaseV060,
    );

    await notifier.checkForUpdate(manual: true);

    final state = container.read(updateStatusProvider);
    expect(state.readyToInstall, isFalse);
    expect(state.apkPath, isNull);
  });

  test(
    'the saved channel is loaded before an automatic check can use it',
    () async {
      final dir = await Directory.systemTemp.createTemp('tixun-channel');
      final c = AppController(
        AppDatabase.memory(),
        AttachmentStore(dir),
        MemoryKeyStore(),
        MockChatProvider(),
      );
      await c.initialize();
      await c.db.setPreference('update_channel', 'nightly');
      final container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      addTearDown(() async {
        container.dispose();
        await c.db.close();
        await dir.delete(recursive: true);
      });

      final notifier = container.read(updateChannelProvider.notifier);
      await notifier.loadCompleted;

      expect(container.read(updateChannelProvider), UpdateChannel.nightly);
    },
  );
}
