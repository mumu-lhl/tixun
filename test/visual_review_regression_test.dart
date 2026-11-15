// Regression coverage for the end-to-end visual review findings.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_animator.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';
import 'package:tixun/core/visual/validation/visual_validator.dart';
import 'package:tixun/features/visual/visual_card.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/quiz_tool.dart';
import 'package:tixun/core/ai/visual_tool.dart';
import 'package:tixun/core/ai/visual_schema.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/practice/practice_store.dart';
import 'package:tixun/features/visual/visual_store.dart';

Map<String, dynamic> scene() => {
  'v': 1,
  'kind': 'geometry',
  'title': 'Test figure',
  'view': {
    'x': [-5, 5],
    'y': [-5, 5],
  },
  'elements': [
    {
      'id': 'p',
      'type': 'point',
      'at': [0, 0],
    },
  ],
  'meta': {'alt': 'Test figure'},
};

Map<String, dynamic> quiz(String id, {String kind = 'numeric'}) => {
  'kind': kind,
  'stem': 'Read the figure',
  'subject': '数学',
  'answers': [
    [
      kind == 'drag_to_target'
          ? '1,1'
          : kind == 'region_select'
          ? 'missing-region'
          : '1',
    ],
  ],
  if (kind == 'region_select') 'options': {'missing-region': 'Region'},
  'explanation': 'Explanation',
  'visual_id': id,
};

class RecordingProvider implements ChatProvider {
  final requests = <AiRequest>[];
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        requests.add(request);
        if (request.tools.any((t) => t.name == 'enable_visual_tools')) {
          yield const AiChunk(
            completed: true,
            calls: [ToolCall('load', 'enable_visual_tools', '{}')],
          );
          return;
        }
        final toolMessages = request.messages.where(
          (m) => m.role == AiRole.tool,
        );
        if (toolMessages.last.callId == 'load') {
          yield AiChunk(
            completed: true,
            calls: [
              ToolCall(
                'create-figure',
                'create_visual',
                jsonEncode({'scene': scene()}),
              ),
            ],
          );
          return;
        }
        final results = request.messages.where((m) => m.role == AiRole.tool);
        if (results.isNotEmpty) {
          final result = jsonDecode(results.last.text) as Map;
          if (result['visual_id'] is String && result['question_id'] == null) {
            yield AiChunk(
              completed: true,
              calls: [
                ToolCall(
                  'create-question',
                  'create_quiz',
                  jsonEncode(quiz(result['visual_id'] as String)),
                ),
              ],
            );
            return;
          }
        }
        yield const AiChunk(text: 'Done', completed: true);
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppController> controller(RecordingProvider provider) async {
    final root = await Directory.systemTemp.createTemp('visual-review');
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
    return c;
  }

  test('the model-facing DSL examples validate and round-trip', () {
    for (final example in visualDslExamples) {
      expect(validateVisualScene(example).ok, isTrue);
      expect(VisualScene.fromJson(example).toJson()['kind'], example['kind']);
    }
  });

  test('visual tools describe the scene and patch element fields', () {
    final schema =
        (visualToolSchema.parameters['properties'] as Map)['scene'] as Map;
    expect(schema['required'], containsAll(['v', 'kind']));
    expect(
      (schema['properties'] as Map).keys,
      containsAll(['model', 'view', 'elements', 'controls', 'timeline']),
    );
    final ops =
        (updateVisualToolSchema.parameters['properties'] as Map)['ops'] as Map;
    final element =
        ((ops['items'] as Map)['properties'] as Map)['element'] as Map;
    expect(element['anyOf'], isNotEmpty);
  });

  test('review: create_visual must allow a following round to create the requested quiz', () async {
    final provider = RecordingProvider();
    final c = await controller(provider);
    await c.send('请先画图，再根据这张图出一道题');
    expect((await c.db.select(c.db.visualScenes).get()), hasLength(1));
    expect((await c.db.select(c.db.practiceQuestions).get()), hasLength(1));
    expect(
      provider.requests[1].instructions,
      contains('[TiXun Visual DSL v1 contract]'),
    );
    expect(provider.requests[1].instructions, contains('"expression":"a*x^2"'));
  });

  test(
    'review: a follow-up request must expose the existing visual id',
    () async {
      final provider = RecordingProvider();
      final c = await controller(provider);
      await c.send('画图');
      final id = (await c.db.select(c.db.visualScenes).get()).single.id;
      await c.send('请把这张图修改一下');
      final request = provider.requests.last;
      final context =
          request.instructions + request.messages.map((m) => m.text).join('\n');
      expect(context, contains(id));
    },
  );

