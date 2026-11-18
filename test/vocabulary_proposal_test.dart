import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/l10n/generated/app_localizations.dart';
import 'package:tixun/features/language_learning/language_store.dart';
import 'package:tixun/features/language_learning/vocabulary_ai.dart';
import 'package:tixun/features/language_learning/vocabulary_proposal_dialog.dart';

const _config = ProviderConfig(
  id: 1,
  kind: 'openai',
  baseUrl: 'https://example.com',
  model: 'test-model',
  vision: false,
  supportsTools: false,
  thinking: false,
  supportsThinking: false,
  effort: '',
);

class _VocabularyProvider implements ChatProvider {
  _VocabularyProvider({required this.completed});

  final bool completed;
  int requests = 0;

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        requests++;
        yield AiChunk(
          completed: completed,
          text:
              '{"language":"en","entries":['
              '{"form":"platform","type":"word","meaning":"a boarding area",'
              '"example":"The train leaves from platform two.",'
              '"translation":"We board at platform two."},'
              '{"form":"ticket","type":"word","meaning":"a pass for a journey",'
              '"example":"I bought a ticket at the station.",'
              '"translation":"I paid for my trip at the station."}]}',
        );
      });
}

Future<void> _openProposal(
  WidgetTester tester,
  LanguageLearningStore store,
  _VocabularyProvider provider,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showVocabularyProposal(
              context,
              store: store,
              ai: VocabularyAi(provider),
              config: _config,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(provider.requests, 0);
  await tester.enterText(find.byType(TextFormField), 'Rail travel');
  await tester.runAsync(() async {
    await tester.tap(find.widgetWithText(FilledButton, 'Generate vocabulary'));
    await tester.pump();
    // Let the native SQLite and stream work finish on the real event loop.
    await store.existingGroupsForEntries('en', const [
      VocabularyEntry(form: 'platform', meaning: 'a boarding area'),
    ]);
  });
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late LanguageLearningStore store;

  setUp(() {
    db = AppDatabase.memory();
    store = LanguageLearningStore(db);
  });

  tearDown(() async {
    store.dispose();
    await db.close();
  });

  testWidgets('preview saves only selected candidates and creates no Chat', (
    tester,
  ) async {
    final provider = _VocabularyProvider(completed: true);
    await _openProposal(tester, store, provider);
    expect(find.text('Review vocabulary candidates'), findsOneWidget);
    expect(provider.requests, 1);
    await tester.runAsync(() async {
      expect(await store.cards(language: 'en'), isEmpty);
    });

    await tester.ensureVisible(find.text('ticket — a pass for a journey'));
    await tester.tap(find.text('ticket — a pass for a journey'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save selected expressions'));
      await store.whenIdle;
    });
    await tester.pumpAndSettle();
    expect(find.text('Review vocabulary candidates'), findsNothing);
    await tester.runAsync(() async {
      final saved = (await store.cards(language: 'en')).single;
      expect(saved.item.form, 'platform');
      expect(saved.sense.aiModel, _config.model);
      expect(await db.select(db.chatMessages).get(), isEmpty);
    });
  });

  testWidgets('an interrupted reply cannot become a saveable preview', (
    tester,
  ) async {
    await _openProposal(tester, store, _VocabularyProvider(completed: false));
    expect(
      find.text(
        'Could not generate a complete vocabulary list. No expressions were saved.',
      ),
      findsOneWidget,
    );
    expect(find.text('Save selected expressions'), findsNothing);
    await tester.runAsync(() async {
      expect(await store.cards(language: 'en'), isEmpty);
    });
  });
}
