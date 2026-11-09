import '../../core/ai/ai_options.dart';
import '../../core/l10n/app_strings.dart';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/ui/reasoning_panel.dart';

final sourceMessageProvider = StreamProvider.autoDispose
    .family<ChatMessage?, String>((ref, id) {
      final db = ref.read(appControllerProvider).db;
      return (db.select(
        db.chatMessages,
      )..where((m) => m.id.equals(id))).watchSingleOrNull();
    });

final reasoningLockedProvider = StreamProvider.autoDispose.family<bool, String>(
  (ref, id) {
    final db = ref.read(appControllerProvider).db;
    return db
        .customSelect(
          '''
    SELECT count(*) AS pending FROM practice_questions q
    WHERE q.deleted = 0 AND (q.source_message_id = ? OR q.id IN
      (SELECT question_id FROM practice_chat_links WHERE message_id = ?))
    AND coalesce((SELECT a.status FROM practice_attempts a WHERE a.question_id = q.id
      ORDER BY a.started_at DESC, a.rowid DESC LIMIT 1), 'draft') NOT IN ('graded', 'awaiting_self_grade')
  ''',
          variables: [Variable(id), Variable(id)],
          readsFrom: {
            db.practiceQuestions,
            db.practiceChatLinks,
            db.practiceAttempts,
          },
        )
        .watchSingle()
        .map((r) => r.read<int>('pending') > 0);
  },
);

class MessageReasoning extends ConsumerWidget {
  const MessageReasoning(
    this.message, {
    this.examGenerating = false,
    super.key,
  });
  final ChatMessage message;
  final bool examGenerating;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = message.reasoningTrace ?? message.reasoningContent ?? '';
    // Watch (not read) the session config: the generating placeholder must
    // refresh when the thinking setting changes mid-generation.
    final reasoningEnabled = AiOptions(
      ref.watch(appControllerProvider).sessionConfig,
    ).reasoningEnabled;
    if (text.isEmpty && (message.status != 'generating' || !reasoningEnabled)) {
      return const SizedBox.shrink();
    }
    final locked = ref.watch(reasoningLockedProvider(message.id));
    // A failed lock query must not lock the panel forever: allow expanding
    // and offer a retry instead of silently locking until re-entry.
    final loadFailed = locked.hasError;
    final panel = ReasoningPanel(
      key: ValueKey('reasoning-${message.id}'),
      text: text,
      generating: message.status == 'generating',
      locked:
          examGenerating ||
          locked.isLoading ||
          (!loadFailed && locked.value != false),
    );
    if (!loadFailed) return panel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panel,
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () =>
                ref.invalidate(reasoningLockedProvider(message.id)),
            child: Text(context.tr('重试')),
          ),
        ),
      ],
    );
  }
}

class SourceReasoning extends ConsumerWidget {
  const SourceReasoning(this.messageId, {super.key});
  final String messageId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(sourceMessageProvider(messageId))
      .when(
        data: (m) => m == null
            ? const SizedBox.shrink()
            : MessageReasoning(m, examGenerating: m.status == 'generating'),
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      );
}
