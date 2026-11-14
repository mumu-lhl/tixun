import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/visual_tool.dart';
import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/chat/message_visuals.dart';
import 'package:tixun/features/visual/visual_card.dart';
import 'package:tixun/features/visual/visual_store.dart';

Map<String, dynamic> _plotArgs({
  Map<String, dynamic>? scene,
  String? title,
  String? alt,
}) {
  final args = <String, dynamic>{
    'scene':
        scene ??
        {
          'v': 1,
          'kind': 'plot2d',
          'title': '二次函数',
          'model': {'expression': 'x^2-4'},
          'view': {
            'x': [-3, 3],
            'y': [-5, 6],
          },
          'meta': {'alt': '抛物线 y=x^2-4 的图像'},
        },
  };
  if (title != null) args['title'] = title;
  if (alt != null) args['alt'] = alt;
  return args;
}

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

  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });

  test('visualToolSchema is strict', () {
    expect(visualToolSchema.name, 'create_visual');
    expect(visualToolSchema.parameters['additionalProperties'], isFalse);
    expect(
      (visualToolSchema.parameters['required'] as List),
      contains('scene'),
    );
    expect(
      (visualToolSchema.parameters['properties'] as Map).keys,
      containsAll(['scene', 'title', 'alt']),
    );
  });

  group('executeVisualTool', () {
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

    Future<Map<String, dynamic>> runTool(
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

    test('valid scene creates a scene and returns computed zeros', () async {
      await _seedMessage(db, 'session-1', 'run-1');
      final result = await runTool('call-1', _plotArgs());
      expect(result['ok'], isTrue);
      expect(result['visual_id'], isA<String>());
      expect((result['visual_id'] as String).isNotEmpty, isTrue);
      expect(result['verification'], 'verified');
      final zeros =
          (result['computed']['zeros'] as List)
              .map((v) => (v as num).toDouble())
              .toList()
            ..sort();
      expect(zeros, hasLength(2));
      expect(zeros[0], closeTo(-2, 1e-9));
      expect(zeros[1], closeTo(2, 1e-9));
      final rows = await db.select(db.visualScenes).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, result['visual_id']);
      expect(rows.single.title, '二次函数');
      expect(rows.single.verificationStatus, 'verified');
      final links = await db.select(db.visualMessageLinks).get();
      expect(links, hasLength(1));
      expect(links.single.messageId, 'run-1');
      final ops = await db.select(db.aiToolOperations).get();
      expect(ops, hasLength(1));
      expect(ops.single.name, 'create_visual');
      expect(ops.single.status, 'succeeded');
    });

    test('create reports quality issues without failing the scene', () async {
      await _seedMessage(db, 'session-1', 'run-1');
      final result = await runTool(
        'call-1',
        _plotArgs(
          scene: {
            'v': 1,
            'kind': 'geometry',
            'title': '点',
            'view': {
              'x': [-3, 3],
              'y': [-3, 3],
            },
            'elements': [
              {
                'id': 'p1',
                'type': 'point',
                'at': [5, 5],
                'label': 'P',
              },
            ],
            'meta': {'alt': '点'},
          },
        ),
      );
      expect(result['ok'], isTrue);
      expect(result['verification'], 'verified');
      final issues = result['quality_issues'] as List;
      expect(issues.map((i) => (i as Map)['code']), ['point_outside_view']);
      expect((issues.single as Map)['path'], 'p1');
      // A clean scene reports no quality_issues key at all.
      final clean = await runTool('call-2', _plotArgs());
      expect(clean['ok'], isTrue);
      expect(clean.containsKey('quality_issues'), isFalse);
    });

    test(
      'a visual created in a study-linked session links to the study item',
      () async {
        await _seedMessage(db, 'session-1', 'run-1');
        final now = DateTime.now();
        await db
            .into(db.knowledgeItems)
            .insert(
              KnowledgeItemsCompanion.insert(
                id: 'k',
                title: '二次函数',
                content: '正文',
                subject: '数学',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.studyChatLinks)
            .insert(
              StudyChatLinksCompanion.insert(
                id: 'l1',
                sessionId: 'session-1',
                knowledgeId: const Value('k'),
              ),
            );
        final result = await runTool('call-1', _plotArgs());
        expect(result['ok'], isTrue);
        final scenes = await store.listByStudy(knowledgeId: 'k');
        expect(scenes.map((s) => s.id), [result['visual_id']]);
        expect(scenes.single.source, 'ai');
      },
    );

    test('invalid expression returns ok:false and creates nothing', () async {
      await _seedMessage(db, 'session-1', 'run-1');
      final result = await runTool(
        'call-1',
        _plotArgs(
          scene: {
            'v': 1,
            'kind': 'plot2d',
            'model': {'expression': 'z^2'},
            'title': '坏表达式',
          },
        ),
      );
      expect(result['ok'], isFalse);
      expect(result['error'], isA<String>());
      expect((result['error'] as String).isNotEmpty, isTrue);
      expect(await db.select(db.visualScenes).get(), isEmpty);
      expect(await db.select(db.aiToolOperations).get(), isEmpty);
    });

    test('oversized arguments return ok:false', () async {
      await _seedMessage(db, 'session-1', 'run-1');
      final result = await runTool('call-1', _plotArgs(title: 'x' * 70000));
      expect(result['ok'], isFalse);
      expect(result['error'], contains('过长'));
      expect(await db.select(db.visualScenes).get(), isEmpty);
    });

    test(
      'replayed call returns the cached result without a duplicate',
      () async {
        await _seedMessage(db, 'session-1', 'run-1');
        final args = _plotArgs();
        final first = await runTool('call-1', args);
        expect(first['ok'], isTrue);
        final second = await runTool('call-1', args);
        expect(second['ok'], isTrue);
        expect(second['visual_id'], first['visual_id']);
        expect(await db.select(db.visualScenes).get(), hasLength(1));
        // Same call id with different arguments is an error, not a new scene.
        final conflict = await runTool('call-1', _plotArgs(title: '另一个标题'));
        expect(conflict['ok'], isFalse);
        expect(await db.select(db.visualScenes).get(), hasLength(1));
      },
    );

    test('tool title and alt fill gaps in the scene', () async {
      await _seedMessage(db, 'session-1', 'run-1');
      final result = await runTool(
        'call-1',
        _plotArgs(
          scene: {
            'v': 1,
            'kind': 'plot2d',
            'model': {'expression': 'x^2'},
          },
          title: '工具标题',
          alt: '工具说明',
        ),
      );
      expect(result['ok'], isTrue);
      final row = (await db.select(db.visualScenes).get()).single;
      expect(row.title, '工具标题');
      final stored = (jsonDecode(row.sceneJson) as Map).cast<String, dynamic>();
      expect(stored['title'], '工具标题');
      expect((stored['meta'] as Map)['alt'], '工具说明');
    });

    test('scene title wins over the tool title', () async {
      await _seedMessage(db, 'session-1', 'run-1');
      final result = await runTool('call-1', _plotArgs(title: '工具标题'));
      expect(result['ok'], isTrue);
      final row = (await db.select(db.visualScenes).get()).single;
      expect(row.title, '二次函数');
      final stored = (jsonDecode(row.sceneJson) as Map).cast<String, dynamic>();
      expect(stored['title'], '二次函数');
    });

    test('unknown tool argument is rejected', () async {
      await _seedMessage(db, 'session-1', 'run-1');
      final result = await runTool('call-1', {
        ..._plotArgs(),
        'surprise': true,
      });
      expect(result['ok'], isFalse);
      expect(await db.select(db.visualScenes).get(), isEmpty);
    });
  });

  group('applyVisualPatchOps', () {
    Map<String, dynamic> groupScene() => {
      'v': 1,
      'kind': 'geometry',
      'title': '分组',
      'elements': [
        {
          'id': 'g1',
          'type': 'group',
          'children': [
            {
              'id': 'p1',
              'type': 'point',
              'at': [0, 0],
            },
            {
              'id': 'g2',
              'type': 'group',
              'children': [
                {
                  'id': 'p4',
                  'type': 'point',
                  'at': [3, 3],
                },
              ],
            },
          ],
        },
        {
          'id': 'p3',
          'type': 'point',
          'at': [2, 2],
        },
      ],
      'meta': {'alt': '分组场景'},
    };

    test('replace_element reaches a point inside a group', () {
      final patched = applyVisualPatchOps(groupScene(), [
        {
          'op': 'replace_element',
          'id': 'p1',
          'element': {
            'id': 'p1',
            'type': 'point',
            'at': [1, 1],
          },
        },
      ]);
      final elements = patched['elements'] as List;
      final g1 = elements[0] as Map;
      expect(((g1['children'] as List)[0] as Map)['at'], [1, 1]);
      // The rest of the scene is untouched.
      expect(((g1['children'] as List)[1] as Map)['id'], 'g2');
      expect((elements[1] as Map)['id'], 'p3');
      expect((elements[1] as Map)['at'], [2, 2]);
    });

    test('replace_element reaches a point in a nested group', () {
      final patched = applyVisualPatchOps(groupScene(), [
        {
          'op': 'replace_element',
          'id': 'p4',
          'element': {
            'id': 'p4',
            'type': 'point',
            'at': [4, 4],
          },
        },
      ]);
      final g1 = (patched['elements'] as List)[0] as Map;
      final g2 = (g1['children'] as List)[1] as Map;
      expect(((g2['children'] as List)[0] as Map)['at'], [4, 4]);
      expect(((g1['children'] as List)[0] as Map)['at'], [0, 0]);
    });

    test('remove_element removes a point inside a group', () {
      final patched = applyVisualPatchOps(groupScene(), [
        {'op': 'remove_element', 'id': 'p1'},
      ]);
      final g1 = (patched['elements'] as List)[0] as Map;
      expect((g1['children'] as List).map((e) => (e as Map)['id']).toList(), [
        'g2',
      ]);
      expect((patched['elements'] as List).length, 2);
    });

    test('remove_element of a nested-group point keeps its siblings', () {
      final patched = applyVisualPatchOps(groupScene(), [
        {'op': 'remove_element', 'id': 'p4'},
      ]);
      final g1 = (patched['elements'] as List)[0] as Map;
      final g2 = (g1['children'] as List)[1] as Map;
      expect(g2['children'], isEmpty);
      expect(((g1['children'] as List)[0] as Map)['id'], 'p1');
    });

    test('add_element rejects an id that exists inside a group', () {
      expect(
        () => applyVisualPatchOps(groupScene(), [
          {
            'op': 'add_element',
            'element': {
              'id': 'p1',
              'type': 'point',
              'at': [9, 9],
            },
          },
        ]),
        throwsA(
          isA<AppFormatException>()
              .having(
                (e) => e.code,
                'code',
                AppErrorCode.errorInvalidParameterType,
              )
              .having((e) => e.message, 'message', contains('图元 id 已存在'))
              .having((e) => e.arguments, 'arguments', ['id']),
        ),
      );
    });

    test('replace_element of a group id still replaces the group itself', () {
      final patched = applyVisualPatchOps(groupScene(), [
        {
          'op': 'replace_element',
          'id': 'g1',
          'element': {
            'id': 'g1',
            'type': 'group',
            'children': [
              {
                'id': 'p1',
                'type': 'point',
                'at': [7, 7],
              },
            ],
          },
        },
      ]);
      final g1 = (patched['elements'] as List)[0] as Map;
      expect(((g1['children'] as List)[0] as Map)['at'], [7, 7]);
    });
  });

  group('MessageVisuals', () {
    testWidgets('renders a card for a linked scene, nothing without one', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      late Directory root;
      late AppController c;
      late ProviderContainer scope;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('tixun-visual-tool');
        c = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          MockChatProvider(),
        );
        await c.initialize();
        await _seedMessage(c.db, 'session-1', 'msg-1');
        await c.visual.create(
          sceneJson: jsonEncode(_plotArgs()['scene']),
          messageId: 'msg-1',
          title: '二次函数',
        );
        scope = ProviderContainer(
          overrides: [appControllerProvider.overrideWith((ref) => c)],
        );
      });
      addTearDown(() async {
        await tester.runAsync(() async {
          scope.dispose();
          await c.shutdown();
          await root.delete(recursive: true);
        });
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: const MaterialApp(
            home: Scaffold(body: MessageVisuals('msg-1')),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VisualCard), findsOneWidget);
      expect(find.text('二次函数'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: const MaterialApp(
            home: Scaffold(body: MessageVisuals('msg-none')),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VisualCard), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Mock create_visual flow', () {
    test('asking to draw a figure creates a scene via the mock', () async {
      final root = await Directory.systemTemp.createTemp('tixun-visual-mock');
      final c = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
      );
      addTearDown(() async {
        await c.shutdown();
        await root.delete(recursive: true);
      });
      await c.initialize();
      await c.newSession();
      // Pin the prompt language so the run's closing text is deterministic
      // (the test host locale decides the default otherwise).
      c.prompts = c.prompts.withLanguage('zh');
      await c.send('请画图，画出 y = x^2 的函数图');
      expect(c.messages.last.status, 'complete');
      expect(c.messages.last.content, '已生成图形，可在下方查看。');
      final scenes = await c.db.select(c.db.visualScenes).get();
      expect(scenes, hasLength(1));
      expect(scenes.single.title, 'y = x²');
      final links = await c.db.select(c.db.visualMessageLinks).get();
      expect(links, hasLength(1));
      expect(links.single.messageId, c.messages.last.id);
      final op = (await c.db.select(c.db.aiToolOperations).get()).single;
      expect(op.name, 'create_visual');
      expect(op.status, 'succeeded');
      final result = jsonDecode(op.result!) as Map;
      expect(result['verification'], 'verified');
      expect(await c.visual.listByMessage(c.messages.last.id), hasLength(1));
    });
  });
}
