import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/backup/backup_service.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/a2ui/a2ui_catalog.dart';
import 'package:tixun/features/a2ui/a2ui_markdown.dart';
import 'package:tixun/features/a2ui/a2ui_store.dart';
import 'package:tixun/features/chat/chat_branch_store.dart';

import 'support/chat_a2ui.dart';

void main() {
  test('Official compiler validates a native catalog and rejects unsafe layouts', () {
    const id = 'my-instance';
    final snapshot = readChatA2ui(compileChatA2ui(expressForm, id), id);
    expect(snapshot.dataModel, {
      'word': 'pleasure',
      'score': 3,
      'flipped': false,
      'choices': [],
    });
    expect(
      snapshot.components!.map((c) => c['component']),
      containsAll(['FlipCard', 'TextField', 'Slider', 'Markdown', 'Button']),
    );
    expect(
      chatA2uiSkill,
      allOf(contains('FlipCard'), contains('VisualSceneRef')),
    );
    expect(chatA2uiSkill, isNot(contains('openUrl(')));

    for (final source in [
      'broken',
      'root = Image("https://example.com")',
      'root = Column([missing])',
      'root = Column([label, label])\nlabel = Text("Label")',
      'root = Button(label, action=Event("delete_record", {text: "delete"}))\nlabel = Text("Delete")',
      'root = Button(label, action=Event("copy_text", {secret: "bad"}))\nlabel = Text("Copy")',
      'root = Text("One")\nsurface("two")\nroot = Text("Two")',
      'root = Text("${'a' * 12000}")',
      'root = Column([c1])\n${[for (var i = 1; i < 9; i++) 'c$i = Column([c${i + 1}])'].join('\n')}\nc9 = Text("deep")',
    ]) {
      expect(
        () => compileChatA2ui(source, id),
        throwsException,
        reason: source.substring(0, source.length.clamp(0, 85)),
      );
    }
  });

  group('Chat controller', () {
    late AppController c;
    late A2uiTestProvider provider;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('tixun-a2ui');
      provider = A2uiTestProvider();
      c = AppController(
        AppDatabase.memory(),
        AttachmentStore(dir),
        MemoryKeyStore(),
        provider,
      );
      await c.initialize();
      await c.newSession();
    });

    tearDown(() async {
      await c.shutdown();
      await c.files.root.delete(recursive: true);
    });

    test('Lazy tools, deterministic mixed placements, failed call, dedup and scoped follow-up', () async {
      await c.send('Create native controls');
      final reply = c.messages.last;
      expect(reply.status, 'complete', reason: reply.error);
      expect(provider.requests, hasLength(3));
      expect(provider.requests.first.instructions, isNot(contains('FlipCard')));
      expect(provider.requests[1].instructions, contains('FlipCard'));
      for (final request in provider.requests) {
        expect(
          request.tools.map((tool) => tool.name),
          isNot(contains('get_a2ui')),
        );
        expect(
          request.tools.map((tool) => tool.name),
          isNot(contains('update_a2ui')),
        );
      }
      expect(provider.results[0], containsPair('inserted', true));
      expect(provider.results[1], containsPair('ok', false));
      expect(provider.results[2], containsPair('inserted', false));
      expect(provider.results[3], containsPair('inserted', true));
      final rows = await a2uiRows(c.db, reply.id);
      final first = provider.results[0]['surface_id'];
      final ref = provider.results[2]['surface_id'];
      final second = provider.results[3]['surface_id'];
      expect(rows, hasLength(3));
      final parts = chatA2uiMarkdown(
        reply.content,
        rows.reversed.toList(),
        interrupted: false,
      );
      expect(parts.map((p) => p.surfaceId), [null, first, second, null]);
      expect(parts.first.markdown, contains('Before the interface'));
      final tail = parts.last.markdown!;
      expect(tail, contains('After the interface'));
      expect(tail, contains('Final prose'));
      expect(tail, contains('![example](a2ui:$ref)'));
      expect(tail, contains('![form](a2ui:$ref)'));
      expect(tail, isNot(contains('duplicate')));
      expect(await c.db.select(c.db.practiceQuestions).get(), isEmpty);

      provider.results.clear();
      final previousRequests = provider.requests.length;
      await c.send('Update that interface');
      final followUp = provider.requests[previousRequests];
      expect(
        followUp.instructions,
        contains('Relevant saved interface metadata'),
      );
      expect(followUp.instructions, contains('FlipCard'));
      expect(followUp.instructions, isNot(contains(r'$/word')));
      expect(followUp.messages.every((m) => m.calls.isEmpty), isTrue);
    });

    test('An automatic insertion cannot activate a fenced reference', () async {
      await c.send('Create native controls');
      final rows = await a2uiRows(c.db, c.messages.last.id);
      final here = rows.firstWhere((row) => row.autoOffset != null);
      final reference = rows.singleWhere((row) => row.autoOffset == null);
      const opening = '```md\n';
      final body = '$opening![example](a2ui:${reference.id})\n```';
      final parts = chatA2uiMarkdown(
        body,
        [here.copyWith(autoOffset: Value(opening.length)), reference],
        interrupted: false,
        renderScheme: 'tixun-a2ui-inline',
      );
      expect(parts.map((part) => part.surfaceId), [null, here.id, null]);
      expect(parts.last.markdown, contains('![example](a2ui:${reference.id})'));
      expect(parts.last.markdown, isNot(contains('tixun-a2ui-inline')));
    });

    test('Committed automatic surfaces survive cancellation before the next text chunk', () async {
      provider.pauseAfterTools = true;
      final sending = c.send('Create interactive controls');
      await provider.arrived.future.timeout(const Duration(seconds: 10));
      final pending = c.messages.last;
      expect(pending.content, contains('Before'));
      expect(
        (await a2uiRows(c.db, pending.id)).where((s) => s.autoOffset != null),
        hasLength(2),
      );
      await c.stop();
      await sending;
      final reply = c.messages.last;
      expect(reply.status, 'stopped');
      final rows = await a2uiRows(c.db, reply.id);
      expect(
        chatA2uiMarkdown(
          reply.content,
          rows,
          interrupted: true,
        ).where((p) => p.surfaceId != null),
        hasLength(3),
      );

      provider.pauseAfterTools = false;
      provider.results.clear();
      await c.regenerate();
      final next = c.messages.last;
      expect(next.status, 'complete');
      expect(next.sessionId, isNot(reply.sessionId));
      final regenerated = (await a2uiRows(
        c.db,
        next.id,
      )).map((row) => row.id).toSet();
      expect(regenerated, hasLength(3));
      expect(
        regenerated.intersection(rows.map((row) => row.id).toSet()),
        isEmpty,
      );
      expect(await a2uiRows(c.db, reply.id), rows);
    });

    test(
      'An identical tool retry is idempotent and forks isolate editable state',
      () async {
        final sessionId = c.selected!.id;
        await c.db
            .into(c.db.chatMessages)
            .insert(
              ChatMessagesCompanion.insert(
                id: 'assistant',
                sessionId: sessionId,
                role: 'assistant',
                content: '',
                status: const Value('generating'),
                createdAt: DateTime.now(),
              ),
            );
        Future<ChatA2uiSurface> create(String body) => c.a2ui.create(
          sessionId: sessionId,
          messageId: 'assistant',
          callId: 'same-tool',
          express: expressForm,
          bodyAtInsertion: body,
          cancel: CancelToken(),
        );
        final row = await create('durable prefix');
        final repeat = await create('a later reply prefix');
        expect(repeat.id, row.id);
        expect(repeat.autoOffset, 'durable prefix'.length);
        final parent = (await c.db.messages(sessionId)).single;
        expect(parent.content, 'durable prefix');
        await c.db
            .update(c.db.chatMessages)
            .replace(parent.copyWith(status: 'complete'));
        await c.a2ui.saveState(row, '{"word":"before fork"}');
        await c.a2ui.recordAction(row, componentId: 'button', kind: 'ask_chat');
        final branch = await ChatBranchStore(
          c.db,
          c.practice,
          copySettings: (_, _) async {},
        ).fork(through: parent, title: 'Branch');
        final clone = (await a2uiRows(
          c.db,
          (await c.db.messages(branch.id)).single.id,
        )).single;
        expect(clone.id, row.id);
        expect(clone.sessionId, branch.id);
        expect(clone.stateJson, '{"word":"before fork"}');
        await c.a2ui.saveState(clone, '{"word":"branch change"}');
        expect(
          (await a2uiRows(c.db, parent.id)).single.stateJson,
          '{"word":"before fork"}',
        );
        expect(await c.db.select(c.db.chatA2uiActions).get(), hasLength(2));
        await (c.db.delete(
          c.db.chatSessions,
        )..where((s) => s.id.equals(branch.id))).go();
        expect(await c.db.select(c.db.chatA2uiActions).get(), hasLength(1));
        expect(await c.db.select(c.db.chatA2uiSurfaces).get(), hasLength(1));
      },
    );
  });

  test('Full backup restores compiled surface, offset and interaction state offline', () async {
    final root = await Directory.systemTemp.createTemp('tixun-a2ui-backup');
    addTearDown(() => root.delete(recursive: true));
    final db = AppDatabase.file(File('${root.path}/surface.sqlite'));

    final session = await db.createSession();
    await db
        .into(db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            id: 'saved',
            sessionId: session.id,
            role: 'assistant',
            content: 'prefix',
            status: const Value('generating'),
            createdAt: DateTime.now(),
          ),
        );
    final store = ChatA2uiStore(db);
    final row = await store.create(
      sessionId: session.id,
      messageId: 'saved',
      callId: 'call',
      express: expressForm,
      bodyAtInsertion: 'prefix',
      cancel: CancelToken(),
    );
    await store.saveState(row, '{"flipped":true}');
    await store.recordAction(row, componentId: 'button', kind: 'ask_chat');
    final backup = File('${root.path}/surface.tixun');
    final exported = await BackupService.export(
      db,
      AttachmentStore(root),
      backup,
    );
    await db.close();
    expect(exported.schema, AppDatabase.latestSchemaVersion);
    final prepared = await BackupService.prepare(
      backup,
      Directory('${root.path}/target'),
    );
    addTearDown(prepared.discard);
    final restored = AppDatabase.file(
      File('${prepared.data.path}/tixun.sqlite'),
    );
    addTearDown(restored.close);
    final restoredRow = (await a2uiRows(restored, 'saved')).single;
    expect(restoredRow.stateJson, '{"flipped":true}');
    expect(restoredRow.autoOffset, 6);
    expect(
      readChatA2ui(restoredRow.messagesJson, row.id).components,
      isNotEmpty,
    );
    expect(
      (await restored.select(restored.chatA2uiActions).get()).single.kind,
      'ask_chat',
    );
    expect((await restored.messages(session.id)).single.status, 'interrupted');
  });
}
