import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/a2ui/a2ui_surface_card.dart';

import '../test/support/chat_a2ui.dart';
import 'support/gui_capture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Native chat streams A2UI Express and interacts without another query',
    (t) async {
      final root = await Directory.systemTemp.createTemp('tixun-native-a2ui');
      final provider = A2uiTestProvider();
      final c = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        provider,
        demo: true,
      );
      await c.initialize();
      await c.setLanguage('en');
      final container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TixunApp(),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('start-chat')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('chat-input')),
        'Create native controls',
      );
      await t.tap(find.byKey(const Key('send-message')));
      for (
        var i = 0;
        i < 100 && find.byType(ChatA2uiSurfaceCard).evaluate().length < 3;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.pumpAndSettle();
      expect(c.messages.last.status, 'complete');
      expect(find.byType(ChatA2uiSurfaceCard), findsNWidgets(3));
      final flip = find.text('Flip card');
      await t.ensureVisible(flip);
      await t.tap(flip);
      await t.pumpAndSettle();
      expect(find.text('Back of card', findRichText: true), findsOneWidget);
      expect(provider.requests, hasLength(3));
      expect(t.takeException(), isNull);
      await guiCapture('a2ui', 'native-flashcard');
      await t.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await c.db.close();
      await root.delete(recursive: true);
    },
  );
}
