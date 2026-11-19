import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/l10n/generated/app_localizations.dart';
import 'package:tixun/features/language_learning/language_course.dart';

void main() {
  testWidgets(
    'English and Japanese lessons offer examples without preset quizzes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LanguageCourse(),
        ),
      );
      await tester.tap(find.text('Letters and short vowels'));
      await tester.pumpAndSettle();
      expect(find.text('cat, hat'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Japanese'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('The five hiragana vowels'));
      await tester.pumpAndSettle();
      expect(find.text('あ、い、う、え、お'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    },
  );
}
