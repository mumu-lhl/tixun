import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/ai_usage_store.dart';
import '../../core/ai/chat_provider.dart';
import '../../core/database/database.dart';
import 'language_store.dart';
import 'sentence_batch_store.dart';
import 'sentence_content.dart';

class SentenceBatchAi {
  const SentenceBatchAi({
    required this.provider,
    required this.config,
    this.usageStore,
  });

  final ChatProvider provider;
  final ProviderConfig config;
  final AiUsageStore? usageStore;
  static const _promptVersion = 1;

  Future<SentenceBatchProposal> propose({
    required SentenceTopic topic,
    required SentenceStyle style,
    required SentenceLevel? level,
    required String glossLanguage,
    required int count,
    required CancelToken cancel,
  }) async {
    final id = const Uuid().v4();
    final started = DateTime.now();
    final mock = provider is MockChatProvider;
    final model = mock ? 'Mock' : config.model;
    cancel.checkCancelled();
    final request = AiRequest(
      instructions:
          'Produce a small set of natural English examples for learners. '
          'Return only JSON: {"language":"en","sentences":[{"text":"…",'
          '"hint":"…","translation":"…","level":"beginner"}]}. '
          'Use the requested topic and style. Keep each written example to '
          'one or two sentences, and each dialogue to two short turns. '
          'Allowed levels are beginner and intermediate; mixed allows either. '
          'Write a short hint and translation in the requested gloss language '
          '(for English use a plain English paraphrase). '
          'Do not include duplicates, quizzes, answers, or personal data.',
      messages: [
        AiMessage.user(
          jsonEncode({
            'topic': topic.name,
            'style': style.name,
            'level': level?.name ?? 'mixed',
            'count': count,
            'glossLanguage': glossLanguage,
          }),
        ),
      ],
      maxOutputTokens: 2200,
    );
    final body = StringBuffer(), reasoning = StringBuffer();
    var complete = false;
    var status = 'error';
    AiTokenUsage? usage;
    try {
      final List<SentenceCard> cards;
      if (mock) {
        cards = [
          for (final card in localSentenceBatch(
            topic: topic,
            style: style,
            level: level,
            count: count,
          ).cards)
            SentenceCard.study(
              id: '$id:${card.id}',
              text: card.text,
              hint: card.hint,
              translation: glossLanguage == 'zh' ? card.translation : card.hint,
              level: card.level,
            ),
        ];
      } else {
        await for (final chunk
            in provider.start(config).complete(request, cancel)) {
          cancel.checkCancelled();
          usage = chunk.usage ?? usage;
          if (chunk.calls.isNotEmpty ||
              complete &&
                  (chunk.text.isNotEmpty || chunk.reasoning.isNotEmpty) ||
              body.length + chunk.text.length > 10000 ||
              reasoning.length + chunk.reasoning.length > 32000) {
            throw const FormatException('Invalid sentence batch reply');
          }
          body.write(chunk.text);
          reasoning.write(chunk.reasoning);
          complete |= chunk.completed;
        }
        cancel.checkCancelled();
        if (!complete) {
          status = 'incomplete';
          throw const FormatException('Incomplete sentence batch reply');
        }
        cards = _parse(body.toString(), id, count, level);
      }
      status = 'complete';
      return SentenceBatchProposal(
        id: id,
        topic: topic,
        style: style,
        glossLanguage: glossLanguage,
        model: model,
        promptVersion: _promptVersion,
        isMock: mock,
        generatedAt: DateTime.now(),
        cards: List.unmodifiable(cards),
      );
    } finally {
      final recorder = usageStore;
      if (recorder != null && !mock) {
        try {
          await recorder.record(
            AiUsageCapture(
              actionId: id,
              providerKind: config.kind,
              endpoint: config.baseUrl,
              model: model,
              feature: 'language_sentence_batch',
              status: cancel.isCancelled ? 'incomplete' : status,
              occurredAt: started,
              durationMs: DateTime.now().difference(started).inMilliseconds,
              usage: usage,
            ),
            request: request,
            response: body.toString(),
            reasoning: reasoning.toString(),
          );
        } catch (_) {
          // Usage accounting is independent of generating a preview.
        }
      }
    }
  }

  static List<SentenceCard> _parse(
    String raw,
    String id,
    int count,
    SentenceLevel? requestedLevel,
  ) {
    final trimmed = raw.trim();
    final fence = RegExp(
      r'^\x60\x60\x60(?:json)?\s*([\s\S]+?)\s*\x60\x60\x60$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    final data = jsonDecode(fence?.group(1) ?? trimmed);
    if (data is! Map ||
        data['language'] != 'en' ||
        data['sentences'] is! List) {
      throw const FormatException('Expected English sentences');
    }
    final rows = data['sentences'] as List;
    if (rows.isEmpty || rows.length > count) {
      throw const FormatException('Invalid sentence batch size');
    }
    final seen = <String>{};
    final cards = <SentenceCard>[];
    for (final row in rows) {
      if (row is! Map) throw const FormatException('Invalid sentence');
      String field(String key) {
        final value = row[key];
        if (value is! String || value.trim().isEmpty || value.length > 420) {
          throw const FormatException('Missing or oversized sentence content');
        }
        return value.trim();
      }

      final text = field('text');
      final level = SentenceLevel.values.asNameMap()[row['level']];
      if (level == null ||
          requestedLevel != null && level != requestedLevel ||
          !_latin.hasMatch(text) ||
          !_latinText.hasMatch(text)) {
        throw const FormatException('Unexpected sentence language or level');
      }
      if (!seen.add(normalizeLanguageText(text))) continue;
      cards.add(
        SentenceCard.study(
          id: '$id:${cards.length}',
          text: text,
          translation: field('translation'),
          hint: field('hint'),
          level: level,
        ),
      );
    }
    return cards;
  }

  static final _latin = RegExp(r'\p{Script=Latin}', unicode: true);
  static final _latinText = RegExp(
    r'^[\p{Script=Latin}\p{M}\p{N}\p{P}\p{Zs}\r\n]+$',
    unicode: true,
  );
}
