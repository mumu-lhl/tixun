import 'dart:convert';
import 'dart:io';

// The official renderer currently uses legacy Material widgets.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/l10n/generated/app_localizations.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/a2ui/a2ui_surface_card.dart';
import 'package:tixun/features/visual/visual_markdown.dart';
import 'package:tixun/features/visual/visual_card.dart';

import 'support/chat_a2ui.dart';

void main() {
  testWidgets(
    'Inline diagrams and forms render once and restore local controls',
    (t) async {
      t.view.physicalSize = const Size(320, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final root = (await t.runAsync(
        () => Directory.systemTemp.createTemp('tixun-a2ui-widget'),
      ))!;
      final provider = A2uiTestProvider();
      final c = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        provider,
      );
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      addTearDown(() async {
        scope.dispose();
        await c.db.close();
        await root.delete(recursive: true);
      });
      await t.runAsync(() async {
        await c.initialize();
        await c.newSession();
        await c.setAiDrawingEnabled(true);
        await c.send('Draw a parabola and create native controls');
      });
      final reply = c.messages.last;
      expect(reply.status, 'complete', reason: reply.error);
      Widget shell() => UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (_, child) {
            // ignore: deprecated_member_use
            return MaterialUiCompatibilityBridge(child: child!);
          },
          home: Scaffold(
            body: SingleChildScrollView(
              child: VisualMarkdown(
                reply.content,
                sessionId: reply.sessionId,
                messageId: reply.id,
              ),
            ),
          ),
        ),
      );

      Future<void> pumpSurface() async {
        await t.pumpWidget(shell());
        for (
          var i = 0;
          i < 12 && find.byType(ChatA2uiSurfaceCard).evaluate().length < 3;
          i++
        ) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)),
          );
          await t.pump();
        }
        await t.pumpAndSettle();
        expect(find.byType(ChatA2uiSurfaceCard), findsNWidgets(3));
      }

      await pumpSurface();
      expect(find.text('A parabola'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Back of card'), findsNothing);
      expect(find.byType(legacy.Slider), findsNWidgets(2));
      final plot = find.byType(VisualCard);
      expect(t.widget<VisualCard>(plot).scene.model!.parameters['a'], 1);
      await t.runAsync(() async {
        t.widget<legacy.Slider>(find.byType(legacy.Slider).first).onChanged!(2);
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await t.pumpAndSettle();
      expect(t.widget<VisualCard>(plot).scene.model!.parameters['a'], 2);
      final promote = find.text('Save as a reusable figure');
      await t.ensureVisible(promote);
      await t.tap(promote);
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await t.tap(find.text('Save').last);
        await Future<void>.delayed(const Duration(milliseconds: 35));
      });
      await t.pumpAndSettle();
      final promoted = await t.runAsync(
        () => c.visual.listBySession(reply.sessionId),
      );
      expect(promoted, hasLength(1));
      expect(find.byType(VisualCard), findsOneWidget);
      expect(find.byType(legacy.TextField), findsOneWidget);
      final flip = find.text('Flip card');
      await t.ensureVisible(flip);
      await t.tap(flip);
      await t.pumpAndSettle();
      final field = find.byType(legacy.TextField);
      await t.ensureVisible(field);
      await t.enterText(field, 'edited expression');
      await t.pumpAndSettle();
      expect(find.text('Back of card', findRichText: true), findsOneWidget);

      final choice = find.text('Formal');
      await t.ensureVisible(choice);
      await t.tap(choice);
      await t.pumpAndSettle();

      final action = find.text('Ask about this');
      await t.ensureVisible(action);
      await t.tap(action);
      await t.pumpAndSettle();
      expect(find.text('Continue in chat'), findsOneWidget);
      expect(provider.requests, hasLength(1));
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(provider.requests, hasLength(1));
      await t.tap(action);
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await t.tap(find.text('Send to AI'));
        for (
          var i = 0;
          i < 150 && (c.busy || provider.requests.length < 2);
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await t.pumpAndSettle();
      expect(c.busy, false);
      expect(provider.requests.length, greaterThan(1));
      expect(
        c.messages.where((m) => m.role == 'user').last.content,
        contains('edited expression'),
      );
      expect(
        provider.requests[1].instructions,
        contains('Relevant saved interface metadata'),
      );
      final state = await t.runAsync(() async {
        final rows = await a2uiRows(c.db, reply.id);
        expect(await c.db.select(c.db.chatA2uiActions).get(), hasLength(1));
        return jsonDecode(
          rows.singleWhere((r) => r.express == expressForm).stateJson!,
        ) as Map;
      });
      expect(state, containsPair('flipped', true));
      expect(state, containsPair('choices', ['formal']));
      expect(state, containsPair('word', 'edited expression'));

      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      await pumpSurface();
      expect(find.text('Back of card', findRichText: true), findsOneWidget);
      expect(
        t
            .widget<legacy.TextField>(find.byType(legacy.TextField))
            .controller!
            .text,
        'edited expression',
      );
      expect(t.widget<VisualCard>(plot).scene.model!.parameters['a'], 2);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
}
