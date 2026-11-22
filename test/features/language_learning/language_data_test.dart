import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/features/language_learning/language_data.dart";

void main() {
  for (final synchronous in [false, true]) {
    testWidgets(
      "retry failed read without resetting surrounding input: $synchronous",
      (tester) async {
        var attempts = 0;
        Stream<String> load() {
          attempts++;
          if (attempts == 1) {
            if (synchronous) throw StateError("read failed");
            return Stream.error(StateError("read failed"));
          }
          return Stream.value("Recovered library");
        }

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale("en"),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  const TextField(),
                  LanguageDataBuilder<String>(
                    load: load,
                    builder: (_, value) => Text(value),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(attempts, 1);
        expect(find.text("Retry"), findsOneWidget);
        await tester.enterText(find.byType(TextField), "keep my topic");
        await tester.tap(find.text("Retry"));
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(find.text("Recovered library"), findsOneWidget);
        expect(find.text("Retry"), findsNothing);
        expect(find.text("keep my topic"), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
