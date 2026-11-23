import "dart:io";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/app/theme.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/vocabulary_batch.dart";
import "package:tixun/features/language_learning/vocabulary_groups_screen.dart";

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets(
      "vocabulary cards open in the bottom mode and create empty groups at $width",
      (tester) async {
        late AppController c;
        late Directory root;
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp("vocabulary-groups");
          c = AppController(
            AppDatabase.memory(),
            AttachmentStore(root),
            MemoryKeyStore(),
            MockChatProvider(),
            demo: true,
          );
          await c.initialize(seed: false);
          for (var i = 0; i < 12; i++) {
            await c.language.saveEntries(
              language: "en",
              groupTitle: "Group $i",
              groupType: VocabularyGroupType.topic,
              entries: [VocabularyEntry(form: "word$i", meaning: "Meaning $i")],
            );
          }
        });
        addTearDown(
          () => tester.runAsync(() async {
            c.dispose();
            await c.db.close();
            await root.delete(recursive: true);
          }),
        );
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appControllerProvider.overrideWith((_) => c)],
            child: MaterialApp(
              theme: appTheme(Brightness.light),
              locale: const Locale("en"),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const VocabularyGroupsScreen(),
            ),
          ),
        );
        await tester.runAsync(() => c.language.groups("en").first);
        await tester.pumpAndSettle();
        expect(find.text("Add"), findsNothing);
        expect(find.text("Generate vocabulary"), findsNothing);
        final modeY = tester.getCenter(find.text("Practice")).dy;
        await tester.drag(find.byType(ListView).first, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.getCenter(find.text("Practice")).dy, modeY);
        await tester.tap(find.text("Practice"));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text("Group 9"),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text("Group 9"));
        await tester.pumpAndSettle();
        expect(
          tester.widget<VocabularyBatch>(find.byType(VocabularyBatch)).mode,
          VocabularyMode.recall,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key("create-vocabulary-group")));
        await tester.pumpAndSettle();
        expect(find.byType(SwitchListTile), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), "Empty group");
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, "Create"));
          await c.language.whenIdle;
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final empty = await c.language.groupNamed("en", "Empty group");
          expect(empty, isNotNull);
          expect(await c.language.groupExpressions(empty!.id), isEmpty);
        });
        final group = await tester.runAsync(
          () => c.language.groupNamed("en", "Group 0"),
        );
        await tester.scrollUntilVisible(
          find.text("Group 0"),
          -220,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.byKey(ValueKey("vocabulary-group-${group!.id}"))),
          alignment: .2,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey("vocabulary-menu-${group.id}")));
        await tester.pumpAndSettle();
        expect(find.text("Add"), findsOneWidget);
        expect(find.text("Expand with AI"), findsOneWidget);
        expect(find.text("Delete"), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }

  test(
    "group creation rejects normalized duplicate names and never creates words",
    () async {
      final db = AppDatabase.memory();
      final store = LanguageLearningStore(db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      final id = await store.createGroup(
        "en",
        "Travel",
        VocabularyGroupType.topic,
      );
      await expectLater(
        store.createGroup("en", "  travel  ", VocabularyGroupType.topic),
        throwsArgumentError,
      );
      expect((await store.groupNamed("en", "TRAVEL"))!.id, id);
      expect(await db.select(db.learningLexicalItems).get(), isEmpty);
    },
  );
}
