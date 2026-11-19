import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/prompt_settings.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/l10n/generated/app_localizations.dart';
import 'package:tixun/features/language_learning/language_store.dart';
import 'package:tixun/features/language_learning/next_practice.dart';
import 'package:tixun/features/language_learning/sentence_batch_ai.dart';
import 'package:tixun/features/language_learning/sentence_batch_store.dart';
import 'package:tixun/features/language_learning/sentence_content.dart';
import 'package:tixun/features/language_learning/sentence_explanation.dart';
import 'package:tixun/features/language_learning/sentence_practice.dart';
import 'package:tixun/features/language_learning/sentence_store.dart';

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

class _Provider implements ChatProvider {
  int calls = 0;
  AiRequest? lastRequest;
  bool complete = true;
  bool offline = false;
  String response = 'The library closes earlier on Saturdays.';

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        expect(
          encodeCompletion(config, request).containsKey('max_tokens'),
          isFalse,
        );
        calls++;
        lastRequest = request;
        if (offline) throw const AiFailure('Offline');
        yield AiChunk(text: response, completed: complete);
      });
}

SentenceCard _card({int revision = 1, bool travel = false}) => SentenceCard(
  id: travel ? 'station' : 'library',
  text: travel
      ? 'The station shuts at noon.'
      : 'On Saturdays, the library closes at noon rather than at six.',
  translation: '图书馆周六中午关门，不是六点。',
  hint: '“Rather than” contrasts two times.',
  question: 'When does it close?',
  choices: const ['At six', 'At noon'],
  correctIndex: 1,
  skill: SentenceSkill.detail,
  level: SentenceLevel.beginner,
  revision: revision,
);

