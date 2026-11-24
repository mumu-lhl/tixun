import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/lexical_form.dart";
import "package:tixun/features/language_learning/vocabulary_editor.dart";

void main() {
  for (final (width, scale) in [(320.0, 1.6), (1200.0, 1.0)]) {
    testWidgets("preview edits and deselects inflections at $width/$scale", (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      VocabularyEntry? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale("en"),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await editVocabularyCandidate(
                    context,
                    const VocabularyEntry(
                      form: "useful",
                      meaning: "helpful",
                      partOfSpeech: "adj.",
                      forms: [
                        LexicalFormDraft("more useful", Inflection.comparative),
                        LexicalFormDraft("most useful", Inflection.superlative),
                      ],
                    ),
                  );
                },
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, "more useful"),
          )
          .controller;
      final comparative = find.byWidgetPredicate(
        (widget) => widget is TextFormField && widget.controller == controller,
      );
      await tester.ensureVisible(comparative);
      await tester.enterText(comparative, "");
      final confirm = find.widgetWithText(FilledButton, "Confirm");
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(result, isNull);
      await tester.ensureVisible(comparative);
      await tester.enterText(comparative, "more helpful");
      await tester.ensureVisible(find.byType(Checkbox).last);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result!.forms, hasLength(1));
      expect(result!.forms.single.surface, "more helpful");
      expect(result!.forms.single.inflection, Inflection.comparative);
      expect(tester.takeException(), isNull);
    });
  }

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
