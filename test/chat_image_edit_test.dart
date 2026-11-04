import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/image_editor.dart';
import 'package:tixun/features/library/study_store.dart';

class CapturingImageProvider implements ChatProvider {
  Map<String, dynamic>? request;
  @override
  Stream<AiChunk> complete(
    ProviderConfig config,
    String key,
    Map<String, dynamic> body,
    CancelToken cancel,
  ) async* {
    request = body;
    yield const AiChunk(text: '已收到当前编辑图片。', finish: 'stop');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Draft cropping preserves original, sends only edited bytes and keeps both in a saved mistake', () async {
    final root = await Directory.systemTemp.createTemp('tixun-chat-image');
    final provider = CapturingImageProvider();
    final c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      provider,
    );
    addTearDown(() async {
      await c.shutdown();
      await root.delete(recursive: true);
    });
    await c.initialize();
    await c.newSession();
    await c.addImage('assets/demo/two_problems.png');
    final original = c.attachments.single;
    final codec = await ui.instantiateImageCodec(
      await c.files.resolve(original.relativePath).readAsBytes(),
    );
    final frame = await codec.getNextFrame();
    final crop = await renderStudyCrop(
      frame.image,
      const ui.Rect.fromLTRB(0, .1, 1, .46),
      0,
    );
    frame.image.dispose();
    codec.dispose();
    await c.replaceDraftImage(original, crop);
    final edited = c.attachments.single;
    expect(edited.originalPath, original.relativePath);
    expect(edited.relativePath, isNot(original.relativePath));
    expect(await c.files.resolve(original.relativePath).exists(), true);
    await c.send('只分析裁剪后的题目');
    final content =
        (provider.request!['messages'] as List).last['content'] as List;
    expect(content.where((v) => v['type'] == 'image_url').length, 1);
    expect(
      content.last['image_url']['url'],
      'data:image/png;base64,${base64Encode(crop)}',
    );
    final question = (await c.db.images(c.selected!.id)).single;
    final mistake = await c.study.saveMistake(
      const MistakeDraft(title: '来自裁剪图片的错题'),
    );
    await c.study.copyChatImage(mistake.id, question, isMistake: true);
    final refs = await c.study.images(mistake.id, isMistake: true);
    expect(refs.length, 2);
    expect(
      c.study.preferredImages(refs).single.relativePath,
      edited.relativePath,
    );
    await expectLater(
      c.replaceDraftImage(question, crop),
      throwsFormatException,
      reason: 'Sent history cannot be edited in place',
    );
    final session = c.selected!;
    await expectLater(c.purgeSession(session.id), throwsFormatException);
    await c.deleteSession(session);
    expect(await c.purgeSession(session.id), 0);
    expect(await c.db.messages(session.id), isEmpty);
    expect(
      await c.files.resolve(edited.relativePath).exists(),
      true,
      reason: 'Saved mistake still references both images',
    );
    expect(await c.files.resolve(original.relativePath).exists(), true);
    expect((await c.study.mistake(mistake.id)).title, '来自裁剪图片的错题');
    expect(await c.db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    await c.newSession();
    await c.addImage('assets/demo/two_problems.png');
    final draftOnly = c.attachments.single;
    await c.replaceDraftImage(draftOnly, crop);
    final editedOnly = c.attachments.single;
    await c.removeImage(editedOnly);
    expect(await c.files.resolve(editedOnly.relativePath).exists(), false);
    expect(await c.files.resolve(draftOnly.relativePath).exists(), false);
    expect(await c.files.resolve(edited.relativePath).exists(), true);
  });
}
