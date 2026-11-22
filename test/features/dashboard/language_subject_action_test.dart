import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/features/dashboard/language_subject_action.dart";

void main() {
  test("only recognized language subject names expose the entry", () {
    expect(isLanguageLearningSubject(""), false);
    expect(isLanguageLearningSubject("数学"), false);
    expect(isLanguageLearningSubject("Python programming"), false);
    expect(isLanguageLearningSubject("英语"), true);
    expect(isLanguageLearningSubject("语文"), true);
    expect(isLanguageLearningSubject("日语（选修）"), true);
    expect(isLanguageLearningSubject(" English "), true);
  });

  testWidgets(
    "changing subjects animates the language entry in both directions",
    (tester) async {
      const action = Key("open-language-learning");
      const container = Key("animation-measure");
      final subject = ValueNotifier("数学");
      addTearDown(subject.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale("en"),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: subject,
              builder: (context, current, _) =>
                  LanguageSubjectAction(subject: current, key: container),
            ),
          ),
        ),
      );
      final bar = find.byKey(container);
      expect(find.byKey(action), findsNothing);
      expect(tester.getSize(bar).height, 0);
      subject.value = "英语";
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 85));
      final midOpen = tester.getSize(bar).height;
      await tester.pumpAndSettle();
      final opened = tester.getSize(bar).height;
      expect(midOpen, greaterThan(0));
      expect(midOpen, lessThan(opened));
      subject.value = "数学";
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      final midClose = tester.getSize(bar).height;
      expect(midClose, greaterThan(0));
      expect(midClose, lessThan(opened));
      expect(find.byKey(action).hitTestable(), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byKey(action), findsNothing);
      expect(tester.getSize(bar).height, 0);
    },
  );
}
