import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/l10n/generated/app_localizations.dart';
import 'package:tixun/core/ui/app_menu.dart';
import 'package:tixun/features/language_learning/language_profile_screen.dart';
import 'package:tixun/features/language_learning/language_skills.dart';
import 'package:tixun/features/language_learning/language_store.dart';
import 'package:tixun/features/language_learning/sentence_content.dart';

void main() {
  testWidgets(
    'narrow profile uses anchored controls and opens a recommendation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final db = AppDatabase.memory();
      final store = LanguageLearningStore(db);
      await tester.runAsync(
        () => store.saveEntries(
          language: 'en',
          groupTitle: 'Foundation',
          groupType: VocabularyGroupType.topic,
          entries: const [VocabularyEntry(form: 'go', meaning: '去')],
        ),
      );
      LanguageGoal? goal;
      LanguageRecommendation? chosen;
      var reviews = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LanguageProfileScreen(
            store: store,
            language: 'en',
            onReview: () => reviews++,
            onPractice: (_, plan, selected) {
              chosen = plan;
              goal = selected;
            },
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(find.byType(AppSelectField<LanguageGoal>), findsOneWidget);
      expect(find.byType(AppSelectField<SentenceLevel>), findsOneWidget);
      await tester.tap(find.byType(AppSelectField<LanguageGoal>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MenuItemButton).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppSelectField<SentenceLevel>));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Intermediate'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.schedule));
      expect(reviews, 1);
      await tester.tap(find.byIcon(Icons.tips_and_updates_outlined));
      expect(goal, LanguageGoal.exam);
      expect(chosen?.level, SentenceLevel.intermediate);
      expect(chosen?.skill, LanguageSkill.reading);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        store.dispose();
        await db.close();
      });
    },
  );
}
