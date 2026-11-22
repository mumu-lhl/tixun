import "dart:io";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/library/study_editor.dart";

void main() {
  for (final mistake in [false, true]) {
    testWidgets("new material can select a module before saving: $mistake", (
      tester,
    ) async {
      late AppController controller;
      late Directory root;
      late String module;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp("study-editor");
        controller = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          MockChatProvider(),
        );
        await controller.initialize(seed: false);
        module = await controller.study.modules.create("数学", "函数");
      });
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((_) => controller)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp(
            locale: const Locale("en"),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<String>(
                    context: context,
                    builder: (_) => StudyEditor(isMistake: mistake),
                  ),
                  child: const Text("Create"),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text("Create"));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key("study-title")), "Example");
      await tester.ensureVisible(find.byKey(const Key("choose-study-modules")));
      await tester.tap(find.byKey(const Key("choose-study-modules")));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key("module-search")), "函数");
      await tester.pump();
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        true,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, "Save"),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsOneWidget);
      await tester.tap(find.byKey(const Key("save-study")));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final ids = mistake
            ? (await controller.study.searchMistakes()).map((r) => r.id)
            : (await controller.study.searchKnowledge()).map((r) => r.id);
        expect(await controller.study.modules.ids(ids.single, mistake), [
          module,
        ]);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      await tester.runAsync(() async {
        await controller.db.close();
        await root.delete(recursive: true);
      });
    });
  }
}
