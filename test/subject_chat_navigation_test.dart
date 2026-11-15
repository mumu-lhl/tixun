import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

void main() {
  for (final width in [390.0, 1200.0]) {
    for (final existing in [true, false]) {
      for (final entry in ['navigation', 'dashboard', 'shortcut']) {
        if (!existing && entry != 'navigation') continue;
        // Navigation has separate phone/sidebar controls: keep both states
        // at both widths. Dashboard and keyboard dispatch are shared paths.
        if (entry == 'dashboard' && width != 390) continue;
        if (entry == 'shortcut' && width != 1200) continue;
        testWidgets(
          '$entry chat entry at $width ${existing ? 'reopens' : 'creates'} the selected subject',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, 900);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            late Directory root;
            late AppController c;
            String? physicsId;
            await tester.runAsync(() async {
              root = await Directory.systemTemp.createTemp(
                'subject-chat-entry',
              );
              c = AppController(
                AppDatabase.memory(),
                AttachmentStore(root),
                MemoryKeyStore(),
                MockChatProvider(),
                demo: true,
              );
              await c.initialize(seed: false);
              await c.setSubjectFilter('数学');
              await c.newSession();
              await c.send('解释一下二次函数');
              await c.draft('尚未发送的数学草稿');
              if (existing) {
                physicsId = (await c.db.createSession(
                  title: '物理讨论',
                  subject: '物理',
                )).id;
              }
            });
            final mathId = c.selected!.id;
            final scope = ProviderContainer(
              overrides: [appControllerProvider.overrideWith((_) => c)],
            );
            addTearDown(() async {
              scope.dispose();
              await c.db.close();
              await root.delete(recursive: true);
            });
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: scope,
                child: const TixunApp(),
              ),
            );
            final router = scope.read(routerProvider);
            router.go('/study');
            await tester.pumpAndSettle();
            Future<void> openChat() async {
              final dashboardButton = find.text(c.l10n.allConversations);
              if (entry == 'dashboard') {
                await tester.scrollUntilVisible(dashboardButton, 250);
                await tester.pumpAndSettle();
              }
              await tester.runAsync(() async {
                if (entry == 'shortcut') {
                  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
                  await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
                  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
                } else {
                  await tester.tap(
                    entry == 'dashboard'
                        ? dashboardButton
                        : find.byKey(const Key('nav-1')),
                  );
                }
                await Future<void>.delayed(const Duration(milliseconds: 150));
              });
              await tester.pumpAndSettle();
            }

            await tester.runAsync(() => c.setSubjectFilter('物理'));
            await tester.pumpAndSettle();
            // Merely filtering records must not cancel a running conversation.
            expect(c.selected!.id, mathId);
            await openChat();
            expect(router.state.uri.path, '/chat');
            expect(c.selected!.subject, '物理');
            expect(c.selected!.id, isNot(mathId));
            if (existing) expect(c.selected!.id, physicsId);
            final count = (await c.db.sessions()).length;
            expect(count, 2);
            final old = (await c.db.sessions()).singleWhere(
              (s) => s.id == mathId,
            );
            expect(old.subject, '数学');
            expect(old.draft, '尚未发送的数学草稿');
            expect(await c.db.messages(mathId), hasLength(2));
            expect(c.messages, isEmpty);

            router.go('/study');
            await tester.pumpAndSettle();
            await tester.runAsync(() => c.setSubjectFilter('数学'));
            await tester.pumpAndSettle();
            await openChat();
            expect(c.selected!.id, mathId);
            expect(c.messages.first.content, '解释一下二次函数');
            expect(c.selected!.draft, '尚未发送的数学草稿');
            expect((await c.db.sessions()).length, count);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
