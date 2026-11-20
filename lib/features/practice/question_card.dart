import "../scratchpad/scratchpad_screen.dart";

import "dart:async";
import "dart:convert";
import "dart:ui" as ui;

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../app/controller.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "../../core/ui/image_viewer.dart";
import "../../core/ui/learning_markdown.dart";
import "../../core/visual/model/visual_scene.dart";
import "../../core/visual/render/visual_animator.dart";
import "../../core/visual/render/visual_painter.dart";
import "../review/review_screen.dart";
import "../visual/visual_card.dart";
import "../visual/visual_providers.dart";
import "practice_providers.dart";
import "practice_store.dart";
import "question_localization.dart";
import "question_spec.dart";
import "../chat/message_reasoning.dart";

part "question_visual_answer.dart";

part "question_card_content.dart";

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
  // Both routes render this attempt; opening fullscreen never begins another.
  final _viewChanges = ValueNotifier<int>(0);
  bool _fullscreenOpen = false;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _viewChanges.value++;
  }

  Future<void> _openFullscreen() async {
    if (_fullscreenOpen) return;
    _fullscreenOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (routeContext) => ValueListenableBuilder<int>(
            valueListenable: _viewChanges,
            builder: (_, _, _) => Scaffold(
              appBar: AppBar(
                title: Text(routeContext.l10n.visualAnswerFullscreen),
                leading: IconButton(
                  key: const Key("visual-return-to-answer"),
                  tooltip: routeContext.l10n.visualReturnToAnswer,
                  onPressed: () => Navigator.of(routeContext).pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  child: _buildQuestion(routeContext, fullscreen: true),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      _fullscreenOpen = false;
    }
  }

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
    _viewChanges.dispose();
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
        "point_select",
        "region_select",
        "drag_to_target",
      ].contains(value.spec.kind)) {
        // Tap/drag-to-answer: one slot, no text controllers — the visual
        // itself is the control.
        answers = [answers.isNotEmpty ? answers.first : ""];
      } else if (![
        "single_choice",
        "multiple_choice",
        "true_false",
      ].contains(value.spec.kind)) {
        answers = List.generate(
          value.spec.responseCount,
          (i) => i < answers.length ? answers[i] : "",
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

  Future<void> _action(
    BuildContext actionContext,
    Future<void> Function() fn,
  ) async {
    if (busy) return;
    setState(() => busy = true);
    await act(actionContext, () async {
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
            heroTag: "question-image-${image.id}",
            cacheWidth: 1600,
            errorText: context.l10n.couldNotDecodeTheQuestion,
          ),
      ],
      initialIndex: index,
      title: context.l10n.questionImage,
    );
  }

  @override
  Widget build(BuildContext context) => _buildQuestion(context);
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
