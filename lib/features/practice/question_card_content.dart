part of "question_card.dart";

extension _QuestionCardContent on _QuestionCardState {
  Widget _buildQuestion(BuildContext context, {bool fullscreen = false}) {
    if (d == null) {
      if (failure == null) return const LinearProgressIndicator();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_failureText(context)),
          const SizedBox(height: 8),
          TextButton(onPressed: () => _load(), child: Text(context.l10n.retry)),
        ],
      );
    }
    final detail = d!, q = detail.spec, a = detail.latest!;
    final editable = a.status == "draft";
    final graded = a.status == "graded";
    final store = ref.read(practiceStoreProvider),
        c = ref.read(appControllerProvider);
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: Key("quiz-${widget.id}"),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                "${questionKindLabel(context, q.kind)} · ${context.subjectName(q.subject)}",
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                detail.row.verification == "unverified"
                    ? (detail.row.origin == "ai"
                          ? context.l10n.aiReferenceAnswerNeedsChecking
                          : context.l10n.referenceMaterialSelfAssessed)
                    : detail.row.origin == "template"
                    ? context.l10n.verifiedBasicPractice
                    : context.l10n.answerCheckedByUser,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (q.timeLimitSeconds != null)
                editable
                    ? _RemainingTime(
                        limitSeconds: q.timeLimitSeconds!,
                        startedAt: a.startedAt,
                      )
                    : Text(
                        context.l10n.suggestedTimeS(
                          l10nArgument((q.timeLimitSeconds)),
                        ),
                      ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ScratchpadButton("practice:${widget.id}"),
          ),
          if (fullscreen) LearningMarkdown(q.stem),
          for (final link in detail.visualLinks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuestionVisual(
                link: link,
                kind: q.kind,
                options: q.options,
                selected: answers.isNotEmpty ? answers.first : "",
                onSelect: editable && !busy ? _selectVisualAnswer : null,
                onDragPosition: editable && !busy ? _updateVisualAnswer : null,
                onDragEnd: editable && !busy ? _save : null,
                onFullscreen: fullscreen ? null : _openFullscreen,
                fullscreen: fullscreen,
              ),
            ),
          if (!fullscreen) LearningMarkdown(q.stem),
          if (widget.showReasoning && detail.row.sourceMessageId != null)
            SourceReasoning(detail.row.sourceMessageId!),
          for (final image in detail.images)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: GestureDetector(
                onTap: () => _showZoomedImage(
                  context,
                  detail.images,
                  detail.images.indexWhere((i) => i.id == image.id),
                ),
                child: Hero(
                  tag: "question-image-${image.id}",
                  child: Image.file(
                    c.files.resolve(image.relativePath),
                    height: 240,
                    fit: BoxFit.contain,
                    cacheWidth: 1000,
                    errorBuilder: (_, _, _) =>
                        Text(context.l10n.couldNotDecodeTheQuestion),
                  ),
                ),
              ),
            ),
          if (q.topics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                q.topics.join(" · "),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 8),
          // Visual-answer kinds use the visual itself as the control:
          // tapping the figure selects the answer, so the option rows
          // never render for them.
          if (!["point_select", "region_select"].contains(q.kind))
            for (final e in q.options.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  // After grading, mark the outcome on the options themselves:
                  // correct options get a primary tint with a check, a wrong
                  // pick gets an error tint with a cross. Before grading the
                  // row only shows the user's selection, as before.
                  color: graded
                      ? (q.answers.expand((a) => a).contains(e.key)
                            ? colors.primaryContainer
                            : answers.contains(e.key)
                            ? colors.errorContainer
                            : colors.surfaceContainerLow)
                      : answers.contains(e.key)
                      ? colors.primaryContainer.withValues(alpha: .5)
                      : colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: Key("option-${e.key}"),
                    borderRadius: BorderRadius.circular(10),
                    onTap: !editable || busy
                        ? null
                        : () {
                            setState(() {
                              if (q.kind == "multiple_choice") {
                                answers.contains(e.key)
                                    ? answers.remove(e.key)
                                    : answers.add(e.key);
                              } else {
                                answers = [e.key];
                              }
                            });
                            _save();
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            graded
                                ? (q.answers.expand((a) => a).contains(e.key)
                                      ? Icons.check_circle
                                      : answers.contains(e.key)
                                      ? Icons.cancel
                                      : q.kind == "multiple_choice"
                                      ? Icons.check_box_outline_blank
                                      : Icons.radio_button_off)
                                : q.kind == "multiple_choice"
                                ? (answers.contains(e.key)
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank)
                                : (answers.contains(e.key)
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off),
                            color: graded
                                ? (q.answers.expand((a) => a).contains(e.key)
                                      ? colors.primary
                                      : answers.contains(e.key)
                                      ? colors.error
                                      : colors.onSurfaceVariant)
                                : colors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            e.key == "true" || e.key == "false"
                                ? ""
                                : "${e.key}. ",
                          ),
                          Expanded(
                            child: IgnorePointer(
                              child: LearningMarkdown(e.value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          for (var i = 0; i < controllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                key: Key("quiz-answer-$i"),
                controller: controllers[i],
                enabled: !busy,
                readOnly: !editable,
                keyboardType: q.kind == "numeric" || q.kind == "read_value"
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : null,
                minLines: q.kind == "short_answer" ? 3 : 1,
                maxLines: q.kind == "short_answer" ? 8 : 2,
                decoration: InputDecoration(
                  labelText: q.kind == "fill_blank"
                      ? context.l10n.blank(l10nArgument((i + 1)))
                      : q.kind == "numeric"
                      ? context.l10n.numericalAnswerFractionsAccepted
                      : context.l10n.myIndependentAnswer,
                ),
                onChanged: (v) {
                  setState(() => answers[i] = v);
                  _save();
                },
              ),
            ),
          if (a.hintUsed && q.hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: LearningMarkdown("提示：${q.hint}"),
            ),
          if (failure != null)
            Text(_failureText(context), style: TextStyle(color: colors.error)),
          if (editable)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton(
                  key: const Key("submit-quiz"),
                  onPressed: busy
                      ? null
                      : () => _action(context, () async {
                          await store.submit(a.id, answers);
                        }),
                  child: Text(
                    busy
                        ? context.l10n.savingInProgress
                        : context.l10n.submitAnswer,
                  ),
                ),
                if (q.hint.isNotEmpty && !a.hintUsed)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _action(context, () => store.useHint(a.id)),
                    child: Text(context.l10n.giveMeAHint),
                  ),
              ],
            ),
          if (!editable) ...[
            const Divider(height: 28),
            Text(
              graded
                  ? (a.correct == true
                        ? context.l10n.thisAnswerIsCorrect
                        : context.l10n.thisAnswerNeedsCorrection)
                  : context.l10n.compareWithTheReferenceThen,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (a.gradingBasis == "ai_reference")
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  context.l10n.thisResultUsedTheAI,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 10),
            if (q.answers.isNotEmpty)
              LearningMarkdown(
                '参考答案：${q.answers.map((a) => a.join(' / ')).join('；')}',
              ),
            if (q.explanation.isNotEmpty) LearningMarkdown(q.explanation),
            for (final link in detail.solutionVisualLinks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.visualSolutionFigure,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    _SolutionVisual(link: link),
                  ],
                ),
              ),
            if (graded)
              Text(
                context.l10n.seconds(
                  l10nArgument(
                    (a.hintUsed
                        ? context.l10n.usedAHint
                        : context.l10n.noHintUsed),
                  ),
                  l10nArgument(
                    (a.gradingBasis == "self"
                        ? context.l10n.selfAssessed
                        : context.l10n.ruleBasedJudgment),
                  ),
                  l10nArgument((((a.elapsedMilliseconds ?? 0) / 1000).round())),
                ),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            if (a.status == "awaiting_self_grade")
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => _action(context, () async {
                            await store.selfGrade(a.id, true);
                          }),
                    child: Text(context.l10n.iSolvedItIndependently),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _action(context, () async {
                            await store.selfGrade(a.id, false);
                          }),
                    child: Text(context.l10n.iNeedMorePractice),
                  ),
                ],
              ),
            if (graded)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (widget.attemptId == null)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              await _load(retry: true);
                            },
                      child: Text(context.l10n.tryAgain),
                    ),
                  TextButton(
                    onPressed: c.busy
                        ? null
                        : () => act(context, () async {
                            await c.prepareVariant(detail);
                            if (context.mounted) context.go("/chat");
                          }),
                    child: Text(context.l10n.explanationAndVariation),
                  ),
                  if (detail.row.origin == "ai" &&
                      detail.row.verification == "unverified")
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => act(context, () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(
                                    context.l10n.confirmIndependentVerification,
                                  ),
                                  content: Text(
                                    context.l10n.checkTheQuestionAnswerAnd,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(context.l10n.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(context.l10n.verified),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await store.verify(widget.id);
                                await _load();
                              }
                            }),
                      child: Text(context.l10n.checkReferenceAnswer),
                    ),
                ],
              ),
          ],
          QuestionReviewStatus(widget.id),
          TextButton(
            onPressed: () => context.go("/practice/${widget.id}/history"),
            child: Text(context.l10n.viewAllAttempts),
          ),
          if (detail.row.parentQuestionId != null)
            TextButton(
              onPressed: () =>
                  context.go("/practice/${detail.row.parentQuestionId}"),
              child: Text(
                detail.row.origin == "ai"
                    ? context.l10n.viewSourceQuestion
                    : context.l10n.viewOriginalVersion,
              ),
            ),
          if (detail.attempts.length > 1)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(context.l10n.recentAttemptsUpTo50),
              children: [
                for (final old in detail.attempts.where(
                  (a) => a.status == "graded",
                ))
                  ListTile(
                    dense: true,
                    title: Text(
                      '${l10nArgument(old.submittedAt?.toLocal().toString().substring(0, 16))} · ${l10nArgument(old.correct == true ? context.l10n.correct : context.l10n.correctionRequired)}${l10nArgument(old.hintUsed ? context.l10n.hintUsedSuffix : '')}',
                    ),
                    subtitle: Text(
                      context.l10n.myAnswerBasis(
                        l10nArgument(
                          ((detail.responses[old.id] ?? []).join("；")),
                        ),
                        l10nArgument(
                          (old.gradingBasis == "ai_reference"
                              ? context.l10n.aiReferenceAwaitingVerification
                              : old.gradingBasis == "self"
                              ? context.l10n.selfAssessed
                              : context
                                    .l10n
                                    .deterministicGradingAgainstAVerified),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