void main() {
  late AppDatabase db;
  late LanguageLearningStore store;
  late _Provider provider;
  late SentenceExplanation explanation;

  setUp(() {
    db = AppDatabase.memory();
    store = LanguageLearningStore(db);
    provider = _Provider();
    explanation = SentenceExplanation(
      store: store,
      provider: provider,
      config: _config,
    );
  });

  tearDown(() async {
    store.dispose();
    await db.close();
  });

  Future<String> explain({int revision = 1, CancelToken? cancel}) =>
      explanation.explain(
        card: _card(revision: revision),
        glossLanguage: 'en',
        simpler: false,
        cancel: cancel ?? CancelToken(),
      );

  test(
    'cached explanation works offline for its revision without making a chat',
    () async {
      final first = await explain();
      provider.offline = true;
      expect(await explain(), first);
      expect(provider.calls, 1);
      await expectLater(explain(revision: 2), throwsA(isA<AiFailure>()));
      expect(provider.calls, 2);
      expect(await db.select(db.chatMessages).get(), isEmpty);
      expect(
        await db.select(db.learningInlineExplanations).get(),
        hasLength(1),
      );
    },
  );

  test(
    'changing explanation preferences bypasses the previous cache',
    () async {
      final original = await explain();
      final custom = SentenceExplanation(
        store: store,
        provider: provider,
        config: _config,
        prompts: PromptSettings().update(
          LanguagePrompt.sentenceExplanation.id,
          'Explain the contrasting phrase first.',
        ),
      );
      Future<String> withPreference() => custom.explain(
        card: _card(),
        glossLanguage: 'en',
        simpler: false,
        cancel: CancelToken(),
      );
      provider.response = 'Rather than contrasts noon with six.';
      expect(await withPreference(), provider.response);
      final request = provider.lastRequest!;
      expect(request.instructions, contains('contrasting phrase first'));
      expect(request.instructions, contains('at most three short sentences'));
      expect(request.tools, isEmpty);
      expect(jsonDecode(request.messages.single.text)['glossLanguage'], 'en');
      provider.offline = true;
      expect(await withPreference(), provider.response);
      expect(await explain(), original);
      expect(provider.calls, 2);
    },
  );

  test('learner can retry after an interrupted explanation', () async {
    provider.complete = false;
    await expectLater(explain(), throwsFormatException);
    expect(await db.select(db.learningInlineExplanations).get(), isEmpty);
    provider.complete = true;
    expect(await explain(), 'The library closes earlier on Saturdays.');
    expect(provider.calls, 2);
  });

  test(
    'follow-up uses distinct independent checks and a fresh context',
    () async {
      SentenceCard detail(SentenceTopic topic) =>
          _card(travel: topic == SentenceTopic.travel);
      final daily = detail(SentenceTopic.dailyLife);
      final travel = detail(SentenceTopic.travel);
      Future<void> record(
        String id,
        SentenceCard card, {
        bool helped = false,
      }) => store.recordSentence(
        batchId: id,
        card: card,
        rating: SentenceRating.understood,
        selectedIndex: (card.correctIndex + 1) % card.choices.length,
        helpUsed: helped ? {SentenceHelp.hint} : {},
        helpBeforeAnswer: helped ? {SentenceHelp.hint} : {},
      );
      await record('one', daily);
      await record('repeat', daily);
      await record('assisted', travel, helped: true);
      final prior = suggestSentences(await store.sentenceEvidence('en').first);
      expect(prior.diagnostic, isTrue);

      await record('independent', travel);
      final suggestion = suggestSentences(
        await store.sentenceEvidence('en').first,
      );
      expect(suggestion.skill, SentenceSkill.detail);
      expect(suggestion.performance.checked, 2);
      expect(suggestion.performance.correct, 0);
      expect(suggestion.performance.assisted, 1);
      expect(suggestion.exclusions, containsAll([daily.text, travel.text]));
      expect(await store.savedForSentencePlan(suggestion), isEmpty);
    },
  );

  test(
    'a weak skill becomes a bounded request and valid checks are reusable',
    () async {
      for (final (i, topic) in SentenceTopic.values.indexed) {
        final card = _card(travel: topic == SentenceTopic.travel);
        await store.recordSentence(
          batchId: 'short-$i',
          card: card,
          rating: SentenceRating.understood,
          helpUsed: const {},
          selectedIndex: (card.correctIndex + 1) % card.choices.length,
        );
      }
      final plan = suggestSentences(await store.sentenceEvidence('en').first);
      expect(plan.skill, SentenceSkill.detail);
      expect(plan.diagnostic, isFalse);
      expect(await store.savedForSentencePlan(plan), isEmpty);
      provider.response = jsonEncode({
        'language': 'en',
        'sentences': [
          for (final room in ['kitchen', 'hall', 'studio', 'cellar', 'garage'])
            {
              'text': 'The spare key is in the $room.',
              'hint': 'Look for a place.',
              'translation': 'Find the spare key in the $room.',
              'level': plan.level.name,
              'skill': plan.skill.name,
              'check': {
                'question': 'Where is the spare key?',
                'choices': [room, 'bedroom', 'porch'],
                'correctIndex': 0,
                'explanation': 'The sentence names the $room.',
              },
            },
        ],
      });
      final ai = SentenceBatchAi(provider: provider, config: _config);
      final proposal = await ai.propose(
        topic: SentenceTopic.dailyLife,
        style: plan.style,
        level: plan.level,
        glossLanguage: 'en',
        count: plan.count,
        cancel: CancelToken(),
        focus: plan.skill,
        exclude: plan.exclusions,
      );
      expect(provider.calls, 1);
      expect(provider.lastRequest!.tools, isEmpty);
      expect(
        provider.lastRequest!.messages.single.text,
        contains('"focus":"detail"'),
      );
      expect(provider.lastRequest!.messages.single.text, contains('"exclude"'));
      expect(
        proposal.cards.map((card) => card.choices.length),
        everyElement(3),
      );
      await store.saveSentenceBatch(
        proposal,
        proposal.cards.map((card) => card.id).toSet(),
      );
      final saved = await store.savedForSentencePlan(plan);
      expect(saved, hasLength(plan.count));
      expect(saved.first.correctIndex, 0);
      expect(saved.first.checkExplanation, contains('kitchen'));

      await store.recordSentence(
        batchId: 'targeted',
        card: saved.first,
        rating: SentenceRating.partial,
        helpUsed: const {},
        selectedIndex: 0,
      );
      final next = suggestSentences(await store.sentenceEvidence('en').first);
      expect(next.skill, isNot(plan.skill));
      expect(next.exclusions, contains(saved.first.text));
      expect(await db.select(db.chatMessages).get(), isEmpty);
    },
  );

  test(
    'invalid generated check is rejected without changing saved batches',
    () async {
      final existing = SentenceBatchProposal(
        id: 'saved',
        topic: SentenceTopic.dailyLife,
        style: SentenceStyle.written,
        glossLanguage: 'en',
        model: 'example',
        promptVersion: 2,
        isMock: false,
        generatedAt: DateTime.now(),
        cards: [_card()],
      );
      await store.saveSentenceBatch(existing, {'library'});
      provider.response = jsonEncode({
        'language': 'en',
        'sentences': [
          {
            'text': 'She arrives on Sunday.',
            'hint': 'Look for the day.',
            'translation': 'She will be there Sunday.',
            'level': 'beginner',
            'skill': 'not_a_skill',
            'check': {
              'question': 'When?',
              'choices': ['Sunday', 'Monday', 'Tuesday'],
              'correctIndex': 0,
              'explanation': 'The day is stated.',
            },
          },
        ],
      });
      final ai = SentenceBatchAi(provider: provider, config: _config);
      await expectLater(
        ai.propose(
          topic: SentenceTopic.dailyLife,
          style: SentenceStyle.written,
          level: SentenceLevel.beginner,
          glossLanguage: 'en',
          count: 1,
          cancel: CancelToken(),
        ),
        throwsFormatException,
      );
      expect((await store.savedSentenceBatches()).single.id, 'saved');
    },
  );

  testWidgets(
    'AI batch saves only confirmed cards and reopens offline without scoring',
    (tester) async {
      const kept = 'The shop opens at ten.';
      const skipped = 'My sister walks to work.';
      provider.response =
          '''
{
  "language": "en",
  "sentences": [
    {"text":"$kept","hint":"Look for a time.","translation":"It opens at 10.","level":"beginner"},
    {"text":"$skipped","hint":"Look for how she travels.","translation":"She goes on foot.","level":"beginner"}
  ]
}
''';
      provider.complete = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SentencePractice(
            store: store,
            explanation: explanation,
            batchAi: SentenceBatchAi(provider: provider, config: _config),
          ),
        ),
      );

      Future<void> tap(String text) async {
        final label = find.text(text).last;
        await tester.ensureVisible(label);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(label);
          await Future<void>.delayed(const Duration(milliseconds: 40));
        });
        await tester.pumpAndSettle();
      }

      expect(find.text('Start offline batch'), findsNothing);
      expect(find.text('Saved sentence batches'), findsOneWidget);
      await tap('Generate an AI batch');
      expect(provider.calls, 0);
      await tap('Generate preview');
      expect(find.text('Save selected and practise'), findsNothing);
      expect(
        find.text(
          'Could not generate a usable batch. Try again or open a saved batch.',
        ),
        findsOneWidget,
      );

      provider.complete = true;
      await tap('Generate preview');
      expect(find.text(kept), findsOneWidget);
      expect(find.text(skipped), findsOneWidget);
      await tester.runAsync(() async {
        expect(await store.savedSentenceBatches(), isEmpty);
      });

      await tap(skipped);
      await tester.runAsync(() async {
        await tester.tap(find.text('Save selected and practise'));
        await store.whenIdle;
      });
      await tester.pumpAndSettle();
      expect(find.text(kept), findsOneWidget);
      expect(find.text('Try a comprehension check'), findsNothing);
      expect(find.text('AI-generated · test-model'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Understood'));
        await store.whenIdle;
        final saved = (await store.savedSentenceBatches()).single;
        expect(openSavedSentenceBatch(saved).cards.single.text, kept);
        expect(
          (await store.sentenceEvidence('en').first).single.correct,
          isNull,
        );
        expect(await db.select(db.chatMessages).get(), isEmpty);
      });
      await tester.pumpAndSettle();

      provider.offline = true;
      await tap('Set up another batch');
      final saved = find.text('Saved sentence batches');
      await tester.ensureVisible(saved);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(saved);
        await tester.pump();
        await store.savedSentenceBatches();
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async => tester.tap(find.text(kept)));
      await tester.pumpAndSettle();
      expect(find.text(kept), findsOneWidget);
      expect(find.text(skipped), findsNothing);
      expect(provider.calls, 2);
    },
  );

  testWidgets(
    'offline sentence check separates helped answers and self-rating',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SentencePractice(
            store: store,
            explanation: explanation,
            initialBatch: SentenceBatch([_card()]),
          ),
        ),
      );
      expect(find.text(_card().text), findsOneWidget);
      expect(find.text('At noon'), findsNothing);
      expect(
        find.text(
          '“Rather than” contrasts the actual closing time with a different one.',
        ),
        findsNothing,
      );

      await tester.tap(find.text('Show a hint'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try a comprehension check'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('At noon'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsNothing);
      await tester.tap(find.text('Check answer'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);

      final finish = find.widgetWithText(OutlinedButton, 'Understood');
      await tester.ensureVisible(finish);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(finish);
        await store.whenIdle;
      });
      await tester.pumpAndSettle();
      expect(find.text('With help: 1/1 correct'), findsOneWidget);
      expect(find.text('Self-rated as understood: 1/1'), findsOneWidget);
      expect(provider.calls, 0);

      await tester.runAsync(() async {
        final attempt = await db
            .select(db.learningSentenceAttempts)
            .getSingle();
        expect(attempt.correct, true);
        expect(attempt.helpBeforeAnswer, SentenceHelp.hint.flag);
        expect(attempt.rating, SentenceRating.understood.name);
      });
    },
  );
}
