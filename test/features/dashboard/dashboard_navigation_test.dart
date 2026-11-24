import "dart:io";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/app.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/review/review_providers.dart";

void main() {
  for (final (key, path, due) in [
    ("today-review", "/practice", 0),
    ("today-review", "/review", 1),
    ("today-review-schedule", "/review", 0),
    ("today-learning-insights", "/progress", 0),
    ("start-practice", "/practice", 0),
  ]) {
    testWidgets("$key ($due due) returns to study with system back", (t) async {
      late Directory root;
      late AppController c;
      await t.runAsync(() async {
        root = await Directory.systemTemp.createTemp("study-navigation");
        c = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          MockChatProvider(),
          demo: true,
        );
        await c.initialize(seed: false);
      });
      final scope = ProviderContainer(
        overrides: [
          appControllerProvider.overrideWith((_) => c),
          dueCountProvider.overrideWith((_) => due),
        ],
      );
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        scope.dispose();
        await t.runAsync(() async {
          await c.db.close();
          await root.delete(recursive: true);
        });
      });
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      await t.pumpAndSettle();
      final button = find.byKey(Key(key));
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pumpAndSettle();
      final router = scope.read(routerProvider);
      expect(router.state.uri.path, path);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(router.state.uri.path, "/study");
      expect(find.byKey(const Key("today-review")), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    });
  }
}
