import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/practice/practice_screen.dart';
import 'package:tixun/features/practice/question_spec.dart';

void main() {
  for (final kind in [
    'numeric',
    'read_value',
    'point_select',
    'drag_to_target',
    'region_select',
  ]) {
    testWidgets('editing $kind preserves its snapshot and region IDs', (
      tester,
    ) async {
      late Directory root;
      late AppController c;
      late String originalId;
      late String visualId;
      late int revision;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('visual-editor');
        c = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          MockChatProvider(),
        );
        await c.initialize();
        final now = DateTime.now();
        await c.db
            .into(c.db.chatSessions)
            .insert(
              ChatSessionsCompanion.insert(
                id: 's',
                title: 'Test',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await c.db
            .into(c.db.chatMessages)
            .insert(
              ChatMessagesCompanion.insert(
                id: 'm',
                sessionId: 's',
                role: 'assistant',
                content: 'Figure',
                createdAt: now,
              ),
            );
        visualId = await c.visual.create(
          messageId: 'm',
          sceneJson: jsonEncode({
            'v': 1,
            'kind': 'geometry',
            'view': {
              'x': [-5, 5],
              'y': [-5, 5],
            },
            'elements': [
              {
                'id': 'p',
                'type': 'point',
                'at': [0, 0],
                'draggable': true,
              },
              {
                'id': 'original-region',
                'type': 'polygon',
                'points': [
                  [-1, -1],
                  [1, -1],
                  [1, 1],
                  [-1, 1],
                ],
                'fill': true,
              },
            ],
            'meta': {'alt': 'Editor fixture'},
          }),
        );
        originalId = await c.practice.create(
          QuestionSpec(
            kind: kind,
            stem: 'Original stem',
            visualId: visualId,
            options: kind == 'region_select'
                ? {'original-region': 'Original region'}
                : const {},
            answers: [
              [
                kind == 'region_select'
                    ? 'original-region'
                    : kind == 'numeric' || kind == 'read_value'
                    ? '1'
                    : '2,0',
              ],
            ],
          ),
        );
        revision = (await c.practice.detail(originalId)).spec.visualRevision!;
      });
      addTearDown(() async {
        await c.shutdown();
        await root.delete(recursive: true);
      });
      final detail = await tester.runAsync(() => c.practice.detail(originalId));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => QuestionEditor(initial: detail),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/practice/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Saved ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('question-stem')),
        'Edited stem',
      );
      if (kind == 'region_select') {
        final options = find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == 'Original region',
        );
        await tester.ensureVisible(options);
        await tester.enterText(options, 'Renamed region');
      }
      await tester.tap(find.widgetWithText(FilledButton, '保存题目'));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        if (find.textContaining('Saved ').evaluate().isNotEmpty) break;
      }
      expect(find.textContaining('Saved '), findsOneWidget);
      await tester.runAsync(() async {
        final questions = await c.practice.list();
        expect(questions, hasLength(2));
        final edited = await c.practice.detail(
          questions.singleWhere((q) => q.id != originalId).id,
        );
        expect(edited.spec.stem, 'Edited stem');
        expect(edited.spec.visualId, visualId);
        expect(edited.spec.visualRevision, revision);
        expect(edited.spec.answers, detail!.spec.answers);
        if (kind == 'region_select') {
          expect(edited.spec.options, {'original-region': 'Renamed region'});
        }
        expect((await c.visual.get(visualId))!.revision, revision);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
