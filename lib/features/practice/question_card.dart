import '../scratchpad/scratchpad_screen.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/image_viewer.dart';
import '../../core/ui/learning_markdown.dart';
import '../../core/visual/model/visual_scene.dart';
import '../../core/visual/render/visual_animator.dart';
import '../../core/visual/render/visual_painter.dart';
import '../review/review_screen.dart';
import '../visual/visual_card.dart';
import '../visual/visual_providers.dart';
import 'practice_providers.dart';
import 'practice_store.dart';
import 'question_localization.dart';
import 'question_spec.dart';
import '../chat/message_reasoning.dart';

class MessageQuestions extends ConsumerWidget {
  const MessageQuestions(this.messageId, {super.key});
  final String messageId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(messageQuestionsProvider(messageId))
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => Text(context.l10n.couldNotReadThePractice),
        data: (rows) => Column(
          children: [
            for (final q in rows)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: QuestionCard(
                  q.id,
                  showReasoning: false,
                  key: ValueKey(q.id),
                ),
              ),
          ],
        ),
      );
}

class QuestionCard extends ConsumerStatefulWidget {
  const QuestionCard(
    this.id, {
    this.attemptId,
    this.showReasoning = true,
    super.key,
  });
  final bool showReasoning;
  final String id;
  final String? attemptId;
  @override
  ConsumerState<QuestionCard> createState() => _QuestionCardState();
}

enum _QuestionFailure { load, draft }

class _QuestionCardState extends ConsumerState<QuestionCard> {
  QuestionDetail? d;
  _QuestionFailure? failure;

