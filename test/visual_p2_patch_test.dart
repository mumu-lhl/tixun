import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/ai_types.dart';
import 'package:tixun/core/ai/visual_tool.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/features/visual/visual_store.dart';

/// P2 coverage for `update_visual` patch ops: malformed op shapes (the
/// executor answers `{'ok': false, ...}` and creates no revision) and
/// patch semantics (group nesting, `set_title` with an empty string).
/// The semantics tests pin the CURRENT behaviour of
/// [applyVisualPatchOps]; nothing here changes it.

Map<String, dynamic> _groupScene() => {
  'v': 1,
  'kind': 'geometry',
  'title': '分组图',
  'view': {
    'x': [-3, 3],
    'y': [-3, 3],
  },
  'elements': [
    {
      'id': 'p1',
      'type': 'point',
      'at': [0, 0],
    },
    {
      'id': 'g1',
      'type': 'group',
      'children': [
        {
          'id': 'p2',
          'type': 'point',
          'at': [1, 1],
        },
        {
          'id': 'g2',
          'type': 'group',
          'children': [
            {
              'id': 'p3',
              'type': 'point',
              'at': [2, 2],
            },
          ],
        },
      ],
    },
  ],
  'meta': {'alt': '分组'},
};

Map<String, dynamic> _plotScene() => {
  'v': 1,
  'kind': 'plot2d',
  'title': '二次函数',
  'model': {'expression': 'x^2-4'},
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

  group('applyVisualPatchOps semantics (current behaviour, pinned)', () {
    test('set_title with an empty string removes the title key', () {
      final patched = applyVisualPatchOps(_groupScene(), [
        {'op': 'set_title', 'title': ''},
      ]);
      expect(patched.containsKey('title'), isFalse);
      // The scene stays valid when alt is present: title is optional.
      expect(patched['meta'], {'alt': '分组'});
    });

    test('set_title with a non-empty string replaces the title', () {
      final patched = applyVisualPatchOps(_groupScene(), [
        {'op': 'set_title', 'title': '新标题'},
      ]);
      expect(patched['title'], '新标题');
    });

    test('replace_element on a group id replaces the whole group', () {
      final patched = applyVisualPatchOps(_groupScene(), [
        {
          'op': 'replace_element',
          'id': 'g1',
          'element': {
            'id': 'g1',
            'type': 'group',
            'children': [
              {
                'id': 'p9',
                'type': 'point',
                'at': [9, 9],
              },
            ],
          },
        },
      ]);
      final elements = patched['elements'] as List;
      expect(elements.length, 2);
      final group = elements[1] as Map;
      expect((group['children'] as List).single['id'], 'p9');
    });

    test('replace_element reaches a point nested two groups deep', () {
      final patched = applyVisualPatchOps(_groupScene(), [
        {
          'op': 'replace_element',
          'id': 'p3',
          'element': {
            'id': 'p3',
            'type': 'point',
            'at': [-2, -2],
          },
        },
      ]);
      final elements = patched['elements'] as List;
      final g1 = elements[1] as Map;
      final g2 = (g1['children'] as List)[1] as Map;
      expect((g2['children'] as List).single['at'], [-2, -2]);
    });

    test('remove_element removes a point nested two groups deep', () {
      final patched = applyVisualPatchOps(_groupScene(), [
        {'op': 'remove_element', 'id': 'p3'},
      ]);
      final elements = patched['elements'] as List;
      final g1 = elements[1] as Map;
      final g2 = (g1['children'] as List)[1] as Map;
      expect(g2['children'], isEmpty);
      // The untouched top-level point and the outer group survive.
      expect(elements.length, 2);
      expect((elements[0] as Map)['id'], 'p1');
    });

    test('add_element with an id colliding with a group child is rejected', () {
      expect(
        () => applyVisualPatchOps(_groupScene(), [
          {
            'op': 'add_element',
            'element': {
              'id': 'p2',
              'type': 'point',
              'at': [5, 5],
            },
          },
        ]),
        throwsA(
          isA<AppFormatException>().having(
            (e) => e.message,
            'message',
            contains('图元 id 已存在：p2'),
          ),
        ),
      );
    });

    test('add_element always appends at the top level', () {
      final patched = applyVisualPatchOps(_groupScene(), [
        {
          'op': 'add_element',
          'element': {
            'id': 'p4',
            'type': 'point',
            'at': [3, 3],
          },
        },
      ]);
      final elements = patched['elements'] as List;
      expect(elements.length, 3);
      expect((elements.last as Map)['id'], 'p4');
      // Groups are untouched: no element was inserted into g1.
      final g1 = elements[1] as Map;
      expect((g1['children'] as List).length, 2);
    });

    test('patching a scene without an elements key creates the list', () {
      final scene = {
        'v': 1,
        'kind': 'geometry',
        'meta': {'alt': '空'},
      };
      final patched = applyVisualPatchOps(scene, [
        {
          'op': 'add_element',
          'element': {
            'id': 'p1',
            'type': 'point',
            'at': [0, 0],
          },
        },
      ]);
      expect((patched['elements'] as List).single['id'], 'p1');
    });

    test('replace with a mismatched element id is rejected', () {
      expect(
        () => applyVisualPatchOps(_groupScene(), [
          {
            'op': 'replace_element',
            'id': 'p1',
            'element': {
              'id': 'p2',
              'type': 'point',
              'at': [0, 0],
            },
          },
        ]),
        throwsA(
          isA<AppFormatException>().having(
            (e) => e.message,
            'message',
            contains('替换的图元 id 与操作 id 不一致：p1'),
          ),
        ),
      );
    });

    test('replace/remove of an unknown id is rejected', () {
      expect(
        () => applyVisualPatchOps(_groupScene(), [
          {
            'op': 'replace_element',
            'id': 'nope',
            'element': {
              'id': 'nope',
              'type': 'point',
              'at': [0, 0],
            },
          },
        ]),
        throwsA(
          isA<AppFormatException>().having(
            (e) => e.message,
            'message',
            contains('找不到要替换的图元：nope'),
          ),
        ),
      );
      expect(
        () => applyVisualPatchOps(_groupScene(), [
          {'op': 'remove_element', 'id': 'nope'},
        ]),
        throwsA(
          isA<AppFormatException>().having(
            (e) => e.message,
            'message',
            contains('找不到要删除的图元：nope'),
          ),
        ),
      );
    });

    test('elements that is not a list is rejected', () {
      final scene = {
        'v': 1,
        'kind': 'geometry',
        'elements': {'id': 'p1'},
        'meta': {'alt': '坏'},
      };
      expect(
        () => applyVisualPatchOps(scene, [
          {'op': 'remove_element', 'id': 'p1'},
        ]),
        throwsA(
          isA<AppFormatException>().having(
            (e) => e.message,
            'message',
            contains('场景的 elements 必须是列表'),
          ),
        ),
      );
    });

    test('the input scene is not mutated', () {
      final scene = _groupScene();
      applyVisualPatchOps(scene, [
        {'op': 'set_title', 'title': '改过'},
      ]);
      expect(scene['title'], '分组图');
    });
  });

  group('executeUpdateVisualTool rejects malformed ops', () {
    late AppDatabase db;
    late VisualStore store;
    late String visualId;

    setUp(() async {
      db = AppDatabase.memory();
      store = VisualStore(db);
      await _seedMessage(db, 's', 'r1');
      visualId = await store.create(
        sceneJson: jsonEncode(_plotScene()),
        messageId: 'r1',
      );
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
    });

    Future<Map<String, dynamic>> runUpdate(
      String callId,
      Map<String, dynamic> args,
    ) => executeUpdateVisualTool(
      store,
      ToolCall(callId, 'update_visual', jsonEncode(args)),
      sessionId: 's',
      runId: 'r1',
      cancel: CancelToken(),
    );

    Future<void> expectRejected(
      Map<String, dynamic> args,
      String messagePart,
    ) async {
      final before = (await store.get(visualId))!.revision;
      final result = await runUpdate('bad-1', args);
      expect(result['ok'], isFalse);
      expect(result['error'], contains(messagePart));
      // A rejected patch creates no revision.
      expect((await store.get(visualId))!.revision, before);
    }

    test('ops that is not a list is rejected', () async {
      await expectRejected({
        'visual_id': visualId,
        'ops': {'op': 'remove_element', 'id': 'x'},
      }, '参数 ops 必须是非空列表');
    });

    test('an empty ops list is rejected', () async {
      await expectRejected({
        'visual_id': visualId,
        'ops': [],
      }, '参数 ops 必须是非空列表');
    });

    test('an op that is not an object is rejected', () async {
      await expectRejected({
        'visual_id': visualId,
        'ops': ['not-an-object'],
      }, '补丁操作必须是对象');
    });

    test('an op without an op field is rejected', () async {
      await expectRejected({
        'visual_id': visualId,
        'ops': [
          {'id': 'x'},
        ],
      }, '补丁操作缺少有效的 op');
    });

    test('replace_element without an element is rejected', () async {
      await expectRejected({
        'visual_id': visualId,
        'ops': [
          {'op': 'replace_element', 'id': 'x'},
        ],
      }, '补丁操作缺少有效的 element');
    });

    test('replace_element without an id is rejected', () async {
      await expectRejected({
        'visual_id': visualId,
        'ops': [
          {
            'op': 'replace_element',
            'element': {
              'id': 'x',
              'type': 'point',
              'at': [0, 0],
            },
          },
        ],
      }, '补丁操作缺少有效的 id');
    });

    test('set_title without a title is rejected', () async {
      await expectRejected({
        'visual_id': visualId,
        'ops': [
          {'op': 'set_title'},
        ],
      }, 'set_title 缺少有效的 title');
    });

    test('an unknown op is rejected', () async {
      await expectRejected({
        'visual_id': visualId,
        'ops': [
          {'op': 'explode', 'id': 'x'},
        ],
      }, '未知的图形补丁操作：explode');
    });

    test('scene and ops together are rejected', () async {
      await expectRejected({
        'visual_id': visualId,
        'scene': _plotScene(),
        'ops': [
          {'op': 'set_title', 'title': 'x'},
        ],
      }, '参数 scene 与 ops 只能二选一');
    });

    test('neither scene nor ops is rejected', () async {
      await expectRejected({'visual_id': visualId}, '缺少参数：scene 或 ops');
    });
  });
}
