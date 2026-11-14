import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/features/visual/visual_store.dart';

const _sceneV1 = '{"v":1,"kind":"plot2d","model":{"expression":"x^2-4"}}';
const _sceneV2 =
    '{"v":1,"kind":"plot2d","model":{"expression":"x^2-4"},"title":"二次函数"}';

Future<void> _seedMessage(
  AppDatabase db,
  String sessionId,
  String messageId,
) async {
  final now = DateTime.now();
  await db
      .into(db.chatSessions)
      .insert(
        ChatSessionsCompanion.insert(
          id: sessionId,
          title: '会话',
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await db
      .into(db.chatMessages)
      .insert(
        ChatMessagesCompanion.insert(
          id: messageId,
          sessionId: sessionId,
          role: 'assistant',
          content: '请看图',
          createdAt: now,
        ),
      );
}

Future<void> _seedQuestion(AppDatabase db, String questionId) async {
  await db
      .into(db.practiceQuestions)
      .insert(
        PracticeQuestionsCompanion.insert(
          id: questionId,
          kind: 'numeric',
          stem: '2+2',
          subject: '数学',
          origin: 'ai',
          createdAt: DateTime.now(),
        ),
      );
}

Future<void> _seedKnowledge(AppDatabase db, String knowledgeId) async {
  final now = DateTime.now();
  await db
      .into(db.knowledgeItems)
      .insert(
        KnowledgeItemsCompanion.insert(
          id: knowledgeId,
          title: '二次函数',
          content: '正文',
          subject: '数学',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

void main() {
  late AppDatabase db;
  late VisualStore store;

  setUp(() {
    db = AppDatabase.memory();
    store = VisualStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
  });

  test(
    'create stores the scene, revision 1 snapshot and message link',
    () async {
      await _seedMessage(db, 's', 'm');
      final id = await store.create(
        sceneJson: _sceneV1,
        messageId: 'm',
        title: '抛物线',
      );
      final scene = await store.get(id);
      expect(scene, isNotNull);
      expect(scene!.sceneJson, _sceneV1);
      expect(scene.title, '抛物线');
      expect(scene.dslVersion, 1);
      expect(scene.verificationStatus, 'unverified');
      expect(scene.revision, 1);
      expect(scene.source, 'ai');
      expect(scene.deleted, isFalse);
      final snapshots = await db.select(db.visualSceneRevisions).get();
      expect(snapshots, hasLength(1));
      expect(snapshots.single.visualId, id);
      expect(snapshots.single.revision, 1);
      expect(snapshots.single.sceneJson, _sceneV1);
      expect((await store.listByMessage('m')).map((s) => s.id), [id]);
    },
  );

  test('create applies defaults and rejects an empty scene', () async {
    await _seedMessage(db, 's', 'm');
    final id = await store.create(sceneJson: _sceneV1, messageId: 'm');
    final scene = (await store.get(id))!;
    expect(scene.title, isNull);
    expect(scene.source, 'ai');
    await expectLater(
      store.create(sceneJson: '   ', messageId: 'm'),
      throwsA(
        isA<AppFormatException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.errorVisualSceneJsonEmpty,
        ),
      ),
    );
  });

  test('create rejects an invalid scene and writes nothing', () async {
    await _seedMessage(db, 's', 'm');
    const invalid = '{"v":1,"kind":"plot2d","model":{"expression":"z^2"}}';
    await expectLater(
      store.create(sceneJson: invalid, messageId: 'm'),
      throwsA(
        isA<AppFormatException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.errorInvalidParameterType,
        ),
      ),
    );
    expect(await db.select(db.visualScenes).get(), isEmpty);
    expect(await db.select(db.visualSceneRevisions).get(), isEmpty);
    expect(await db.select(db.visualMessageLinks).get(), isEmpty);
  });

  test('create rejects malformed JSON', () async {
    await _seedMessage(db, 's', 'm');
    await expectLater(
      store.create(sceneJson: '{not json', messageId: 'm'),
      throwsA(
        isA<AppFormatException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.errorInvalidParameterType,
        ),
      ),
    );
    await expectLater(
      store.create(sceneJson: '[1, 2]', messageId: 'm'),
      throwsA(
        isA<AppFormatException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.errorInvalidParameterType,
        ),
      ),
    );
    expect(await db.select(db.visualScenes).get(), isEmpty);
  });

  test('revise rejects an invalid scene and keeps revision 1', () async {
    await _seedMessage(db, 's', 'm');
    final id = await store.create(sceneJson: _sceneV1, messageId: 'm');
    const invalid = '{"v":1,"kind":"plot2d","model":{"expression":"z^2"}}';
    await expectLater(
      store.revise(id, invalid),
      throwsA(
        isA<AppFormatException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.errorInvalidParameterType,
        ),
      ),
    );
    final row = (await store.get(id))!;
    expect(row.revision, 1);
    expect(row.sceneJson, _sceneV1);
    expect(await db.select(db.visualSceneRevisions).get(), hasLength(1));
  });

  test(
    'revise syncs title and verification status from the new scene',
    () async {
      await _seedMessage(db, 's', 'm');
      final id = await store.create(sceneJson: _sceneV1, messageId: 'm');
      final updated = await store.revise(id, _sceneV2);
      expect(updated.title, '二次函数');
      expect(updated.verificationStatus, 'verified');
      final row = (await store.get(id))!;
      expect(row.title, '二次函数');
      expect(row.verificationStatus, 'verified');
    },
  );

  test('get returns null for an unknown id', () async {
    expect(await store.get('nope'), isNull);
  });

  test('listByMessage only returns scenes linked to that message', () async {
    await _seedMessage(db, 's', 'm1');
    await _seedMessage(db, 's', 'm2');
    final first = await store.create(sceneJson: _sceneV1, messageId: 'm1');
    final second = await store.create(sceneJson: _sceneV2, messageId: 'm2');
    expect((await store.listByMessage('m1')).map((s) => s.id), [first]);
    expect((await store.listByMessage('m2')).map((s) => s.id), [second]);
    expect(await store.listByMessage('other'), isEmpty);
  });

  test('listByQuestion reads question links', () async {
    await _seedMessage(db, 's', 'm');
    await _seedQuestion(db, 'q');
    final id = await store.create(sceneJson: _sceneV1, messageId: 'm');
    await db
        .into(db.visualQuestionLinks)
        .insert(
          VisualQuestionLinksCompanion.insert(visualId: id, questionId: 'q'),
        );
    expect((await store.listByQuestion('q')).map((s) => s.id), [id]);
    expect(await store.listByQuestion('other'), isEmpty);
  });

  test(
    'listByStudy reads study links and requires exactly one owner',
    () async {
      await _seedMessage(db, 's', 'm');
      await _seedKnowledge(db, 'k');
      final id = await store.create(sceneJson: _sceneV1, messageId: 'm');
      await db
          .into(db.visualStudyLinks)
          .insert(
            VisualStudyLinksCompanion.insert(
              visualId: id,
              knowledgeId: const Value('k'),
            ),
          );
      expect((await store.listByStudy(knowledgeId: 'k')).map((s) => s.id), [
        id,
      ]);
      expect(await store.listByStudy(mistakeId: 'none'), isEmpty);
      await expectLater(
        store.listByStudy(),
        throwsA(
          isA<AppFormatException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.errorVisualStudyLinkNeedsOneOwner,
          ),
        ),
      );
      await expectLater(
        store.listByStudy(knowledgeId: 'k', mistakeId: 'x'),
        throwsA(
          isA<AppFormatException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.errorVisualStudyLinkNeedsOneOwner,
          ),
        ),
      );
    },
  );

  test(
    'snapshotForQuestion freezes the current JSON at a new revision',
    () async {
      await _seedMessage(db, 's', 'm');
      final id = await store.create(sceneJson: _sceneV1, messageId: 'm');
      final snap = await store.snapshotForQuestion(id);
      expect(snap.visualId, id);
      expect(snap.revision, 2);
      expect((await store.get(id))!.revision, 2);
      expect((await store.get(id))!.sceneJson, _sceneV1);
      final snapshots = await (db.select(
        db.visualSceneRevisions,
      )..orderBy([(r) => OrderingTerm.asc(r.revision)])).get();
      expect(snapshots.map((r) => r.revision), [1, 2]);
      expect(snapshots.map((r) => r.sceneJson), [_sceneV1, _sceneV1]);
    },
  );

  test(
    'revise bumps the revision and appends a snapshot of the new JSON',
    () async {
      await _seedMessage(db, 's', 'm');
      final id = await store.create(sceneJson: _sceneV1, messageId: 'm');
      await store.snapshotForQuestion(id);
      final updated = await store.revise(id, _sceneV2);
      expect(updated.id, id);
      expect(updated.sceneJson, _sceneV2);
      expect(updated.revision, 3);
      expect((await store.get(id))!.sceneJson, _sceneV2);
      final snapshots = await (db.select(
        db.visualSceneRevisions,
      )..orderBy([(r) => OrderingTerm.asc(r.revision)])).get();
      expect(snapshots.map((r) => r.revision), [1, 2, 3]);
      expect(snapshots.last.sceneJson, _sceneV2);
    },
  );

  test('linkToQuestion pins a revision and re-linking moves the pin', () async {
    await _seedMessage(db, 's', 'm');
    await _seedQuestion(db, 'q');
    final id = await store.create(sceneJson: _sceneV1, messageId: 'm');
    final snap = await store.snapshotForQuestion(id);
    await store.linkToQuestion(id, 'q', snap.revision);
    expect(await store.questionVisualLinks('q'), [(visualId: id, revision: 2)]);
    // Re-linking the same pair moves the pin instead of duplicating it.
    await store.linkToQuestion(id, 'q', 1);
    expect(await store.questionVisualLinks('q'), [(visualId: id, revision: 1)]);
    expect(await store.questionVisualLinks('other'), isEmpty);
  });

  test('linkToQuestion rejects bad revisions and unknown scenes', () async {
    await _seedMessage(db, 's', 'm');
    await _seedQuestion(db, 'q');
    final id = await store.create(sceneJson: _sceneV1, messageId: 'm');
    await expectLater(
      store.linkToQuestion(id, 'q', 0),
      throwsA(
        isA<AppFormatException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.errorInvalidParameterType,
        ),
      ),
    );
    await expectLater(
      store.linkToQuestion(id, 'q', 2),
      throwsA(
        isA<AppFormatException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.errorVisualSceneDoesNotExist,
        ),
      ),
    );
    await expectLater(
      store.linkToQuestion('nope', 'q', 1),
      throwsA(
        isA<AppFormatException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.errorVisualSceneDoesNotExist,
        ),
      ),
    );
  });

  test(
    'linkToStudy links exactly one owner and is visible in listByStudy',
    () async {
      await _seedMessage(db, 's', 'm');
      await _seedKnowledge(db, 'k');
      final id = await store.create(sceneJson: _sceneV1, messageId: 'm');
      await store.linkToStudy(id, knowledgeId: 'k');
      expect((await store.listByStudy(knowledgeId: 'k')).map((s) => s.id), [
        id,
      ]);
      await expectLater(
        store.linkToStudy(id),
        throwsA(
          isA<AppFormatException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.errorVisualStudyLinkNeedsOneOwner,
          ),
        ),
      );
      await expectLater(
        store.linkToStudy(id, knowledgeId: 'k', mistakeId: 'x'),
        throwsA(
          isA<AppFormatException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.errorVisualStudyLinkNeedsOneOwner,
          ),
        ),
      );
    },
  );

  test('a pinned question visual stays frozen after later edits', () async {
    await _seedMessage(db, 's', 'm');
    await _seedQuestion(db, 'q');
    final id = await store.create(sceneJson: _sceneV1, messageId: 'm');
    final snap = await store.snapshotForQuestion(id);
    await store.linkToQuestion(id, 'q', snap.revision);
    await store.revise(id, _sceneV2);
    expect((await store.get(id))!.sceneJson, _sceneV2);
    final links = await store.questionVisualLinks('q');
    expect(links.single.revision, 2);
    expect(
      await store.getRevisionSceneJson(id, links.single.revision),
      _sceneV1,
    );
  });

  test('revise and snapshot reject unknown ids and empty JSON', () async {
    await expectLater(
      store.revise('nope', _sceneV2),
      throwsA(
        isA<AppFormatException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.errorVisualSceneDoesNotExist,
        ),
      ),
    );
    await expectLater(
      store.snapshotForQuestion('nope'),
      throwsA(
        isA<AppFormatException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.errorVisualSceneDoesNotExist,
        ),
      ),
    );
    await _seedMessage(db, 's', 'm');
    final id = await store.create(sceneJson: _sceneV1, messageId: 'm');
    await expectLater(
      store.revise(id, ''),
      throwsA(
        isA<AppFormatException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.errorVisualSceneJsonEmpty,
        ),
      ),
    );
    expect((await store.get(id))!.revision, 1);
  });
}
