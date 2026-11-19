import 'dart:convert';

import 'package:dio/dio.dart';
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
        expect(
          encodeCompletion(config, request).containsKey('max_tokens'),
          isFalse,
        );
        requests++;
        yield AiChunk(
          completed: completed,
          text:
              '{"language":"en","entries":['
              '{"form":"platform","type":"word","meaning":"a boarding area",'
              '"example":"The train leaves from platform two.",'
              '"translation":"We board at platform two.",'
              '"application":"Please wait on the ___ until the doors open.",'
              '"applicationAnswer":"platform"},'
              '{"form":"ticket","type":"word","meaning":"a pass for a journey",'
              '"example":"I bought a ticket at the station.",'
              '"translation":"I paid for my trip at the station."}]}',
        );
      });
}

class _ChunkProvider implements ChatProvider {
  final counts = <int>[];
  bool interruptSecond = false;

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        expect(
          encodeCompletion(config, request).containsKey('max_tokens'),
          isFalse,
        );
        final data = jsonDecode(request.messages.single.text) as Map;
        final count = data['count'] as int;
        counts.add(count);
        expect(request.tools, isEmpty);
        yield AiChunk(
          completed: !interruptSecond || counts.length == 1,
          text: jsonEncode({
            'language': 'en',
            'entries': [
              for (var i = 0; i < count; i++)
                {
                  'form': 'expression ${counts.length} $i',
                  'type': 'phrase',
                  'meaning': 'One meaning.',
                  'example': 'We rehearsed in the morning.',
                  'translation': 'We practised early.',
                  'application': 'Please try ___ another time.',
                  'applicationAnswer': 'expression ${counts.length} $i',
                },
            ],
          }),
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

  test('large vocabulary proposals split requests and preview only complete chunks', () async {
    Future<VocabularyProposal> propose(_ChunkProvider provider) =>
        VocabularyAi(provider).propose(
          config: _config,
          topic: 'Practice',
          groupType: VocabularyGroupType.topic,
          level: VocabularyLevel.beginner,
          glossLanguage: 'en',
          existingExpressions: const [],
          cancel: CancelToken(),
          count: 10,
        );
    final provider = _ChunkProvider();
    final complete = await propose(provider);
    expect(provider.counts, [6, 4]);
    expect(complete.entries, hasLength(10));
    expect(complete.entries.first.application, contains('___'));
    final interrupted = _ChunkProvider()..interruptSecond = true;
    final partial = await propose(interrupted);
    expect(partial.requested, 10);
    expect(partial.entries, hasLength(6));
    expect(await store.cards(language: 'en'), isEmpty);
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
    final edit = find.byTooltip('Edit').first;
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'a place to board',
    );
    final confirm = find.widgetWithText(FilledButton, 'Confirm');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(confirm);
      await tester.pump();
      await store.existingGroupsForEntries('en', const [
        VocabularyEntry(form: 'platform', meaning: 'a place to board'),
      ]);
    });
    await tester.pumpAndSettle();
    expect(find.text('platform — a place to board'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Save selected expressions'));
      await store.whenIdle;
    });
    await tester.pumpAndSettle();
    expect(find.text('Review vocabulary candidates'), findsNothing);
    await tester.runAsync(() async {
      final saved = (await store.cards(language: 'en')).single;
      expect(saved.item.form, 'platform');
      expect(saved.sense.meaning, 'a place to board');
      expect(saved.sense.aiModel, _config.model);
      expect(
        saved.sense.application,
        'Please wait on the ___ until the doors open.',
      );
      expect(saved.sense.applicationAnswer, 'platform');
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
