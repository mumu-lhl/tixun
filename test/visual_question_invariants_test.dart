import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/features/practice/practice_store.dart';
import 'package:tixun/features/practice/question_spec.dart';
import 'package:tixun/features/visual/visual_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late VisualStore visual;
  late PracticeStore practice;
  setUp(() async {
    db = AppDatabase.memory();
    visual = VisualStore(db);
    practice = PracticeStore(db, visual: visual);
    final now = DateTime.now();
    await db
        .into(db.chatSessions)
        .insert(
          ChatSessionsCompanion.insert(
            id: 's',
            title: 'Test',
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
  });
  tearDown(() async {
    practice.dispose();
    visual.dispose();
    await db.close();
  });

  Map<String, dynamic> point({bool draggable = true}) => {
    'id': 'p',
    'type': 'point',
    'at': [0, 0],
    'draggable': draggable,
  };
  Map<String, dynamic> polygon(String id, {double x = -1, double size = 2}) => {
    'id': id,
    'type': 'polygon',
    'fill': true,
    'points': [
      [x, -1],
      [x + size, -1],
      [x + size, -1 + size],
      [x, -1 + size],
    ],
  };
  Map<String, dynamic> scene(List<Map<String, dynamic>> elements) => {
    'v': 1,
    'kind': 'geometry',
    'view': {
      'x': [-5, 5],
      'y': [-5, 5],
    },
    'elements': elements,
    'meta': {'alt': 'Question fixture'},
  };
  Future<String> createVisual(Map<String, dynamic> json) =>
      visual.create(sceneJson: jsonEncode(json), messageId: 'm');
  QuestionSpec spec(
    String id, {
    String kind = 'drag_to_target',
    int? revision,
    String answer = '2,0',
    Map<String, String> options = const {},
  }) => QuestionSpec(
    kind: kind,
    stem: 'Interact',
    answers: [
      [answer],
    ],
    options: options,
    visualId: id,
    visualRevision: revision,
  );
  final notAnswerable = isA<AppFormatException>().having(
    (e) => e.code,
    'code',
    AppErrorCode.errorVisualQuestionNotAnswerable,
  );
  Future<void> rejectWithoutWrites(
    Map<String, dynamic> json, {
    String kind = 'drag_to_target',
    String answer = '2,0',
    Map<String, String> options = const {},
  }) async {
    final id = await createVisual(json);
    await expectLater(
      practice.create(spec(id, kind: kind, answer: answer, options: options)),
      throwsA(notAnswerable),
    );
    expect(await practice.list(), isEmpty);
    expect(await db.select(db.practiceOptions).get(), isEmpty);
    expect(await db.select(db.practiceAnswerKeys).get(), isEmpty);
    expect(await db.select(db.visualQuestionLinks).get(), isEmpty);
    expect((await visual.get(id))!.revision, 1);
    expect(await db.select(db.visualSceneRevisions).get(), hasLength(1));
  }

  test('direct Store creation owns and persists the visual pin', () async {
    final id = await createVisual(scene([point()]));
    final q = await practice.create(spec(id));
    final detail = await practice.detail(q);
    expect(detail.spec.visualId, id);
    expect(detail.spec.visualRevision, 2);
    expect(detail.visualLinks, hasLength(1));
    expect(detail.visualLinks.single.revision, 2);
    expect(await visual.getRevisionSceneJson(id, 2), isNotNull);
  });

  test('a text-only revision inherits its old snapshot, not the changed live scene', () async {
    final id = await createVisual(scene([point()]));
    final q = await practice.create(spec(id));
    final original = await practice.detail(q);
    final oldJson = await visual.getRevisionSceneJson(
      id,
      original.spec.visualRevision!,
    );
    final changed = scene([point()])
      ..['view'] = {
        'x': [100, 110],
        'y': [100, 110],
      };
    await visual.revise(id, jsonEncode(changed));
    final revised = await practice.revise(
      q,
      const QuestionSpec(
        kind: 'drag_to_target',
        stem: 'Edited',
        answers: [
          ['2,0'],
        ],
      ),
    );
    final detail = await practice.detail(revised);
    expect(detail.spec.visualRevision, original.spec.visualRevision);
    expect(detail.visualLinks, original.visualLinks);
    expect(
      await visual.getRevisionSceneJson(id, detail.spec.visualRevision!),
      oldJson,
    );
    expect((await visual.get(id))!.revision, 3);
  });

  test(
    'same operation replay reuses the pin even after the live scene changes',
    () async {
      final id = await createVisual(scene([point()]));
      final q = await practice.create(spec(id), operation: 'operation');
      final original = await practice.detail(q);
      await visual.revise(id, jsonEncode(scene([point(draggable: false)])));
      expect(await practice.create(spec(id), operation: 'operation'), q);
      expect(
        (await practice.detail(q)).spec.visualRevision,
        original.spec.visualRevision,
      );
      expect((await visual.get(id))!.revision, 3);
      expect(await practice.list(), hasLength(1));
    },
  );

  test(
    'same operation cannot silently substitute a different explicit pin',
    () async {
      final id = await createVisual(scene([point()]));
      await practice.create(spec(id), operation: 'operation');
      await visual.revise(id, jsonEncode(scene([point()])));
      await expectLater(
        practice.create(spec(id, revision: 3), operation: 'operation'),
        throwsA(isA<AppFormatException>()),
      );
      expect(await practice.list(), hasLength(1));
    },
  );

  test('an explicit older answerable snapshot is checked instead of the live scene', () async {
    final id = await createVisual(scene([point()]));
    await visual.revise(id, jsonEncode(scene([point(draggable: false)])));
    final q = await practice.create(spec(id, revision: 1));
    expect((await practice.detail(q)).spec.visualRevision, 1);
    expect((await visual.get(id))!.revision, 2);
  });

  test('drag points hidden by an ancestor are not answer controls', () async {
    await rejectWithoutWrites(
      scene([
        {
          'id': 'g',
          'type': 'group',
          'visible': false,
          'children': [point()],
        },
      ]),
    );
  });
  test('drag points hidden by the first timeline step are rejected', () async {
    final json = scene([point()])
      ..['timeline'] = {
        'durationMs': 1000,
        'steps': [
          {
            'atMs': 0,
            'hide': ['p'],
          },
        ],
      };
    await rejectWithoutWrites(json);
  });
  test(
    'parameter-bound draggable points are rejected by visual persistence',
    () async {
      final p = point()
        ..['at'] = [
          {r'$param': 'a'},
          0,
        ];
      final json = scene([p])
        ..['model'] = {
          'parameters': {'a': 0},
        };
      await expectLater(createVisual(json), throwsA(isA<AppFormatException>()));
      expect(await practice.list(), isEmpty);
      expect(await db.select(db.visualScenes).get(), isEmpty);
    },
  );
  test('drag points outside the initial viewport are rejected', () async {
    final p = point()..['at'] = [10, 0];
    await rejectWithoutWrites(scene([p]));
  });
  for (final kind in ['point_select', 'drag_to_target']) {
    test('$kind targets outside the viewport are rejected', () async {
      await rejectWithoutWrites(scene([point()]), kind: kind, answer: '10,0');
    });
  }
  for (final which in [
    'missing',
    'hidden',
    'outside',
    'degenerate',
    'covered',
  ]) {
    test('region options must remain selectable: $which', () async {
      final p = polygon('r');
      if (which == 'hidden') p['visible'] = false;
      if (which == 'outside') p['points'] = polygon('r', x: 10)['points'];
      if (which == 'degenerate') {
        p['points'] = [
          [0, 0],
          [1, 1],
          [2, 2],
        ];
      }
      final elements = [
        if (which != 'missing') p,
        if (which == 'covered') polygon('cover'),
      ];
      await rejectWithoutWrites(
        scene(elements),
        kind: 'region_select',
        answer: 'r',
        options: {'r': 'Region'},
      );
    });
  }
  test(
    'partially covered regions with reachable areas are still accepted',
    () async {
      final id = await createVisual(
        scene([polygon('r'), polygon('cover', x: 0)]),
      );
      final q = await practice.create(
        spec(
          id,
          kind: 'region_select',
          answer: 'r',
          options: {'r': 'Left', 'cover': 'Right'},
        ),
      );
      expect((await practice.detail(q)).visualLinks, hasLength(1));
    },
  );
  test(
    'region reachability uses canvas-space precision at large offsets',
    () async {
      final json =
          scene([
              {
                'id': 'r',
                'type': 'polygon',
                'fill': true,
                'points': [
                  [1e16 + 16, -1],
                  [1e16 + 32, -1],
                  [1e16 + 32, 1],
                  [1e16 + 16, 1],
                ],
              },
            ])
            ..['view'] = {
              'x': [1e16, 1e16 + 128],
              'y': [-5, 5],
            };
      final id = await createVisual(json);
      final q = await practice.create(
        spec(id, kind: 'region_select', answer: 'r', options: {'r': 'Visible'}),
      );
      expect((await practice.detail(q)).spec.visualId, id);
    },
  );
  test('revisions specifying the same visual ID without a revision keep the old pin', () async {
    final id = await createVisual(scene([point()]));
    final q = await practice.create(spec(id));
    final oldPin = (await practice.detail(q)).spec.visualRevision;
    await visual.revise(id, jsonEncode(scene([point(draggable: false)])));
    final edited = await practice.revise(q, spec(id));
    expect((await practice.detail(edited)).spec.visualRevision, oldPin);
    expect((await visual.get(id))!.revision, 3);
  });

  test('unreachable distractor options are rejected too', () async {
    await rejectWithoutWrites(
      scene([polygon('r')]),
      kind: 'region_select',
      answer: 'r',
      options: {'r': 'Visible', 'absent': 'Missing'},
    );
  });
}
