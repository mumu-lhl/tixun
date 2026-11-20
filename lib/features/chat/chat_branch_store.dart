import "package:drift/drift.dart";
import "package:uuid/uuid.dart";

import "../../core/database/database.dart";
import "../../core/l10n/app_error.dart";
import "../practice/practice_store.dart";
import "../a2ui/a2ui_store.dart";
import "chat_context_store.dart";

/// Copies only the prefix ending at the chosen message. Original messages,
/// drafts stay untouched. Saved figures and attempts retain their references;
/// no new attempts or learning statistics are created.
class ChatBranchStore {
  ChatBranchStore(this.db, this.practice, {required this.copySettings});
  final AppDatabase db;
  final PracticeStore practice;
  final Future<void> Function(String source, String target) copySettings;

  Future<ChatSession> fork({
    required ChatMessage through,
    required String title,
    String? editedText,
    bool inheritStudyLinks = true,
  }) => db.transaction(() async {
    final source = await (db.select(
      db.chatMessages,
    )..where((m) => m.id.equals(through.id))).getSingleOrNull();
    final parent = source == null
        ? null
        : await (db.select(
            db.chatSessions,
          )..where((s) => s.id.equals(source.sessionId))).getSingleOrNull();
    if (source == null ||
        source.status == "generating" ||
        parent == null ||
        parent.deleted) {
      throw const AppFormatException(
        AppErrorCode.cannotForkMessage,
        "请从未删除会话中的已完成消息创建分支。",
      );
    }
    final history = await db.messages(parent.id);
    final end = history.indexWhere((m) => m.id == source.id);
    final prefix = history.take(end + 1).toList();
    final images = await db.images(parent.id);
    final created = await db.createSession(
      title: title,
      mode: parent.mode,
      subject: parent.subject,
    );
    var branch = created.copyWith(
      toolsEnabled: parent.toolsEnabled,
      stage: parent.stage,
    );
    await db.update(db.chatSessions).replace(branch);
    await copySettings(parent.id, branch.id);
    final studyLinks = await (db.select(
      db.studyChatLinks,
    )..where((l) => l.sessionId.equals(parent.id))).get();
    if (inheritStudyLinks) {
      for (final link in studyLinks) {
        await db
            .into(db.studyChatLinks)
            .insert(link.copyWith(id: const Uuid().v4(), sessionId: branch.id));
      }
    }
    // Public scene links are reused, preserving literal Markdown IDs and the
    // exact message prefix. Never copy private question/solution snapshots.
    final query =
        db.select(db.visualScenes).join([
          innerJoin(
            db.visualMessageLinks,
            db.visualMessageLinks.visualId.equalsExp(db.visualScenes.id),
          ),
        ])..where(
          db.visualMessageLinks.messageId.isIn(prefix.map((m) => m.id)) &
              db.visualScenes.deleted.equals(false),
        );
    final visualLinks = await query.get();
    final messageIds = <String, String>{};
    final attachmentIds = <String, String>{};
    final a2ui = ChatA2uiStore(db);
    for (final message in prefix) {
      final newId = const Uuid().v4();
      messageIds[message.id] = newId;
      final content = message.id == source.id && editedText != null
          ? editedText.trim()
          : message.content;
      await db
          .into(db.chatMessages)
          .insert(
            message.copyWith(id: newId, sessionId: branch.id, content: content),
          );
      if (message.role == "assistant") {
        await practice.linkFork(message.id, newId);
        await a2ui.copyMessage(
          sourceSession: parent.id,
          sourceMessage: message.id,
          targetSession: branch.id,
          targetMessage: newId,
        );
      }
      for (final image in images.where((a) => a.messageId == message.id)) {
        final id = const Uuid().v4();
        attachmentIds[image.id] = id;
        await db
            .into(db.attachments)
            .insert(
              image.copyWith(
                id: id,
                sessionId: branch.id,
                messageId: Value(newId),
              ),
            );
      }
      for (final row in visualLinks.where(
        (r) => r.readTable(db.visualMessageLinks).messageId == message.id,
      )) {
        final link = row.readTable(db.visualMessageLinks);
        await db
            .into(db.visualMessageLinks)
            .insert(link.copyWith(messageId: newId));
      }
    }
    final context = ChatContextStore(db);
    final transcript = await context.load(parent.id);
    // The edited turn has new content and must be captured on its first send.
    // Earlier checkpoints remain valid if their entire prefix survived.
    if (editedText != null) messageIds.remove(source.id);
    await context.copyPrefix(
      source: transcript,
      messages: messageIds,
      attachments: attachmentIds,
    );
    final checkpoint = transcript.latestCheckpoint(messageIds.keys);
    final watermark = messageIds[checkpoint?.$1 ?? parent.contextSummaryUpToId];
    final summary = checkpoint?.$2 ?? parent.contextSummary;
    if (summary != null && watermark != null) {
      branch = branch.copyWith(
        contextSummary: Value(summary),
        contextSummaryUpToId: Value(watermark),
      );
      await db.update(db.chatSessions).replace(branch);
    }
    // Unsaved drafts and Python workspaces remain with the original chat.
    return branch;
  });
}
