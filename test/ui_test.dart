import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/app/theme.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/core/ui/learning_markdown.dart';
import 'package:tixun/features/practice/question_card.dart';
import 'package:tixun/features/practice/question_spec.dart';

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
  testWidgets(
    'Interactive quiz hides answers, persists submission and fits narrow phones',
    (tester) async {
      late AppController c;
      late String id;
      await tester.runAsync(() async {
        final root = await Directory.systemTemp.createTemp('tixun-quiz-widget');
        c = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          MockChatProvider(),
        );
        await c.initialize();
        id = await c.practice.create(
          const QuestionSpec(
            kind: 'single_choice',
            stem: r'函数 $y=x^2-4x+3$ 的顶点坐标是？',
            options: {
              'A': r'$(2,-1)$',
              'B': r'$(-2,-1)$',
              'C': r'$(2,3)$',
              'D': r'$(-2,3)$',
            },
            answers: [
              ['A'],
            ],
            explanation: '作答后才显示这段解析。',
            hint: '先配方。',
          ),
          origin: 'ai',
          verification: 'unverified',
        );
      });
      final container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      addTearDown(() async {
        await tester.runAsync(() async {
          container.dispose();
          await c.db.close();
          if (await c.files.root.exists()) {
            await c.files.root.delete(recursive: true);
          }
        });
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: QuestionCard(id),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('作答后才显示这段解析'), findsNothing);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/quiz_phone.png'),
      );
      await tester.tap(find.byKey(const Key('option-A')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('submit-quiz')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 20 && find.textContaining('作答后才显示这段解析').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('作答后才显示这段解析'), findsOneWidget);
      await tester.runAsync(() async {
        expect((await c.practice.detail(id)).latest!.correct, true);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Responsive real app navigation, long math and settings in light/dark',
    (tester) async {
      late AppController c;
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('tixun-widget');
        c = AppController(
          AppDatabase.memory(),
          AttachmentStore(dir),
          MemoryKeyStore(),
          MockChatProvider(),
          demo: true,
        );
        await c.initialize();
      });
      final container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      addTearDown(() async {
        container.dispose();
        await c.db.close();
        await c.files.root.delete(recursive: true);
      });
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [1280.0, 390.0, 360.0]) {
        tester.view.physicalSize = Size(width, 860);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const TixunApp(),
          ),
        );
        await tester.pumpAndSettle();
        for (final route in [
          '/study',
          '/chat',
          '/settings',
          '/knowledge',
          '/mistakes',
          '/practice',
          '/review',
          '/progress',
        ]) {
          container.read(routerProvider).go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$width $route');
        }
      }
      final note = await tester.runAsync(
        () async => (await c.study.searchKnowledge()).first,
      );
      final wrong = await tester.runAsync(
        () async => (await c.study.searchMistakes()).first,
      );
      for (final path in ['/knowledge/${note!.id}', '/mistakes/${wrong!.id}']) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: path);
      }
      await tester.runAsync(() => c.theme(ThemeMode.dark));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      container.read(routerProvider).go('/chat');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/chat_dark_phone.png'),
      );
      expect(find.byKey(const Key('chat-input')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chat-input')), '不会丢失的草稿');
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      expect(c.selected!.draft, '不会丢失的草稿');
      tester.view.physicalSize = const Size(360, 760);
      tester.view.viewInsets = const FakeViewPadding(bottom: 360);
      addTearDown(tester.view.resetViewInsets);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() => c.addImage('assets/demo/two_problems.png'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chat-input')),
        '第一行\n第二行\n第三行\n第四行\n第五行\n第六行',
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Keyboard, image preview, long draft and large text must fit together',
      );
      expect(
        tester.getRect(find.byKey(const Key('chat-input'))).bottom,
        lessThanOrEqualTo(400),
      );
      expect(
        tester.getRect(find.byKey(const Key('send-message'))).bottom,
        lessThanOrEqualTo(400),
        reason: 'Send stays above the keyboard',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Math supports fractions, matrix, aligned and invalid syntax fallback',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const content = r'''# 公式与推导
行内 $x_1^2+\frac{1}{2}$ 与中文混排。

$$\begin{pmatrix}1&2\\3&4\end{pmatrix}$$

$$
\begin{aligned} x+y&=3\\x-y&=1\end{aligned}
$$

未知语法 $\unknowncommand{x}$ 应回退为源代码。

```dart
final answer = 42;
```
''';
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: LearningMarkdown(content),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/math_phone.png'),
      );
    },
  );
}
