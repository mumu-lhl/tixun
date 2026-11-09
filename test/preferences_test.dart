import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

/// A key store whose writes can be made to fail, simulating the OS
/// key store being unavailable mid-save.
class _FailingKeyStore extends MemoryKeyStore {
  bool failWrites = false;
  @override
  Future<void> write(String provider, String key) async {
    if (failWrites) throw StateError('key store unavailable');
    await super.write(provider, key);
  }
}

const _chatGptConfig = ProviderConfig(
  id: 1,
  kind: 'chatgpt',
  baseUrl: 'https://api.openai.com/v1',
  model: 'gpt-5',
  vision: false,
  thinking: false,
  supportsThinking: true,
  supportsTools: true,
  effort: 'high',
);

Future<AppController> _open(KeyStore keys) async {
  final dir = await Directory.systemTemp.createTemp('tixun-prefs-test');
  final c = AppController(
    AppDatabase.memory(),
    AttachmentStore(dir),
    keys,
    MockChatProvider(),
  );
  await c.initialize();
  return c;
}

void main() {
  test('saveSettings persists config before rotating the key', () async {
    final keys = MemoryKeyStore();
    final c = await _open(keys);
    addTearDown(() async {
      await c.db.close();
      await c.files.root.delete(recursive: true);
    });
    final next = c.config.copyWith(model: 'deepseek-v4-pro', vision: false);

    await c.saveSettings(next, 'new-key');

    expect((await c.db.config()).model, 'deepseek-v4-pro');
    expect(await keys.read(providerKeyId(next)), 'new-key');
    expect(c.config.model, 'deepseek-v4-pro');
  });

  test('a failed key write leaves config and key exactly as before', () async {
    final keys = _FailingKeyStore();
    final c = await _open(keys);
    addTearDown(() async {
      await c.db.close();
      await c.files.root.delete(recursive: true);
    });
    final original = c.config;
    await keys.write(providerKeyId(original), 'old-key');
    keys.failWrites = true;
    final next = original.copyWith(model: 'deepseek-v4-pro', vision: false);

    await expectLater(c.saveSettings(next, 'new-key'), throwsStateError);

    // The config was saved first but rolled back by the compensation;
    // the old key was never rotated away.
    expect((await c.db.config()).model, original.model);
    expect(c.config.model, original.model);
    expect(await keys.read(providerKeyId(original)), 'old-key');
  });

  test('restoreApiProvider consumes the saved previous provider', () async {
    final keys = MemoryKeyStore();
    final c = await _open(keys);
    addTearDown(() async {
      await c.db.close();
      await c.files.root.delete(recursive: true);
    });
    final original = c.config;

    await c.saveSettings(_chatGptConfig, null);
    expect(c.config.kind, 'chatgpt');
    expect(await c.db.preference('previous_api_provider'), isNot(isNull));

    await c.restoreApiProvider();
    expect(c.config.kind, original.kind);
    expect(c.config.model, original.model);
    expect(await c.db.preference('previous_api_provider'), isEmpty);

    // A second restore has nothing left to restore.
    await expectLater(c.restoreApiProvider(), throwsFormatException);
  });
}