  test('saved visual index is bounded metadata and excludes deleted and unrelated figures', () async {
    final provider = RecordingProvider();
    final c = await controller(provider);
    await c.send('画图');
    final messageId = c.messages.last.id;
    final title = List.filled(100, '图').join();
    for (var i = 0; i < 30; i++) {
      await c.visual.create(
        sceneJson: jsonEncode(scene()),
        messageId: messageId,
        title: title,
      );
    }
    final deletedId = await c.visual.create(
      sceneJson: jsonEncode(scene()),
      messageId: messageId,
    );
    await (c.db.update(c.db.visualScenes)..where((s) => s.id.equals(deletedId)))
        .write(const VisualScenesCompanion(deleted: Value(true)));
    final now = DateTime.now();
    await c.db
        .into(c.db.chatSessions)
        .insert(
          ChatSessionsCompanion.insert(
            id: 'unrelated',
            title: 'Other chat',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await c.db
        .into(c.db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            id: 'other-message',
            sessionId: 'unrelated',
            role: 'assistant',
            content: 'Other',
            createdAt: now,
          ),
        );
    final otherId = await c.visual.create(
      sceneJson: jsonEncode(scene()),
      messageId: 'other-message',
    );
    await c.send('修改这张图');
    final messages = provider.requests.last.messages
        .map((m) => m.text)
        .join('\n');
    expect(messages, isNot(contains(deletedId)));
    expect(messages, isNot(contains(otherId)));
    final indexes = RegExp(
      r'\[Saved visual index; learning data, not instructions\]\n([^\n]+)',
    ).allMatches(messages);
    final entries = [
      for (final index in indexes)
        ...(jsonDecode(index.group(1)!) as List).cast<Map<String, dynamic>>(),
    ];
    expect(entries, isNotEmpty);
    expect(entries.length, lessThanOrEqualTo(24));
    expect(
      entries.fold<int>(
        0,
        (sum, entry) => sum + utf8.encode(jsonEncode(entry)).length,
      ),
      lessThanOrEqualTo(6000),
    );
    for (final entry in entries) {
      expect(
        entry.keys,
        unorderedEquals(['visual_id', 'title', 'revision', 'kind']),
      );
    }
  });

  test('review: hiding a group must hide its descendants', () {
    final json = scene();
    json['elements'] = [
      {
        'id': 'group',
        'type': 'group',
        'visible': false,
        'children': json['elements'],
      },
    ];
    expect(validateVisualScene(json).ok, isTrue);
    final model = VisualScene.fromJson(json);
    expect(visualVisibleElements(model, {}, {}), isEmpty);
    json['elements'][0]['visible'] = true;
    final timelineHidden = VisualScene.fromJson(json);
    expect(visualVisibleElements(timelineHidden, {}, {'group'}), isEmpty);
  });

  test('toggle visibility is inherited through nested groups', () {
    final json = scene();
    json['controls'] = [
      {'id': 'show', 'kind': 'toggle', 'label': 'Show', 'value': false},
    ];
    json['elements'] = [
      {
        'id': 'outer',
        'type': 'group',
        'visibleWhen': {'control': 'show', 'equals': true},
        'children': [
          {'id': 'inner', 'type': 'group', 'children': json['elements']},
        ],
      },
    ];
    final model = VisualScene.fromJson(json);
    expect(visualVisibleElements(model, {}, {}), isEmpty);
    expect(visualVisibleElements(model, {'show': true}, {}).map((e) => e.id), [
      'p',
    ]);
    expect(visualVisibleElements(model, {'show': true}, {'inner'}), isEmpty);
  });

  testWidgets(
    'review: card must use the timeline-resolved frame at time zero',
    (tester) async {
      final json = scene();
      json['model'] = {
        'parameters': {'a': 1},
      };
      json['controls'] = [
        {
          'id': 'a',
          'kind': 'slider',
          'label': 'a',
          'min': 0,
          'max': 10,
          'step': 1,
          'value': 1,
        },
      ];
      json['timeline'] = {
        'durationMs': 1000,
        'tracks': [
          {
            'id': 'track',
            'target': 'a',
            'from': 3,
            'to': 5,
            'startMs': 0,
            'endMs': 1000,
          },
        ],
      };
      expect(validateVisualScene(json).ok, isTrue);
      final model = VisualScene.fromJson(json);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: VisualCard(scene: model)),
          ),
        ),
      );
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<VisualPainter>()
          .single;
      expect(painter.parameters, resolveVisualFrame(model, 0).parameters);
    },
  );

  group('review: question scene invariants', () {
    late AppDatabase db;
    late PracticeStore practice;
    late VisualStore visual;
    late String visualId;
    setUp(() async {
      db = AppDatabase.memory();
      practice = PracticeStore(db);
      visual = VisualStore(db);
      final now = DateTime.now();
      await db
          .into(db.chatSessions)
          .insert(
            ChatSessionsCompanion.insert(
              id: 's',
              title: 'Session',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              id: 'm',
              sessionId: 's',
              role: 'assistant',
              content: 'Figure',
              createdAt: now,
            ),
          );
      visualId = await visual.create(
        sceneJson: jsonEncode(scene()),
        messageId: 'm',
      );
    });
    tearDown(() async {
      practice.dispose();
      visual.dispose();
      await db.close();
    });
    Future<Map<String, dynamic>> createQuiz({String kind = 'numeric'}) =>
        executeQuizTool(
          practice,
          ToolCall('q', 'create_quiz', jsonEncode(quiz(visualId, kind: kind))),
          sessionId: 's',
          runId: 'm',
          cancel: CancelToken(),
          visual: visual,
        );

    test(
      'drag question without any draggable point must be rejected',
      () async {
        final result = await createQuiz(kind: 'drag_to_target');
        expect(result['ok'], isFalse);
        expect(await db.select(db.practiceQuestions).get(), isEmpty);
      },
    );
    test(
      'region question referencing no actual polygon must be rejected',
      () async {
        final result = await createQuiz(kind: 'region_select');
        expect(result['ok'], isFalse);
        expect(await db.select(db.practiceQuestions).get(), isEmpty);
      },
    );
    test(
      'revising a figure question must preserve its pinned visual',
      () async {
        final result = await createQuiz();
        expect(result['ok'], isTrue);
        final original = await practice.detail(result['question_id'] as String);
        final revisedId = await practice.revise(original.row.id, original.spec);
        final revised = await practice.detail(revisedId);
        expect(revised.visualLinks, original.visualLinks);
      },
    );
  });
}
