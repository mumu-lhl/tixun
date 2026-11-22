import "package:dio/dio.dart";
import "package:drift_dev/api/migrations_native.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/features/a2ui/a2ui_catalog.dart";
import "package:tixun/features/a2ui/a2ui_store.dart";

import "../../generated_migrations/schema.dart";

void main() {
  test("v28 chat upgrades to v29 and can save standard A2UI payloads", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final old = await verifier.schemaAt(28);
    old.rawDatabase.execute(
      "INSERT INTO chat_sessions(id,title,created_at,updated_at) VALUES('s','Legacy',1,1)",
    );
    old.rawDatabase.execute(
      "INSERT INTO chat_messages(id,session_id,role,content,status,created_at) "
      "VALUES('m','s','assistant','Legacy prose','complete',1)",
    );
    final db = AppDatabase(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 29);
    expect((await db.messages("s")).single.content, "Legacy prose");
    expect(await db.select(db.chatA2uiSurfaces).get(), isEmpty);
    await db
        .into(db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            id: "n",
            sessionId: "s",
            role: "assistant",
            content: "",
            createdAt: DateTime.now(),
          ),
        );
    final record = (await db.messages("s")).last;
    await db
        .update(db.chatMessages)
        .replace(record.copyWith(status: "generating"));
    final row = await ChatA2uiStore(db).saveInline(
      sessionId: "s",
      messageId: "n",
      blockIndex: 0,
      drawingEnabled: true,
      express: 'root = Text("New")',
      bodyAtInsertion: "",
      cancel: CancelToken(),
    );
    expect(
      readChatA2ui(row.messagesJson, row.id).components!.single["text"],
      "New",
    );
  });
}
