import "package:drift/drift.dart";
import "package:tixun/core/database/database.dart";

Future<void> seedVisualMessage(
  AppDatabase db,
  String sessionId,
  String messageId,
) async {
  final now = DateTime.now();
  await db
      .into(db.chatSessions)
      .insert(
        ChatSessionsCompanion.insert(
          id: sessionId,
          title: "会话",
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await db
      .into(db.chatMessages)
      .insert(
        ChatMessagesCompanion.insert(
          id: messageId,
          sessionId: sessionId,
          role: "assistant",
          content: "请看图",
          createdAt: now,
        ),
      );
}
