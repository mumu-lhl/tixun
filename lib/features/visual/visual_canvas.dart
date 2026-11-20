part of "visual_card.dart";

/// Presentation-only transform. Answer gestures still use the original canvas
/// mapper after InteractiveViewer inverse-transforms the pointer positions.
class _AssessmentViewport extends StatefulWidget {
  const _AssessmentViewport({required this.expanded, required this.child});
  final bool expanded;
  final Widget child;
  @override
  State<_AssessmentViewport> createState() => _AssessmentViewportState();
}

class _AssessmentViewportState extends State<_AssessmentViewport> {
  final _transform = TransformationController();
  bool _navigate = false;
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.expanded) {
      return AspectRatio(aspectRatio: 4 / 3, child: widget.child);
    }
    return Column(
      children: [
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              key: const Key("visual-navigation-mode"),
              onPressed: () => setState(() => _navigate = !_navigate),
              icon: Icon(_navigate ? Icons.touch_app : Icons.pan_tool),
              label: Text(
                _navigate
                    ? context.l10n.visualAnswerMode
                    : context.l10n.visualMoveView,
              ),
            ),
            IconButton(
              key: const Key("visual-reset-view"),
              tooltip: context.l10n.visualResetView,
              onPressed: () => _transform.value = Matrix4.identity(),
              icon: const Icon(Icons.fit_screen),
            ),
          ],
        ),
        SizedBox(
          height: (MediaQuery.sizeOf(context).height * .6).clamp(240, 720),
          width: double.infinity,
          child: ClipRect(
            child: GestureDetector(
              // Claim navigation pans before the surrounding scroll view.
              onVerticalDragUpdate: !_navigate
                  ? null
                  : (details) {
                      _transform.value =
                          Matrix4.translationValues(0, details.delta.dy, 0) *
                          _transform.value;
                    },

              child: InteractiveViewer(
                transformationController: _transform,
                panEnabled: _navigate,
                minScale: 1,
                maxScale: 4,
                child: IgnorePointer(ignoring: _navigate, child: widget.child),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The paint surface and TeX overlays share a coordinate mapper for hit-testing.
/// Drag callbacks report model positions, and the caller owns mutable overrides.
class _VisualCanvas extends StatefulWidget {
  const _VisualCanvas({
    required this.scene,
    required this.palette,
    required this.parameters,
    required this.toggles,
    this.hiddenElementIds = const {},
    this.pointOverrides = const {},
    this.timeMs = 0,
    this.stepIndex = visualNoStepIndex,
    this.zoom = 1.0,
    this.pan = ui.Offset.zero,
    this.dragEnabled = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onTapModelPoint,
    this.selectedPoint,
    this.selectedRegionId,
  });

  final VisualScene scene;
  final VisualPalette palette;
  final Map<String, double> parameters;
  final Map<String, bool> toggles;

  final Set<String> hiddenElementIds;

  /// Local drag positions (element id → model coordinates).
  final Map<String, ui.Offset> pointOverrides;

  /// Current playback time (only identifies the frame for repaint).
  final double timeMs;

  /// Current teaching step, or [visualNoStepIndex] when none applies.
  final int stepIndex;

  /// Fullscreen pinch zoom (1.0 = fit view) and pan in canvas pixels.
  final double zoom;
  final ui.Offset pan;

  final bool dragEnabled;

  final void Function(String id)? onDragStart;

  final void Function(String id, ui.Offset modelPosition)? onDragUpdate;

  /// Called with the dragged element id when a drag finishes.
  final void Function(String id)? onDragEnd;

  /// Tap-to-answer handler (question cards only): reports the tapped
  /// position in model coordinates. Mutually exclusive with [dragEnabled].
  final ValueChanged<ui.Offset>? onTapModelPoint;

  /// Selected point (point-select answers), in model coordinates:
  /// drawn as a ring on the canvas whether or not the question is
  /// still editable.
  final ui.Offset? selectedPoint;

  /// Selected region (region-select answers): the polygon element id,
  /// drawn highlighted on the canvas.
  final String? selectedRegionId;

  /// Touch hit radius around a draggable point, in logical pixels.
  static const double dragHitRadius = 24;

  @override
  State<_VisualCanvas> createState() => _VisualCanvasState();
}

class _VisualCanvasState extends State<_VisualCanvas> {
  /// Element id being dragged, or null between drags.
  String? _draggingId;

  /// Canvas-space vector from the touch point to the dragged point's
  /// center, captured on drag start so the point does not jump to the
  /// finger.
  ui.Offset _grabOffset = ui.Offset.zero;

  @override
  void dispose() {
    // Removing the canvas may dispose the gesture before its callbacks run.
    // Finish the drag here so the caller can persist the last reported position.
    _endDrag();
    super.dispose();
  }

  /// Draggable, visible, literal points with their current canvas
  /// positions (overrides applied, scene order).
  List<({String id, ui.Offset canvasPos})> _dragCandidates(
    VisualCoordinateMapper mapper,
  ) {
    final out = <({String id, ui.Offset canvasPos})>[];
    for (final element in visualVisibleElements(
      widget.scene,
      widget.toggles,
      widget.hiddenElementIds,
    )) {
      if (element is! PointElement || !element.draggable) continue;
      // `$param`-bound points are never draggable: the validator
      // rejects them, but a scene built in code could still carry one.
      if (!element.at.isLiteral) continue;
      final at =
          widget.pointOverrides[element.id] ??
          resolvePoint(element.at, widget.parameters);
      if (at == null) continue;
      out.add((id: element.id, canvasPos: mapper.modelToCanvas(at)));
    }
    return out;
  }

  /// Canvas path of the selected region polygon, or null when there is
  /// no selection, the polygon is hidden, or a corner cannot be
  /// resolved with the current parameters.
  ui.Path? _selectedRegionPath(VisualCoordinateMapper mapper) {
    final id = widget.selectedRegionId;
    if (id == null) return null;
    for (final element in visualVisibleElements(
      widget.scene,
      widget.toggles,
      widget.hiddenElementIds,
    )) {
      if (element is! PolygonElement || element.id != id) continue;
      final points = <ui.Offset>[];
      for (final p in element.points) {
        final resolved = resolvePoint(p, widget.parameters);
        if (resolved == null) return null;
        points.add(mapper.modelToCanvas(resolved));
      }
      if (points.length < 3) return null;
      final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      return path;
    }
    return null;
  }

  /// Where a label at canvas position [labelAt] should move when it
  /// sits on a dragged point: the override position of that point, or
  /// null when the label is not anchored on any dragged point.
  ui.Offset? _draggedLabelPosition(
    ui.Offset labelAt,
    VisualCoordinateMapper mapper,
  ) {
    for (final entry in widget.pointOverrides.entries) {
      final original = _draggedPointCanvasPos(entry.key, mapper);
      if (original != null && (labelAt - original).distance < 0.5) {
        return mapper.modelToCanvas(entry.value);
      }
    }
    return null;
  }

  /// Canvas position of the draggable point [id] before any override,
  /// or null when it is not a visible literal draggable point.
  ui.Offset? _draggedPointCanvasPos(String id, VisualCoordinateMapper mapper) {
    for (final element in visualVisibleElements(
      widget.scene,
      widget.toggles,
      widget.hiddenElementIds,
    )) {
      if (element is! PointElement || element.id != id) continue;
      if (!element.draggable || !element.at.isLiteral) continue;
      final at = resolvePoint(element.at, widget.parameters);
      if (at == null) continue;
      return mapper.modelToCanvas(at);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tickStyle = Theme.of(context).textTheme.bodySmall;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final mapper = VisualCoordinateMapper.fromScene(
          widget.scene,
          size,
          zoom: widget.zoom,
          pan: widget.pan,
        );
        final labels = mapper.mathLabelPositions(
          widget.scene,
          widget.parameters,
          toggles: widget.toggles,
          hiddenElementIds: widget.hiddenElementIds,
        );
        // Math labels have no explicit point reference. An anchor coincident with a
        // dragged point's original position follows that point's override.
        final adjustedLabels = [
          for (final label in labels)
            (
              at: _draggedLabelPosition(label.at, mapper) ?? label.at,
              tex: label.tex,
            ),
        ];
        final selectedRegionPath = _selectedRegionPath(mapper);
        final canvas = Stack(
          fit: StackFit.expand,
          // Labels are centered on their anchor: with the default
          // hard-edge clip a label on the canvas edge is cut in half.
          // The card clips at its own bounds, so unclipped labels
          // stay inside the card.
          clipBehavior: Clip.none,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                key: const Key("visual-canvas-paint"),
                painter: VisualPainter(
                  scene: widget.scene,
                  palette: widget.palette,
                  parameters: widget.parameters,
                  toggles: widget.toggles,
                  hiddenElementIds: widget.hiddenElementIds,
                  pointOverrides: widget.pointOverrides,
                  timeMs: widget.timeMs,
                  stepIndex: widget.stepIndex,
                  zoom: widget.zoom,
                  pan: widget.pan,
                  tickLabelStyle: tickStyle ?? const TextStyle(fontSize: 11),
                ),
              ),
            ),
            for (final label in adjustedLabels)
              Positioned(
                left: label.at.dx,
                top: label.at.dy,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: Math.tex(
                    label.tex,
                    mathStyle: MathStyle.text,
                    textStyle: TextStyle(
                      fontSize: 15,
                      color: widget.palette.onBackground,
                    ),
                    onErrorFallback: (_) => Text(
                      label.tex,
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.palette.onBackground,
                      ),
                    ),
                  ),
                ),
              ),
            // The student's answer, drawn on top of the figure: a ring
            // around the selected point, a highlight over the selected
            // region. Both render whether or not the question is still
            // editable, so a graded answer stays visible.
            if (widget.selectedPoint != null)
              CustomPaint(
                key: const Key("visual-selection-point"),
                painter: _SelectionPointPainter(
                  mapper.modelToCanvas(widget.selectedPoint!),
                  widget.palette.highlight,
                ),
              ),
            if (selectedRegionPath != null)
              CustomPaint(
                key: const Key("visual-selection-region"),
                painter: _SelectionRegionPainter(
                  selectedRegionPath,
                  widget.palette.highlight,
                ),
              ),
          ],
        );
        if (widget.onTapModelPoint != null) {
          return GestureDetector(
            key: const Key("visual-tap-answer"),
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => widget.onTapModelPoint!(
              mapper.canvasToModel(details.localPosition),
            ),
            child: canvas,
          );
        }
        if (!widget.dragEnabled) return canvas;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Hit-test the pointer-down position. Gesture recognition can start after
          // the pointer has already traveled beyond the point's hit radius.
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (details) {
            ({String id, ui.Offset canvasPos})? nearest;
            var nearestDistance = _VisualCanvas.dragHitRadius;
            for (final candidate in _dragCandidates(mapper)) {
              final distance =
                  (candidate.canvasPos - details.localPosition).distance;
              if (distance <= nearestDistance) {
                nearest = candidate;
                nearestDistance = distance;
              }
            }
            if (nearest == null) return;
            _draggingId = nearest.id;
            _grabOffset = nearest.canvasPos - details.localPosition;
            widget.onDragStart?.call(nearest.id);
          },
          onPanUpdate: (details) {
            final id = _draggingId;
            if (id == null) return;
            widget.onDragUpdate?.call(
              id,
              mapper.canvasToModel(details.localPosition + _grabOffset),
            );
          },
          onPanEnd: (_) => _endDrag(),
          onPanCancel: _endDrag,
          child: canvas,
        );
      },
    );
  }

  void _endDrag() {
    final id = _draggingId;
    _draggingId = null;
    if (id != null) widget.onDragEnd?.call(id);
  }
}

class _SelectionPointPainter extends CustomPainter {
  _SelectionPointPainter(this.center, this.color);

  final ui.Offset center;
  final ui.Color color;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.drawCircle(
      center,
      10,
      ui.Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = ui.PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      10,
      ui.Paint()
        ..color = color
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      center,
      3,
      ui.Paint()
        ..color = color
        ..style = ui.PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_SelectionPointPainter old) =>
      old.center != center || old.color != color;
}

class _SelectionRegionPainter extends CustomPainter {
  _SelectionRegionPainter(this.path, this.color);

  final ui.Path path;
  final ui.Color color;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.drawPath(
      path,
      ui.Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = ui.PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      ui.Paint()
        ..color = color
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SelectionRegionPainter old) =>
      old.path != path || old.color != color;
}
