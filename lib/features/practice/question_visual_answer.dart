part of "question_card.dart";

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
/// fullscreen page renders this same attempt via the owning QuestionCard.
class _QuestionVisual extends ConsumerStatefulWidget {
  const _QuestionVisual({
    required this.link,
    required this.kind,
    required this.options,
    required this.selected,
    this.onSelect,
    this.onDragPosition,
    this.onDragEnd,
    this.onFullscreen,
    this.fullscreen = false,
  });
  final VoidCallback? onFullscreen;
  final bool fullscreen;
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
  /// A tap outside every region shows an in-card "please choose" hint.
  /// A SnackBar would queue behind the submit-error SnackBar and hide
  /// the "answer incomplete" feedback on submit.
  var _showRegionHint = false;

  /// Overrides for the card: this session's drags, or — on first render
  /// with a saved answer — the stored position, so a reloaded question
  /// shows the point where the student left it.
  ///
  /// A drag answer carries the dragged element's id (`"id:x,y"`); older
  /// answers are plain `"x,y"` and restore to the first draggable point.
  /// Group children count: a draggable point inside a group restores
  /// exactly like a top-level one.
  Map<String, ui.Offset> _dragOverrides(VisualScene scene) {
    final saved = parseVisualPoint(widget.selected);
    if (saved == null) return const {};
    final position = ui.Offset(saved.$1, saved.$2);
    final points = _draggablePoints(scene);
    final id = _dragAnswerId(widget.selected);
    if (id != null) {
      for (final point in points) {
        if (point.id == id) return {id: position};
      }
    }
    if (points.isNotEmpty) return {points.first.id: position};
    return const {};
  }

  /// Draggable, literal points anywhere in the scene (group children
  /// included), in scene order.
  List<PointElement> _draggablePoints(VisualScene scene) {
    final out = <PointElement>[];
    void visit(List<VisualElement> elements) {
      for (final element in elements) {
        if (element is GroupElement) {
          visit(element.children);
        } else if (element is PointElement &&
            element.draggable &&
            element.at.isLiteral) {
          out.add(element);
        }
      }
    }

    visit(scene.elements);
    return out;
  }

  /// The element id of a drag answer (`"id:x,y"`), or null for a plain
  /// `"x,y"` answer. An id containing a comma cannot be told apart from
  /// a coordinate pair, so it is treated as no id (the restore falls
  /// back to the first draggable point).
  String? _dragAnswerId(String value) {
    final colon = value.indexOf(":");
    if (colon <= 0) return null;
    final id = value.substring(0, colon);
    if (id.contains(",")) return null;
    return id;
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
          final frame = resolveVisualFrame(scene, 0);
          final answerable =
              (widget.kind == "point_select" ||
                  widget.kind == "region_select") &&
              widget.onSelect != null;
          final draggable =
              widget.kind == "drag_to_target" && widget.onSelect != null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              VisualCard(
                scene: scene,
                // A question card's fullscreen is view-only: dragging
                // there must not move the point (and never counts as
                // an answer), so the fullscreen page gets no drag.
                fullscreenAllowDrag: false,
                assessment: true,
                onFullscreen: widget.onFullscreen,
                assessmentFullscreen: widget.fullscreen,
                onTapModelPoint: answerable
                    ? (point) {
                        if (widget.kind == "point_select") {
                          widget.onSelect!("${point.dx},${point.dy}");
                        } else {
                          // Region picking uses the same t=0 frame the
                          // card renders: a region hidden by the first
                          // teaching step cannot be selected.
                          final region = visualRegionAtPoint(
                            scene,
                            point,
                            frame.parameters,
                            toggles: frame.toggles,
                            hiddenElementIds: frame.hiddenElementIds,
                          );
                          if (region != null &&
                              widget.options.containsKey(region)) {
                            setState(() => _showRegionHint = false);
                            widget.onSelect!(region);
                          } else {
                            // A tap outside every region selects nothing:
                            // say so in the card, or the tap looks dead.
                            setState(() => _showRegionHint = true);
                          }
                        }
                      }
                    : null,
                dragEnabled: draggable,
                // The point renders at the student's answer even when
                // the question is no longer editable (graded view):
                // gating overrides on `draggable` would snap it back
                // to the scene's original position.
                pointOverrides: widget.kind == "drag_to_target"
                    ? _dragOverrides(scene)
                    : const {},
                onDragUpdate: draggable
                    ? (id, position) {
                        // The answer carries the dragged element's id,
                        // so a later reload restores the same point
                        // instead of the first draggable one.
                        final view = VisualCoordinateMapper.fromScene(
                          scene,
                          const ui.Size(1, 1),
                        ).modelRect;
                        widget.onDragPosition?.call(
                          "$id:${position.dx.clamp(view.left, view.right)},${position.dy.clamp(view.top, view.bottom)}",
                        );
                      }
                    : null,
                onDragEnd: draggable ? (_) => widget.onDragEnd?.call() : null,
                // The answer marker/highlight renders in the graded
                // view too, so the student's own answer stays visible
                // on the figure after submission.
                selectedPoint: widget.kind == "point_select"
                    ? _selectedPoint()
                    : null,
                selectedRegionId:
                    widget.kind == "region_select" && widget.selected.isNotEmpty
                    ? widget.selected
                    : null,
              ),
              if (widget.kind == "region_select" && _showRegionHint)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(context.l10n.choose),
                ),
              // Show the selection whenever one exists, including in
              // the graded view (where `onSelect` is null). The kind
              // gate matters: other kinds (e.g. `read_value`, whose
              // answer is typed) share this widget and must not get a
              // "selected point" line for their option key / value.
              if (const {
                    "point_select",
                    "region_select",
                    "drag_to_target",
                  }.contains(widget.kind) &&
                  widget.selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    widget.kind == "region_select"
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
    return "(${point.$1.toStringAsFixed(2)}, ${point.$2.toStringAsFixed(2)})";
  }
}

class _SolutionVisual extends ConsumerWidget {
  const _SolutionVisual({required this.link});
  final ({String visualId, int revision}) link;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_questionVisualProvider(link))
      .when(
        data: (scene) =>
            scene == null ? const SizedBox.shrink() : VisualCard(scene: scene),
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => Text(context.l10n.thisQuestionCannotBeRead),
      );
}

final _questionVisualProvider = FutureProvider.autoDispose
    .family<VisualScene?, ({String visualId, int revision})>((ref, link) async {
      final json = await ref
          .watch(visualStoreProvider)
          .getRevisionSceneJson(link.visualId, link.revision);
      if (json == null) return null;
      return VisualScene.fromJson(jsonDecode(json) as Map<String, dynamic>);
    });
