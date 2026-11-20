part of "practice_screen.dart";

class QuestionEditor extends ConsumerStatefulWidget {
  const QuestionEditor({this.initial, super.key});
  final QuestionDetail? initial;
  @override
  ConsumerState<QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends ConsumerState<QuestionEditor> {
  final stem = TextEditingController(),
      options = TextEditingController(),
      answers = TextEditingController(),
      explanation = TextEditingController(),
      subject = TextEditingController(text: "数学"),
      hint = TextEditingController(),
      topics = TextEditingController(),
      absoluteTolerance = TextEditingController(text: "0.000001"),
      relativeTolerance = TextEditingController(text: "0"),
      timeLimit = TextEditingController();
  bool caseSensitive = true;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) {
      // New question: default to the global subject filter, else 数学.
      final filter = ref.read(appControllerProvider).subjectFilter;
      if (filter.isNotEmpty) subject.text = filter;
      return;
    }
    final q = initial.spec;
    kind = q.kind;
    stem.text = q.stem;
    subject.text = q.subject;
    explanation.text = q.explanation;
    hint.text = q.hint;
    topics.text = q.topics.join("、");
    final ids = q.options.keys.toList();
    options.text = q.options.values.join("\n");
    final map = {
      for (var i = 0; i < ids.length; i++) ids[i]: String.fromCharCode(65 + i),
    };
    answers.text = q.answers
        .map(
          (a) => a
              .map(
                (v) => kind == "single_choice" || kind == "multiple_choice"
                    ? map[v] ?? v
                    : v,
              )
              .join("|"),
        )
        .join("\n");
    absoluteTolerance.text = "${q.absoluteTolerance}";
    relativeTolerance.text = "${q.relativeTolerance}";
    timeLimit.text = q.timeLimitSeconds?.toString() ?? "";
    caseSensitive = q.caseSensitive;
  }

  String kind = "single_choice";
  bool saving = false;
  Object? failure;
  @override
  void dispose() {
    for (final c in [
      stem,
      options,
      answers,
      explanation,
      subject,
      hint,
      topics,
      absoluteTolerance,
      relativeTolerance,
      timeLimit,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final lines = options.text
          .split("\n")
          .where((v) => v.trim().isNotEmpty)
          .toList();
      final choice = [
        "single_choice",
        "multiple_choice",
        "true_false",
        "region_select",
      ].contains(kind);
      final regionIds =
          widget.initial?.spec.options.keys.toList() ?? <String>[];
      if (kind == "region_select" && lines.length != regionIds.length) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidQuestionOptionsAnswersOrArguments,
          "区域名称数量必须与原图区域一致。",
        );
      }
      final spec = QuestionSpec(
        kind: kind,
        stem: stem.text,
        subject: subject.text.trim(),
        visualId: widget.initial?.spec.visualId,
        visualRevision: widget.initial?.spec.visualRevision,
        solutionVisualId: widget.initial?.spec.solutionVisualId,
        solutionVisualRevision: widget.initial?.spec.solutionVisualRevision,
        options: !choice
            ? {}
            : kind == "region_select"
            ? {
                for (var i = 0; i < lines.length; i++)
                  regionIds[i]: lines[i].trim(),
              }
            : kind == "true_false"
            ? {"true": "正确", "false": "错误"}
            : {
                for (var i = 0; i < lines.length; i++)
                  String.fromCharCode(65 + i): lines[i].trim(),
              },
        answers: answers.text
            .split("\n")
            .where((v) => v.trim().isNotEmpty)
            .map((v) => v.split("|").map((s) => s.trim()).toList())
            .toList(),
        explanation: explanation.text,
        hint: hint.text,
        absoluteTolerance:
            double.tryParse(absoluteTolerance.text.trim()) ?? double.nan,
        relativeTolerance:
            double.tryParse(relativeTolerance.text.trim()) ?? double.nan,
        timeLimitSeconds: timeLimit.text.trim().isEmpty
            ? null
            : int.tryParse(timeLimit.text.trim()) ?? -1,
        caseSensitive: caseSensitive,
        topics: topics.text
            .split("、")
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList(),
      );
      final store = ref.read(practiceStoreProvider), old = widget.initial;
      final id = old == null
          ? await store.create(spec)
          : await store.revise(old.row.id, spec);
      if (mounted) {
        Navigator.pop(context);
        context.go("/practice/$id");
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => failure = e is FormatException
              ? e
              : const AppFormatException(
                  AppErrorCode.errorSaveCheckStorage,
                  "保存失败，请检查存储空间。",
                ),
        );
      }
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null
          ? context.l10n.addPracticeQuestion
          : context.l10n.reviseQuestionKeepOriginal,
    ),
    scrollable: true,
    content: SizedBox(
      width: 600,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSelectField<String>(
            initialValue: kind,
            decoration: InputDecoration(labelText: context.l10n.questionType),
            items: questionKinds.entries
                .where(
                  (e) =>
                      (widget.initial?.spec.visualId != null ||
                          !const {
                            "point_select",
                            "region_select",
                            "drag_to_target",
                            "read_value",
                          }.contains(e.key)) &&
                      // The editor can rename existing regions, not add
                      // geometry or invent region IDs for another kind.
                      (e.key != "region_select" ||
                          widget.initial?.spec.kind == "region_select"),
                )
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(questionKindLabel(context, e.key)),
                  ),
                )
                .toList(),
            onChanged: saving
                ? null
                : (v) => setState(() {
                    kind = v!;
                    // The true/false answer control only accepts 'true' /
                    // 'false'; drop a stale free-text answer from another
                    // kind so the dropdown starts empty instead of invalid.
                    if (kind == "true_false" &&
                        answers.text.trim() != "true" &&
                        answers.text.trim() != "false") {
                      answers.text = "";
                    }
                  }),
          ),
          for (final (ctrl, label, lines) in [
            (subject, context.l10n.subject, 1),
            (stem, context.l10n.questionMarkdownAndMathSupported, 3),
            if ([
              "single_choice",
              "multiple_choice",
              "region_select",
            ].contains(kind))
              (
                options,
                kind == "region_select"
                    ? context.l10n.visualRegionOptions
                    : context.l10n.optionsOnePerLineNumbered,
                3,
              ),
            (
              answers,
              kind == "true_false"
                  ? context.l10n.answerTrueOrFalse
                  : kind == "fill_blank"
                  ? context.l10n.oneBlankPerLineSeparate
                  : kind == "multiple_choice"
                  ? context.l10n.oneCorrectOptionLetterPer
                  : kind == "region_select"
                  ? context.l10n.visualRegionAnswer
                  : kind == "point_select" || kind == "drag_to_target"
                  ? context.l10n.visualCoordinateAnswer
                  : kind == "short_answer"
                  ? context.l10n.referenceAnswerOptionalSelfAssess
                  : context.l10n.correctAnswerOptionLetterOr,
              2,
            ),
            (explanation, context.l10n.explanation, 3),
            (hint, context.l10n.hintOptional, 2),
            (topics, context.l10n.knowledgePointsSeparateWith, 1),
          ])
            Padding(
              padding: const EdgeInsets.only(top: 12),
              // True/false answers are a choice, not free text: typing
              // literal "true"/"false" is error-prone and only surfaces
              // at save time.
              child: ctrl == answers && kind == "true_false"
                  ? AppSelectField<String>(
                      initialValue:
                          ["true", "false"].contains(answers.text.trim())
                          ? answers.text.trim()
                          : null,
                      decoration: InputDecoration(
                        labelText: context.l10n.answer,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: "true",
                          child: Text(context.l10n.correct),
                        ),
                        DropdownMenuItem(
                          value: "false",
                          child: Text(context.l10n.error),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (v) => setState(() => answers.text = v ?? ""),
                    )
                  : TextField(
                      controller: ctrl,
                      key: ctrl == stem
                          ? const Key("question-stem")
                          : ctrl == answers
                          ? const Key("question-answers")
                          : null,
                      enabled: !saving,
                      minLines: lines,
                      maxLines: lines + 3,
                      decoration: InputDecoration(
                        labelText: label,
                        suffixIcon:
                            {stem, options, explanation, hint}.contains(ctrl)
                            ? MarkdownFullscreenButton(
                                key: ValueKey(
                                  'practice-markdown-${ctrl == stem
                                      ? 'stem'
                                      : ctrl == options
                                      ? 'options'
                                      : ctrl == hint
                                      ? 'hint'
                                      : 'explanation'}',
                                ),
                                controller: ctrl,
                                title: label,
                                enabled: !saving,
                              )
                            : null,
                        helperText: ctrl == options && kind == "region_select"
                            ? widget.initial?.spec.options.keys.join(" · ")
                            : null,
                        helperMaxLines: 6,
                      ),
                    ),
            ),
          ExpansionTile(
            title: Text(context.l10n.gradingAndTimeSettings),
            tilePadding: EdgeInsets.zero,
            children: [
              if ([
                "numeric",
                "read_value",
                "point_select",
                "drag_to_target",
              ].contains(kind)) ...[
                TextField(
                  controller: absoluteTolerance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.absoluteTolerance0100,
                  ),
                ),
                if (kind == "numeric" || kind == "read_value") ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: relativeTolerance,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.l10n.relativeTolerance001,
                    ),
                  ),
                ],
              ],
              if (kind == "fill_blank")
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.caseSensitiveAnswers),
                  value: caseSensitive,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => caseSensitive = v),
                ),
              TextField(
                controller: timeLimit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.suggestedTimeInSecondsOptional,
                ),
              ),
            ],
          ),
          if (widget.initial != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                context.l10n.saveAsANewVersion,
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (failure != null)
            Text(
              failureText(context.l10n, failure!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          Text(
            context.l10n.checkTheQuestionAndAnswer,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(
          saving ? context.l10n.savingEllipsis : context.l10n.saveQuestion,
        ),
      ),
    ],
  );
}
