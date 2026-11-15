import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/library_screen.dart';
import 'package:tixun/features/settings/settings_screen.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    for (final rightward in [true, false]) {
      testWidgets(
        'bottom navigation enters from the ${rightward ? 'right' : 'left'} (reduced motion: $reducedMotion)',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(disableAnimations: reducedMotion);
          addTearDown(
            tester
                .binding
                .platformDispatcher
                .clearAccessibilityFeaturesTestValue,
          );
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          late Directory root;
          late AppController c;
          await tester.runAsync(() async {
            root = await Directory.systemTemp.createTemp('navigation-motion');
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
          router.go(rightward ? '/mistakes' : '/settings');
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(Key(rightward ? 'nav-4' : 'nav-2')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
          final page = rightward
              ? find.byType(SettingsScreen)
              : find.byType(LibraryScreen);
          final enteringX = tester.getTopLeft(page).dx;
          expect(
            enteringX,
            reducedMotion
                ? closeTo(0, .01)
                : rightward
                ? greaterThan(0)
                : lessThan(0),
            reason: 'The incoming page must follow the destination’s position.',
          );
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(page).dx, closeTo(0, .01));
          expect(router.state.uri.path, rightward ? '/settings' : '/mistakes');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
