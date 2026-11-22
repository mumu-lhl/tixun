import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/vocabulary_editor.dart";

void main() {
  testWidgets(
    "vocabulary edits survive canceling discard, including system back",
    (tester) async {
      VocabularyEntry? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale("en"),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await editVocabularyCandidate(
                    context,
                    const VocabularyEntry(form: "hello", meaning: "greeting"),
                  );
                },
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );
      Future<void> open() async {
        await tester.tap(find.text("Open"));
        await tester.pumpAndSettle();
      }

      await open();
      await tester.ensureVisible(find.text("Cancel"));
      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await open();
      await tester.enterText(find.byType(TextFormField).first, "goodbye");
      await tester.ensureVisible(find.text("Cancel"));
      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();
      expect(find.text("Discard unsaved changes?"), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, "Cancel").last);
      await tester.pumpAndSettle();
      expect(find.text("goodbye"), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text("Discard unsaved changes?"), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, "Discard"));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(result, isNull);
    },
  );
}