  String _failureText(BuildContext context) => switch (failure!) {
    _QuestionFailure.load => context.l10n.thisQuestionCannotBeRead,
    _QuestionFailure.draft => context.l10n.couldNotSaveTheDraft,
  };
  bool busy = true;
  List<String> answers = [];
  Future<void> _writes = Future.value();
  final controllers = <TextEditingController>[];
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool retry = false}) async {
    try {
      final store = ref.read(practiceStoreProvider);
      if (widget.attemptId == null) await store.begin(widget.id, retry: retry);
      final value = await store.detail(widget.id, attemptId: widget.attemptId);
      if (!mounted) return;
      for (final c in controllers) {
        c.dispose();
      }
      controllers.clear();
      d = value;
      answers = List.of(value.responses[value.latest!.id] ?? []);
      if ([
        'point_select',
        'region_select',
        'drag_to_target',
      ].contains(value.spec.kind)) {
        // Tap/drag-to-answer: one slot, no text controllers — the visual
        // itself is the control.
        answers = [answers.isNotEmpty ? answers.first : ''];
      } else if (![
        'single_choice',
        'multiple_choice',
        'true_false',
      ].contains(value.spec.kind)) {
        answers = List.generate(
          value.spec.responseCount,
          (i) => i < answers.length ? answers[i] : '',
        );
        controllers.addAll(answers.map((a) => TextEditingController(text: a)));
      }
      setState(() {
        busy = false;
        failure = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          failure = _QuestionFailure.load;
          busy = false;
        });
      }
    }
  }

  void _save() {
    final snapshot = List<String>.of(answers);
    final id = d!.latest!.id;
    final store = ref.read(practiceStoreProvider);
    _writes = store.draft(id, snapshot).catchError((Object e) {
      if (mounted) setState(() => failure = _QuestionFailure.draft);
    });
  }

  /// A tap on the question's visual selects the answer: a point's
  /// coordinates for point-select, the tapped region's id for
  /// region-select. The draft is saved so the selection survives reload.
  void _selectVisualAnswer(String response) {
    setState(() {
      answers = [response];
    });
    _save();
  }

  /// A drag on the question's visual moves the answer without saving
  /// on every pointer move; the caller saves the draft when the drag
  /// ends (see the `onDragEnd` passed to [_QuestionVisual]).
  void _updateVisualAnswer(String response) {
    setState(() {
      answers = [response];
    });
  }

  Future<void> _action(Future<void> Function() fn) async {
    if (busy) return;
    setState(() => busy = true);
    await act(context, () async {
      await _writes;
      await fn();
    });
    if (mounted) await _load();
  }

  Future<void> _showZoomedImage(
    BuildContext context,
    List<PracticeImage> images,
    int index,
  ) {
    final files = ref.read(appControllerProvider).files;
    return showImageViewer(
      context,
      images: [
        for (final image in images)
          ImageViewerItem(
            file: files.resolve(image.relativePath),
            heroTag: 'question-image-${image.id}',
            cacheWidth: 1600,
            errorText: context.l10n.couldNotDecodeTheQuestion,
          ),
      ],
      initialIndex: index,
      title: context.l10n.questionImage,
    );
  }

  @override
  Widget build(BuildContext context) {
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
    final editable = a.status == 'draft';
    final graded = a.status == 'graded';
    final store = ref.read(practiceStoreProvider),
        c = ref.read(appControllerProvider);
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: Key('quiz-${widget.id}'),
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
                '${questionKindLabel(context, q.kind)} · ${context.subjectName(q.subject)}',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                detail.row.verification == 'unverified'
                    ? (detail.row.origin == 'ai'
                          ? context.l10n.aiReferenceAnswerNeedsChecking
                          : context.l10n.referenceMaterialSelfAssessed)
                    : detail.row.origin == 'template'
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
            child: ScratchpadButton('practice:${widget.id}'),
          ),
          for (final link in detail.visualLinks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuestionVisual(
                link: link,
                kind: q.kind,
                options: q.options,
                selected: answers.isNotEmpty ? answers.first : '',
                onSelect: editable ? _selectVisualAnswer : null,
                onDragPosition: editable ? _updateVisualAnswer : null,
                onDragEnd: editable ? _save : null,
              ),
            ),
          LearningMarkdown(q.stem),
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
                  tag: 'question-image-${image.id}',
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
                q.topics.join(' · '),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 8),
          // Visual-answer kinds use the visual itself as the control:
          // tapping the figure selects the answer, so the option rows
          // never render for them.
          if (!['point_select', 'region_select'].contains(q.kind))
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
                    key: Key('option-${e.key}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: !editable || busy
                        ? null
                        : () {
                            setState(() {
                              if (q.kind == 'multiple_choice') {
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
                                      : q.kind == 'multiple_choice'
                                      ? Icons.check_box_outline_blank
                                      : Icons.radio_button_off)
                                : q.kind == 'multiple_choice'
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
                            e.key == 'true' || e.key == 'false'
                                ? ''
                                : '${e.key}. ',
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
                key: Key('quiz-answer-$i'),
                controller: controllers[i],
                enabled: !busy,
                readOnly: !editable,
                keyboardType: q.kind == 'numeric'
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : null,
                minLines: q.kind == 'short_answer' ? 3 : 1,
                maxLines: q.kind == 'short_answer' ? 8 : 2,
                decoration: InputDecoration(
                  labelText: q.kind == 'fill_blank'
                      ? context.l10n.blank(l10nArgument((i + 1)))
                      : q.kind == 'numeric'
                      ? context.l10n.numericalAnswerFractionsAccepted
                      : context.l10n.myIndependentAnswer,
                ),
                onChanged: (v) {
                  answers[i] = v;
                  _save();
                },
              ),
            ),
          if (a.hintUsed && q.hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: LearningMarkdown('提示：${q.hint}'),
            ),
          if (failure != null)
            Text(_failureText(context), style: TextStyle(color: colors.error)),
          if (editable)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton(
                  key: const Key('submit-quiz'),
                  onPressed: busy
                      ? null
                      : () => _action(() async {
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
                        : () => _action(() => store.useHint(a.id)),
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
            if (a.gradingBasis == 'ai_reference')
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
            if (graded)
              Text(
                context.l10n.seconds(
                  l10nArgument(
                    (a.hintUsed
                        ? context.l10n.usedAHint
                        : context.l10n.noHintUsed),
                  ),
                  l10nArgument(
                    (a.gradingBasis == 'self'
                        ? context.l10n.selfAssessed
                        : context.l10n.ruleBasedJudgment),
                  ),
                  l10nArgument((((a.elapsedMilliseconds ?? 0) / 1000).round())),
                ),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            if (a.status == 'awaiting_self_grade')
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => _action(() async {
                            await store.selfGrade(a.id, true);
                          }),
                    child: Text(context.l10n.iSolvedItIndependently),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _action(() async {
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
                            if (context.mounted) context.go('/chat');
                          }),
                    child: Text(context.l10n.explanationAndVariation),
                  ),
                  if (detail.row.origin == 'ai' &&
                      detail.row.verification == 'unverified')
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
            onPressed: () => context.go('/practice/${widget.id}/history'),
            child: Text(context.l10n.viewAllAttempts),
          ),
          if (detail.row.parentQuestionId != null)
            TextButton(
              onPressed: () =>
                  context.go('/practice/${detail.row.parentQuestionId}'),
              child: Text(
                detail.row.origin == 'ai'
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
                  (a) => a.status == 'graded',
                ))
                  ListTile(
                    dense: true,
                    title: Text(
                      '${l10nArgument(old.submittedAt?.toLocal().toString().substring(0, 16))} · ${l10nArgument(old.correct == true ? context.l10n.correct : context.l10n.correctionRequired)}${l10nArgument(old.hintUsed ? context.l10n.hintUsedSuffix : '')}',
                    ),
                    subtitle: Text(
                      context.l10n.myAnswerBasis(
                        l10nArgument(
                          ((detail.responses[old.id] ?? []).join('；')),
                        ),
                        l10nArgument(
                          (old.gradingBasis == 'ai_reference'
                              ? context.l10n.aiReferenceAwaitingVerification
                              : old.gradingBasis == 'self'
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

/// Countdown label for a timed question. It owns its own one-second timer
/// so only this text rebuilds, instead of the whole question card (with all
/// its Markdown and math parsing) ticking every second.
class _RemainingTime extends StatefulWidget {
  const _RemainingTime({required this.limitSeconds, required this.startedAt});
  final int limitSeconds;
  final DateTime startedAt;
  @override
  State<_RemainingTime> createState() => _RemainingTimeState();
}

class _RemainingTimeState extends State<_RemainingTime> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        ((widget.limitSeconds * 1000 -
                    DateTime.now()
                        .difference(widget.startedAt)
                        .inMilliseconds) /
                1000)
            .ceil()
            .clamp(0, widget.limitSeconds);
    return Text(
      context.l10n.suggestedTimeRemainingSNo(l10nArgument((remaining))),
    );
  }
}

/// One pinned visual of a question: the scene snapshotted at the linked
/// revision, never the scene's current state. A missing or unparsable
/// snapshot renders nothing — it must never break the question.
///
/// For visual-answer kinds ([QuestionSpec] `point_select` /
/// `region_select`) the card itself is the answer control while the
/// question is editable: tapping it selects the answer ([onSelect]),
/// instead of opening fullscreen. A tap outside every region selects
/// nothing. For `drag_to_target` the card is draggable instead: the
/// dragged point's position is the answer, reported live through
/// [onDragPosition] and saved when the drag ends ([onDragEnd]). The
/// fullscreen page stays view-only.
class _QuestionVisual extends ConsumerStatefulWidget {
  const _QuestionVisual({
    required this.link,
    required this.kind,
    required this.options,
    required this.selected,
    this.onSelect,
    this.onDragPosition,
    this.onDragEnd,
  });
  final ({String visualId, int revision}) link;
  final String kind;
  final Map<String, String> options;

  /// The current single-slot answer, or '' when nothing is selected.
  final String selected;

  /// Set while the question is editable; null renders the plain card.
  final ValueChanged<String>? onSelect;

  /// Live drag positions (drag-to-target only); the caller saves on
  /// [onDragEnd] instead of on every move.
  final ValueChanged<String>? onDragPosition;

  /// Called when a drag finishes (drag-to-target only).
  final VoidCallback? onDragEnd;

  @override
  ConsumerState<_QuestionVisual> createState() => _QuestionVisualState();
}

class _QuestionVisualState extends ConsumerState<_QuestionVisual> {
  /// Drag positions from this session (element id → model coordinates).
  final _pointOverrides = <String, ui.Offset>{};

  @override
  void didUpdateWidget(covariant _QuestionVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    // "Try again" starts a new attempt on the same question id, so this
    // state object is reused (QuestionCard's key is `quiz-<questionId>`).
    // A fresh attempt has no answer yet: drop the previous attempt's
    // drag positions, or the point would sit at the old answer while the
    // answer slot is empty (and submitting would then report "no answer"
    // under a figure that clearly shows one).
    if (widget.selected.isEmpty && oldWidget.selected.isNotEmpty) {
      _pointOverrides.clear();
    }
  }

  /// Overrides for the card: this session's drags, or — on first render
  /// with a saved answer — the stored position, so a reloaded question
  /// shows the point where the student left it.
  Map<String, ui.Offset> _dragOverrides(VisualScene scene) {
    if (_pointOverrides.isNotEmpty) return _pointOverrides;
    final saved = parseVisualPoint(widget.selected);
    if (saved == null) return _pointOverrides;
    for (final element in scene.elements) {
      if (element is PointElement &&
          element.draggable &&
          element.at.isLiteral) {
        return {element.id: ui.Offset(saved.$1, saved.$2)};
      }
    }
    return _pointOverrides;
  }

  /// The selected point for point-select questions, in model
  /// coordinates, or null when nothing is selected (yet).
  ui.Offset? _selectedPoint() {
    final saved = parseVisualPoint(widget.selected);
    if (saved == null) return null;
    return ui.Offset(saved.$1, saved.$2);
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(_questionVisualProvider(widget.link))
      .when(
        data: (scene) {
          if (scene == null) return const SizedBox.shrink();
          final answerable =
              (widget.kind == 'point_select' ||
                  widget.kind == 'region_select') &&
              widget.onSelect != null;
          final draggable =
              widget.kind == 'drag_to_target' && widget.onSelect != null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              VisualCard(
                scene: scene,
                onTapModelPoint: answerable
                    ? (point) {
                        if (widget.kind == 'point_select') {
                          widget.onSelect!('${point.dx},${point.dy}');
                        } else {
                          // Region picking uses the same t=0 frame the
                          // card renders: a region hidden by the first
                          // teaching step cannot be selected.
                          final region = visualRegionAtPoint(
                            scene,
                            point,
                            visualInitialParameters(scene),
                            hiddenElementIds: resolveVisualFrame(
                              scene,
                              0,
                            ).hiddenElementIds,
                          );
                          if (region != null) widget.onSelect!(region);
                        }
                      }
                    : null,
                dragEnabled: draggable,
                // The point renders at the student's answer even when
                // the question is no longer editable (graded view):
                // gating overrides on `draggable` would snap it back
                // to the scene's original position.
                pointOverrides: widget.kind == 'drag_to_target'
                    ? _dragOverrides(scene)
                    : const {},
                onDragUpdate: draggable
                    ? (id, position) {
                        setState(() => _pointOverrides[id] = position);
                        widget.onDragPosition?.call(
                          '${position.dx},${position.dy}',
                        );
                      }
                    : null,
                onDragEnd: draggable ? (_) => widget.onDragEnd?.call() : null,
                // The answer marker/highlight renders in the graded
                // view too, so the student's own answer stays visible
                // on the figure after submission.
                selectedPoint: widget.kind == 'point_select'
                    ? _selectedPoint()
                    : null,
                selectedRegionId:
                    widget.kind == 'region_select' && widget.selected.isNotEmpty
                    ? widget.selected
                    : null,
              ),
              // Show the selection whenever one exists, including in
              // the graded view (where `onSelect` is null). The kind
              // gate matters: other kinds (e.g. `read_value`, whose
              // answer is typed) share this widget and must not get a
              // "selected point" line for their option key / value.
              if (const {
                    'point_select',
                    'region_select',
                    'drag_to_target',
                  }.contains(widget.kind) &&
                  widget.selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    widget.kind == 'region_select'
                        ? context.l10n.visualAnswerSelectedRegion(
                            l10nArgument(
                              widget.options[widget.selected] ??
                                  widget.selected,
                            ),
                          )
                        : context.l10n.visualAnswerSelectedPoint(
                            l10nArgument(_formatPoint(widget.selected)),
                          ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const SizedBox.shrink(),
      );

  /// A stored `"x,y"` answer, shown with two decimals.
  String _formatPoint(String value) {
    final point = parseVisualPoint(value);
    if (point == null) return value;
    return '(${point.$1.toStringAsFixed(2)}, ${point.$2.toStringAsFixed(2)})';
  }
}

final _questionVisualProvider = FutureProvider.autoDispose
    .family<VisualScene?, ({String visualId, int revision})>((ref, link) async {
      final json = await ref
          .watch(visualStoreProvider)
          .getRevisionSceneJson(link.visualId, link.revision);
      if (json == null) return null;
      return VisualScene.fromJson(jsonDecode(json) as Map<String, dynamic>);
    });
