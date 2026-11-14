import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/ai_types.dart';
import 'package:tixun/core/ai/visual_tool.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/features/visual/visual_store.dart';

Map<String, dynamic> _plotScene({
  String expression = 'x^2-4',
  String title = '二次函数',
}) => {
  'v': 1,
  'kind': 'plot2d',
  'title': title,
  'model': {'expression': expression},
  'view': {
    'x': [-3, 3],
    'y': [-5, 6],
  },
  'meta': {'alt': '抛物线的图像'},
};

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('updateVisualToolSchema and getVisualToolSchema are strict', () {
    expect(updateVisualToolSchema.name, 'update_visual');
    expect(updateVisualToolSchema.parameters['additionalProperties'], isFalse);
    // scene OR ops: the executor enforces exactly one, so the schema
    // only requires the id.
    expect((updateVisualToolSchema.parameters['required'] as List), [
      'visual_id',
    ]);
    expect(
      (updateVisualToolSchema.parameters['properties'] as Map).keys,
      containsAll(['visual_id', 'scene', 'ops', 'title']),
    );
    expect(getVisualToolSchema.name, 'get_visual');
    expect(getVisualToolSchema.parameters['additionalProperties'], isFalse);
    expect(
      (getVisualToolSchema.parameters['required'] as List),
      contains('visual_id'),
    );
    expect(
      (getVisualToolSchema.parameters['properties'] as Map).keys,
      containsAll(['visual_id', 'revision']),
    );
  });

  group('executeUpdateVisualTool / executeGetVisualTool', () {
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

    Future<Map<String, dynamic>> runCreate(
      String callId,
      Map<String, dynamic> args, {
      String runId = 'run-1',
    }) => executeVisualTool(
      store,
      ToolCall(callId, 'create_visual', jsonEncode(args)),
      sessionId: 'session-1',
      runId: runId,
      cancel: CancelToken(),
    );

    Future<Map<String, dynamic>> runUpdate(
      String callId,
      Map<String, dynamic> args, {
      String runId = 'run-1',
    }) => executeUpdateVisualTool(
      store,
      ToolCall(callId, 'update_visual', jsonEncode(args)),
      sessionId: 'session-1',
      runId: runId,
      cancel: CancelToken(),
    );

    Future<Map<String, dynamic>> runGet(
      String callId,
      Map<String, dynamic> args, {
      String runId = 'run-1',
    }) => executeGetVisualTool(
      store,
      ToolCall(callId, 'get_visual', jsonEncode(args)),
      sessionId: 'session-1',
      runId: runId,
      cancel: CancelToken(),
    );

    Future<String> createScene() async {
      await _seedMessage(db, 'session-1', 'run-1');
      final created = await runCreate('call-create', {'scene': _plotScene()});
      expect(created['ok'], isTrue);
      return created['visual_id'] as String;
    }

    test(
      'update happy path bumps revision and keeps the old snapshot',
      () async {
        final id = await createScene();
        final updated = await runUpdate('call-update', {
          'visual_id': id,
          'scene': _plotScene(expression: 'x^2', title: '更新后的图'),
        });
        expect(updated['ok'], isTrue);
        expect(updated['visual_id'], id);
        expect(updated['revision'], 2);
        expect(updated['verification'], 'verified');
        final row = (await db.select(db.visualScenes).get()).single;
        expect(row.revision, 2);
        final stored = jsonDecode(row.sceneJson) as Map;
        expect((stored['model'] as Map)['expression'], 'x^2');
        expect(stored['title'], '更新后的图');
        // Revision 1 still holds the ORIGINAL scene JSON.
        final original = await store.getRevisionSceneJson(id, 1);
        expect(original, isNotNull);
        final originalScene = jsonDecode(original!) as Map;
        expect((originalScene['model'] as Map)['expression'], 'x^2-4');
        expect(originalScene['title'], '二次函数');
        final revised = await store.getRevisionSceneJson(id, 2);
        expect(revised, isNotNull);
        expect((jsonDecode(revised!) as Map)['title'], '更新后的图');
      },
    );

    test('update of an unknown id returns ok:false', () async {
      await _seedMessage(db, 'session-1', 'run-1');
      final result = await runUpdate('call-1', {
        'visual_id': 'no-such-id',
        'scene': _plotScene(),
      });
      expect(result['ok'], isFalse);
      expect(result['error'], contains('不存在'));
      expect(await db.select(db.visualScenes).get(), isEmpty);
      expect(await db.select(db.aiToolOperations).get(), isEmpty);
    });

    test(
      'update with an invalid scene returns ok:false and keeps revision 1',
      () async {
        final id = await createScene();
        final result = await runUpdate('call-1', {
          'visual_id': id,
          'scene': _plotScene(expression: 'z^2'),
        });
        expect(result['ok'], isFalse);
        expect(result['error'], isA<String>());
        final row = (await db.select(db.visualScenes).get()).single;
        expect(row.revision, 1);
        final stored = jsonDecode(row.sceneJson) as Map;
        expect((stored['model'] as Map)['expression'], 'x^2-4');
        expect(await db.select(db.visualSceneRevisions).get(), hasLength(1));
      },
    );

    Map<String, dynamic> geometryScene() => {
      'v': 1,
      'kind': 'geometry',
      'title': '三角形',
      'elements': [
        {
          'id': 'p1',
          'type': 'point',
          'at': [0, 0],
          'label': 'A',
        },
        {
          'id': 'p2',
          'type': 'point',
          'at': [3, 0],
          'label': 'B',
        },
      ],
      'meta': {'alt': '两个点'},
    };

    Future<String> createGeometryScene() async {
      await _seedMessage(db, 'session-1', 'run-1');
      final created = await runCreate('call-create', {
        'scene': geometryScene(),
      });
      expect(created['ok'], isTrue);
      return created['visual_id'] as String;
    }

    test('update with ops patches elements by id', () async {
      final id = await createGeometryScene();
      final updated = await runUpdate('call-patch', {
        'visual_id': id,
        'ops': [
          {
            'op': 'replace_element',
            'id': 'p1',
            'element': {
              'id': 'p1',
              'type': 'point',
              'at': [1, 1],
              'label': 'P',
            },
          },
          {
            'op': 'add_element',
            'element': {
              'id': 'p3',
              'type': 'point',
              'at': [2, 2],
            },
          },
          {'op': 'remove_element', 'id': 'p2'},
          {'op': 'set_title', 'title': '改过的标题'},
        ],
      });
      expect(updated['ok'], isTrue);
      expect(updated['visual_id'], id);
      expect(updated['revision'], 2);
      final scene = jsonDecode((await store.get(id))!.sceneJson) as Map;
      expect(scene['title'], '改过的标题');
      final elements = scene['elements'] as List;
      expect(elements.map((e) => (e as Map)['id']), ['p1', 'p3']);
      expect((elements[0] as Map)['at'], [1, 1]);
      // Revision 1 still holds the original two points.
      final original =
          jsonDecode((await store.getRevisionSceneJson(id, 1))!) as Map;
      expect((original['elements'] as List).map((e) => (e as Map)['id']), [
        'p1',
        'p2',
      ]);
      expect(original['title'], '三角形');
    });

    test('update with bad ops returns ok:false and keeps revision 1', () async {
      final id = await createGeometryScene();
      final badCalls = [
        {
          'visual_id': id,
          'ops': [
            {'op': 'explode'},
          ],
        },
        {
          'visual_id': id,
          'ops': [
            {
              'op': 'replace_element',
              'id': 'no-such',
              'element': {
                'id': 'no-such',
                'type': 'point',
                'at': [0, 0],
              },
            },
          ],
        },
        {
          'visual_id': id,
          'ops': [
            {
              'op': 'replace_element',
              'id': 'p1',
              'element': {
                'id': 'other',
                'type': 'point',
                'at': [0, 0],
              },
            },
          ],
        },
        {
          'visual_id': id,
          'ops': [
            {
              'op': 'add_element',
              'element': {
                'id': 'p1',
                'type': 'point',
                'at': [0, 0],
              },
            },
          ],
        },
        {
          'visual_id': id,
          'ops': [
            {'op': 'remove_element', 'id': 'no-such'},
          ],
        },
        {'visual_id': id, 'ops': []},
        {
          'visual_id': id,
          'scene': _plotScene(),
          'ops': [
            {'op': 'set_title', 'title': 'x'},
          ],
        },
        {'visual_id': id},
      ];
      for (var i = 0; i < badCalls.length; i++) {
        final result = await runUpdate('call-bad-$i', badCalls[i]);
        expect(result['ok'], isFalse, reason: 'call $i: $result');
        expect(result['error'], isA<String>());
      }
      final row = (await db.select(db.visualScenes).get()).single;
      expect(row.revision, 1);
      expect(await db.select(db.visualSceneRevisions).get(), hasLength(1));
    });

    test(
      'patch replay returns the cached result, no second revision',
      () async {
        final id = await createGeometryScene();
        final args = {
          'visual_id': id,
          'ops': [
            {'op': 'set_title', 'title': '补丁标题'},
          ],
        };
        final first = await runUpdate('call-patch', args);
        expect(first['ok'], isTrue);
        expect(first['revision'], 2);
        final replay = await runUpdate('call-patch', args);
        expect(replay['ok'], isTrue);
        expect(replay['revision'], 2);
        final row = (await db.select(db.visualScenes).get()).single;
        expect(row.revision, 2);
        expect(await db.select(db.visualSceneRevisions).get(), hasLength(2));
      },
    );

    test('get current returns the updated scene at revision 2', () async {
      final id = await createScene();
      await runUpdate('call-update', {
        'visual_id': id,
        'scene': _plotScene(expression: 'x^2', title: '更新后的图'),
      });
      final result = await runGet('call-get', {'visual_id': id});
      expect(result['ok'], isTrue);
      expect(result['visual_id'], id);
      expect(result['revision'], 2);
      expect(result['title'], '更新后的图');
      expect(result['verification_status'], 'verified');
      final scene = result['scene'] as Map;
      expect((scene['model'] as Map)['expression'], 'x^2');
      expect(scene['title'], '更新后的图');
    });

    test('get revision 1 returns the original scene', () async {
      final id = await createScene();
      await runUpdate('call-update', {
        'visual_id': id,
        'scene': _plotScene(expression: 'x^2', title: '更新后的图'),
      });
      final result = await runGet('call-get', {'visual_id': id, 'revision': 1});
      expect(result['ok'], isTrue);
      expect(result['revision'], 1);
      final scene = result['scene'] as Map;
      expect((scene['model'] as Map)['expression'], 'x^2-4');
      expect(scene['title'], '二次函数');
    });

    test('get of an unknown id returns ok:false', () async {
      await _seedMessage(db, 'session-1', 'run-1');
      final result = await runGet('call-1', {'visual_id': 'no-such-id'});
      expect(result['ok'], isFalse);
      expect(result['error'], contains('不存在'));
    });

    test('get of an unknown revision returns ok:false', () async {
      final id = await createScene();
      final result = await runGet('call-1', {'visual_id': id, 'revision': 99});
      expect(result['ok'], isFalse);
      expect(result['error'], contains('不存在'));
    });

    test('get writes no aiToolOperations row', () async {
      final id = await createScene();
      final result = await runGet('call-1', {'visual_id': id});
      expect(result['ok'], isTrue);
      // Only the create call left an operations row.
      final ops = await db.select(db.aiToolOperations).get();
      expect(ops, hasLength(1));
      expect(ops.single.name, 'create_visual');
    });

    test('replayed update bumps the revision exactly once', () async {
      final id = await createScene();
      final args = {
        'visual_id': id,
        'scene': _plotScene(expression: 'x^2', title: '更新后的图'),
      };
      final first = await runUpdate('call-update', args);
      expect(first['ok'], isTrue);
      expect(first['revision'], 2);
      final second = await runUpdate('call-update', args);
      expect(second['ok'], isTrue);
      expect(second['visual_id'], first['visual_id']);
      expect(second['revision'], 2);
      expect(await db.select(db.visualSceneRevisions).get(), hasLength(2));
      final row = (await db.select(db.visualScenes).get()).single;
      expect(row.revision, 2);
      // Same call id with different arguments is an error.
      final conflict = await runUpdate('call-update', {
        'visual_id': id,
        'scene': _plotScene(expression: 'x^2 + 1', title: '又改了'),
      });
      expect(conflict['ok'], isFalse);
      expect(await db.select(db.visualSceneRevisions).get(), hasLength(2));
    });

    test('getRevisionSceneJson returns null for a missing revision', () async {
      final id = await createScene();
      expect(await store.getRevisionSceneJson(id, 99), isNull);
      expect(await store.getRevisionSceneJson('no-such-id', 1), isNull);
    });
  });
}
