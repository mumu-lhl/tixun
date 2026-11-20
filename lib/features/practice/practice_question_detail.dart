part of "practice_store.dart";

extension _PracticeQuestionDetails on PracticeStore {
  Future<QuestionDetail> _questionDetail(String id, {String? attemptId}) async {
    final q = await (db.select(
      db.practiceQuestions,
    )..where((q) => q.id.equals(id) & q.deleted.equals(false))).getSingle();
    final options =
        await (db.select(db.practiceOptions)
              ..where((o) => o.questionId.equals(id))
              ..orderBy([(o) => OrderingTerm.asc(o.position)]))
            .get();
    final keys =
        await (db.select(db.practiceAnswerKeys)
              ..where((a) => a.questionId.equals(id))
              ..orderBy([(a) => OrderingTerm.asc(a.position)]))
            .get();
    final answers = <List<String>>[];
    for (final k in keys) {
      while (answers.length <= k.position) {
        answers.add([]);
      }
      answers[k.position].add(k.answer);
    }
    final topics = await db
        .customSelect(
          "SELECT t.name FROM learning_topics t JOIN practice_question_topics l ON t.id=l.topic_id WHERE l.question_id=?",
          variables: [Variable(id)],
        )
        .get();
    // The visual reference lives in the link table, not on the question
    // row: load it before building the spec, so visual-answer kinds
    // (which require a visual) validate on read-back.
    final visualJoin = db.select(db.visualScenes).join([
      innerJoin(
        db.visualQuestionLinks,
        db.visualQuestionLinks.visualId.equalsExp(db.visualScenes.id),
      ),
    ]);
    visualJoin.where(db.visualQuestionLinks.questionId.equals(id));
    visualJoin.orderBy([OrderingTerm.asc(db.visualScenes.createdAt)]);
    final allVisualRows = await visualJoin.get();
    final solutionVisualLinks = [
      for (final r in allVisualRows)
        if (r.readTable(db.visualQuestionLinks).role == "solution")
          (
            visualId: r.readTable(db.visualQuestionLinks).visualId,
            revision: r.readTable(db.visualQuestionLinks).revision,
          ),
    ];
    final visualLinks = allVisualRows
        .where((r) => r.readTable(db.visualQuestionLinks).role == "question")
        .map(
          (r) => (
            visualId: r.readTable(db.visualQuestionLinks).visualId,
            revision: r.readTable(db.visualQuestionLinks).revision,
          ),
        )
        .toList();
    final spec = QuestionSpec(
      kind: q.kind,
      stem: q.stem,
      subject: q.subject,
      options: {for (final o in options) o.optionId: o.content},
      answers: answers,
      explanation: q.explanation,
      hint: q.hint,
      topics: topics.map((t) => t.read<String>("name")).toList(),
      absoluteTolerance: q.absoluteTolerance,
      relativeTolerance: q.relativeTolerance,
      caseSensitive: q.caseSensitive,
      timeLimitSeconds: q.timeLimitSeconds,
      visualId: visualLinks.isNotEmpty ? visualLinks.first.visualId : null,
      visualRevision: visualLinks.isNotEmpty
          ? visualLinks.first.revision
          : null,
      solutionVisualId: solutionVisualLinks.firstOrNull?.visualId,
      solutionVisualRevision: solutionVisualLinks.firstOrNull?.revision,
    );
    spec.validate();
    final storedAttempts =
        await (db.select(db.practiceAttempts)
              ..where((a) => a.questionId.equals(id))
              ..orderBy([(a) => OrderingTerm.desc(a.rowId)])
              ..limit(50))
            .get();
    final attempts = List<PracticeAttempt>.of(storedAttempts);
    if (attemptId != null) {
      final focused =
          await (db.select(
                db.practiceAttempts,
              )..where((a) => a.id.equals(attemptId) & a.questionId.equals(id)))
              .getSingle();
      attempts.removeWhere((a) => a.id == attemptId);
      attempts.insert(0, focused);
      if (attempts.length > 50) attempts.removeLast();
    }
    final responses = <String, List<String>>{};
    if (attempts.isNotEmpty) {
      final rows =
          await (db.select(db.practiceResponses)
                ..where((r) => r.attemptId.isIn(attempts.map((a) => a.id)))
                ..orderBy([(r) => OrderingTerm.asc(r.position)]))
              .get();
      for (final r in rows) {
        responses.putIfAbsent(r.attemptId, () => []).add(r.answer);
      }
    }
    return QuestionDetail(
      q,
      spec,
      attempts,
      responses,
      await (db.select(
        db.practiceImages,
      )..where((a) => a.questionId.equals(id))).get(),
      visualLinks,
      solutionVisualLinks,
    );
  }
}
