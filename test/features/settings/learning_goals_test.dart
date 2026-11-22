import "dart:async";
import "dart:io";

import "package:drift/native.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/app_strings.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/progress/learning_profile.dart";
import "package:tixun/features/progress/profile_editor.dart";

class _DelayedProfileDatabase extends AppDatabase {
  _DelayedProfileDatabase() : super(NativeDatabase.memory());

  final _release = Completer<void>();
  String? _pending;

  @override
  Future<void> setPreference(String name, String value) {
    if (name != "learning_profile") return super.setPreference(name, value);
    _pending = value;
    return _release.future;
  }

  Future<void> finishWrite() async {
    await super.setPreference("learning_profile", _pending!);
    _release.complete();
  }
}

void main() {
  testWidgets("learning goals keep their text appearance while saving", (
    tester,
  ) async {
    final db = _DelayedProfileDatabase();
    final root = await tester.runAsync(
      () => Directory.systemTemp.createTemp("tixun-learning-goals"),
    );
    final controller = AppController(
      db,
      AttachmentStore(root!),
      MemoryKeyStore(),
      MockChatProvider(),
      demo: true,
    );
    final scope = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((_) => controller)],
    );
    addTearDown(() async {
      scope.dispose();
      await controller.shutdown();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const ProfileEditor(LearningProfile()),
                ),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();
    final dialog = find.byType(ProfileEditor);
    final l10n = tester.element(dialog).l10n;
    final save = find.widgetWithText(FilledButton, l10n.save);
    final input = find.byType(EditableText).first;
    await tester.enterText(input, "New stage");
    final color = tester.widget<EditableText>(input).style.color;

    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<EditableText>(input).style.color, color);
    expect(find.text(l10n.savingEllipsis), findsNothing);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(dialog, findsOneWidget);

    await tester.runAsync(() async {
      await db.finishWrite();
      expect((await LearningProfile.load(db)).stage, "New stage");
    });
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });
}
