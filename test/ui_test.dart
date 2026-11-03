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
        for (final route in ['/study', '/chat', '/settings']) {
          container.read(routerProvider).go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$width $route');
        }
      }
      await tester.runAsync(() => c.theme(ThemeMode.dark));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      container.read(routerProvider).go('/chat');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-input')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chat-input')), '不会丢失的草稿');
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      expect(c.selected!.draft, '不会丢失的草稿');
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
