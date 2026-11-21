part of "controller.dart";

Future<void> _seedDemo(
  AppDatabase db,
  StudyStore study,
  AttachmentStore files,
) async {
  final s = await db.createSession(title: "二次函数：从配方理解顶点");
  await db
      .into(db.chatMessages)
      .insert(
        ChatMessagesCompanion.insert(
          id: "demo-user",
          sessionId: s.id,
          role: "user",
          content: "二次函数的顶点公式总是记不住，能帮我理解一下吗？",
          createdAt: DateTime(2026, 11, 3, 9),
        ),
      );
  await db
      .into(db.chatMessages)
      .insert(
        ChatMessagesCompanion.insert(
          id: "demo-answer",
          sessionId: s.id,
          role: "assistant",
          content: MockChatProvider.explanation,
          model: const Value("Mock · 离线演示"),
          totalTokens: const Value(368),
          createdAt: DateTime(2026, 11, 3, 9, 0, 1),
        ),
      );
  for (final (title, subject, question) in [
    ("英语阅读：怎样理解长难句", "英语", "读长句时，怎么先找出句子的主干？"),
    ("物理 · 受力分析的学习计划", "物理", "可以从哪些题开始练习画受力图？"),
  ]) {
    final session = await db.createSession(title: title, subject: subject);
    await db
        .into(db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            id: "demo-question:${session.id}",
            sessionId: session.id,
            role: "user",
            content: question,
            createdAt: DateTime(2026, 11, 3, 9),
          ),
        );
  }
  final demoSessions = await db.sessions();
  for (final item in demoSessions) {
    final hour = item.id == s.id
        ? 11
        : item.title.startsWith("英语")
        ? 10
        : 9;
    await (db.update(
      db.chatSessions,
    )..where((t) => t.id.equals(item.id))).write(
      ChatSessionsCompanion(
        createdAt: Value(DateTime(2026, 11, 3, hour)),
        updatedAt: Value(DateTime(2026, 11, 3, hour)),
      ),
    );
  }
  final note = await study.saveKnowledge(
    const KnowledgeDraft(
      title: "从配方理解二次函数的顶点",
      content: MockChatProvider.explanation,
      kind: "解题方法",
      chapter: "函数 · 二次函数",
      tags: ["配方", "顶点", "代数"],
    ),
    sourceSessionId: s.id,
    sourceMessageId: "demo-answer",
  );
  final wrong = await study.saveMistake(
    const MistakeDraft(
      title: "顶点的纵坐标为什么不是常数项？",
      question: r"已知 $g(x)=x^2-6x+5$，求顶点坐标与最小值。",
      chapter: "函数 · 二次函数",
      originalAnswer: "(3, 5)",
      correctAnswer: "(3, -4)，最小值 -4",
      ownAnalysis: "我用对称轴公式得到了3，但把常数5直接作为顶点的纵坐标。",
      aiAnalysis: r"配方得到 $g(x)=(x-3)^2-4$。平方项为零时，函数取最小值。顶点为 $(3,-4)$。",
      suggestedReason: "可能混淆常数项与顶点纵坐标，需要再独立尝试一道题确认。",
      tags: ["二次函数", "易错点"],
    ),
    sourceSessionId: s.id,
    sourceMessageId: "demo-user",
  );
  await study.link(note.id, mistakeId: wrong.id);
  final asset = await rootBundle.load("assets/demo/two_problems.png");
  final file = files.resolve("attachments/demo-two-problems.png");
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
  );
  await study.addImageReference(
    wrong.id,
    "attachments/demo-two-problems.png",
    "image/png",
    asset.lengthInBytes,
    isMistake: true,
  );
  await db.setPreference("selected_session", s.id);
}
