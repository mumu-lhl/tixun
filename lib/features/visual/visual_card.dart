import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'package:tixun/core/l10n/app_strings.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_animator.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';
import 'package:tixun/core/visual/render/visual_png.dart';
import 'package:tixun/core/visual/render/visual_theme.dart';

/// Opens [scene] fullscreen (a [PageRouteBuilder], not a go_router route —
/// same pattern as `showImageViewer`). When [autoplay] is true, playback
/// starts at time 0 once the page opens (unless animations are disabled).
Future<void> showVisualFullscreen(
  BuildContext context,
  VisualScene scene, {
  String? title,
  bool autoplay = false,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, _, _) =>
          _VisualFullscreenPage(scene: scene, title: title, autoplay: autoplay),
    ),
  );
}

/// Initial parameter values: model parameters, overridden by slider
/// controls' current values (a slider id must match a parameters key).
Map<String, double> visualInitialParameters(VisualScene scene) {
  final parameters = Map<String, double>.of(scene.model?.parameters ?? {});
  for (final control in scene.controls.whereType<SliderControl>()) {
    parameters[control.id] = control.value;
  }
  return parameters;
}

/// Initial toggle values from the toggle controls' defaults.
Map<String, bool> visualInitialToggles(VisualScene scene) => {
  for (final control in scene.controls.whereType<ToggleControl>())
    control.id: control.value,
};

/// A rendered visual scene as a card: title row + 4:3 canvas. Tap opens
/// the fullscreen view with interactive controls.
///
/// When [onTapModelPoint] is set (question answering), tapping the canvas
/// reports the tapped position in model coordinates instead of opening
/// fullscreen; the fullscreen button in the title row still works, and
/// the fullscreen page itself stays view-only.
///
/// When [dragEnabled] is set (drag-to-target questions), dragging a
/// draggable point moves it and reports positions through
/// [onDragUpdate]; [onDragEnd] fires when the drag finishes. Dragging
/// also suppresses tap-to-open-fullscreen on the canvas itself.
class VisualCard extends StatelessWidget {
  const VisualCard({
    required this.scene,
    this.title,
    this.onTapModelPoint,
    this.dragEnabled = false,
    this.pointOverrides = const {},
    this.onDragUpdate,
    this.onDragEnd,
    super.key,
  });

  final VisualScene scene;

  /// Title override; defaults to the scene title, then `meta.alt`.
  final String? title;

  /// Tap-to-answer handler; null means "tap opens fullscreen".
  final ValueChanged<ui.Offset>? onTapModelPoint;

  /// Drag-to-answer mode (drag-to-target questions only).
  final bool dragEnabled;

  /// Local drag positions (element id → model coordinates).
  final Map<String, ui.Offset> pointOverrides;

  /// Called with the dragged element id and its new model position.
  final void Function(String id, ui.Offset modelPosition)? onDragUpdate;

  /// Called with the dragged element id when a drag finishes.
  final void Function(String id)? onDragEnd;

  String get _title => title ?? scene.title ?? scene.meta?.alt ?? '';

  /// True when the scene has something to play: a duration or steps.
  bool get _hasTimeline {
    final timeline = scene.timeline;
    return timeline != null &&
        (timeline.durationMs > 0 || timeline.steps.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = VisualPalette.fromColorScheme(scheme);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    _title,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_hasTimeline)
                IconButton(
                  key: const Key('visual-play-card'),
                  tooltip: context.l10n.visualPlayAnimation,
                  onPressed: () => showVisualFullscreen(
                    context,
                    scene,
                    title: _title,
                    autoplay: true,
                  ),
                  icon: const Icon(Icons.play_arrow),
                ),
              IconButton(
                tooltip: context.l10n.visualViewFullscreen,
                onPressed: () =>
                    showVisualFullscreen(context, scene, title: _title),
                icon: const Icon(Icons.open_in_full),
              ),
            ],
          ),
          if (scene.meta?.schematic == true)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                context.l10n.visualSchematicNote,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          GestureDetector(
            onTap: onTapModelPoint == null && !dragEnabled
                ? () => showVisualFullscreen(context, scene, title: _title)
                : null,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _VisualCanvas(
                scene: scene,
                palette: palette,
                parameters: visualInitialParameters(scene),
                toggles: visualInitialToggles(scene),
                onTapModelPoint: onTapModelPoint,
                dragEnabled: dragEnabled,
                pointOverrides: pointOverrides,
                onDragUpdate: onDragUpdate,
                onDragEnd: onDragEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The paint surface + `Math.tex` overlays, shared by the card and the
/// fullscreen page. Phase 1 shows the fit view only (no pan/zoom).
///
/// When [dragEnabled] is true (fullscreen page, or a drag-to-target
/// question card), dragging a draggable point moves it: the gesture is
/// hit-tested here (this widget owns the coordinate mapper), positions
/// are reported through [onDragUpdate] as model coordinates, and the
/// current positions come back in [pointOverrides]. The scene itself is
/// never mutated — overrides live in the caller's state until reset.
/// [onDragEnd] fires when a drag finishes, so the caller can persist
/// the final position.
///
/// [zoom]/[pan] are the fullscreen pinch view transform (fit view in
/// the chat card): the same mapper paints and hit-tests, so a zoomed
/// view still drags the point under the finger.
class _VisualCanvas extends StatefulWidget {
  const _VisualCanvas({
    required this.scene,
    required this.palette,
    required this.parameters,
    required this.toggles,
    this.hiddenElementIds = const {},
    this.pointOverrides = const {},
    this.timeMs = 0,
    this.stepIndex = 0,
    this.zoom = 1.0,
    this.pan = ui.Offset.zero,
    this.dragEnabled = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onTapModelPoint,
  });

  final VisualScene scene;
  final VisualPalette palette;
  final Map<String, double> parameters;
  final Map<String, bool> toggles;

  /// Element ids hidden by the current teaching step (animator output).
  final Set<String> hiddenElementIds;

  /// Local drag positions (element id → model coordinates).
  final Map<String, ui.Offset> pointOverrides;

  /// Current playback time (only identifies the frame for repaint).
  final double timeMs;
  final int stepIndex;

  /// Fullscreen pinch zoom (1.0 = fit view) and pan in canvas pixels.
  final double zoom;
  final ui.Offset pan;

  /// True in the fullscreen page and in drag-to-target question cards;
  /// the plain chat card never drags.
  final bool dragEnabled;

  /// Called with the dragged element id when a drag starts.
  final void Function(String id)? onDragStart;

  /// Called with the dragged element id and its new model position.
  final void Function(String id, ui.Offset modelPosition)? onDragUpdate;

  /// Called with the dragged element id when a drag finishes.
  final void Function(String id)? onDragEnd;

  /// Tap-to-answer handler (question cards only): reports the tapped
  /// position in model coordinates. Mutually exclusive with [dragEnabled].
  final ValueChanged<ui.Offset>? onTapModelPoint;

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
        final canvas = Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                key: const Key('visual-canvas-paint'),
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
            for (final label in labels)
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
          ],
        );
        if (widget.onTapModelPoint != null) {
          return GestureDetector(
            key: const Key('visual-tap-answer'),
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
          // Report the pointer-down position in onPanStart, not the
          // position where the drag was accepted: with the default
          // DragStartBehavior.start the recognizer advances its initial
          // position by the pre-acceptance travel (dead zone + arena
          // delay, ~41 px measured on real Linux), which is larger than
          // the 24 px hit radius — a press exactly on a point would
          // miss it. With `down` the hit test sees where the finger
          // actually went down.
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

class _VisualFullscreenPage extends StatefulWidget {
  const _VisualFullscreenPage({
    required this.scene,
    this.title,
    this.autoplay = false,
  });

  final VisualScene scene;
  final String? title;

  /// Start playback at time 0 once the page opens (unless animations
  /// are disabled).
  final bool autoplay;

  @override
  State<_VisualFullscreenPage> createState() => _VisualFullscreenPageState();
}

class _VisualFullscreenPageState extends State<_VisualFullscreenPage>
    with SingleTickerProviderStateMixin {
  /// Manual parameter overrides from the sliders below the canvas.
  /// Empty at start: the canvas shows the animator's frame (control
  /// defaults + tracks). A drag takes that parameter over until the next
  /// play start, which clears overrides for tracked parameters.
  final Map<String, double> _manualParameters = {};

  /// Manual toggle state (toggles are never animated).
  late Map<String, bool> _manualToggles;

  /// Local drag positions (element id → model coordinates). Set while
  /// the user drags a point in the fullscreen view; never persisted.
  /// The reset button clears them.
  final Map<String, ui.Offset> _pointOverrides = {};

  /// Fullscreen pinch view transform: zoom about the view centre (1.0 =
  /// fit) and pan in canvas pixels. The chat card always shows the fit
  /// view; PNG export too.
  double _zoom = 1.0;
  ui.Offset _pan = ui.Offset.zero;

  /// True while two pointers are down: point dragging is locked so the
  /// pinch does not also drag a point under the first finger.
  bool _pinching = false;

  /// Active pointers on the canvas (pointer id → position in the
  /// pinch Listener's coordinates; only distances and midpoint deltas
  /// are used, so the frame does not matter).
  final Map<int, ui.Offset> _activePointers = {};
  double _pinchStartDistance = 0;
  ui.Offset _pinchStartMidpoint = ui.Offset.zero;
  double _pinchStartZoom = 1.0;
  ui.Offset _pinchStartPan = ui.Offset.zero;

  /// Current playback time in milliseconds.
  double _timeMs = 0;
  bool _playing = false;
  AnimationController? _controller;
  bool _autoplayHandled = false;

  /// Playback speed multiplier (0.5×, 1×, 2×). The animation clock runs
  /// at this rate; the authored duration stays the source of truth.
  double _speed = 1.0;
  static const _speeds = [0.5, 1.0, 2.0];

  double get _durationMs => visualDurationMs(widget.scene);

  /// True when the scene has something to play: a duration or steps.
  bool get _hasPlayer {
    final timeline = widget.scene.timeline;
    return timeline != null &&
        (timeline.durationMs > 0 || timeline.steps.isNotEmpty);
  }

  List<VisualStep> get _sortedSteps {
    final steps = List<VisualStep>.of(widget.scene.timeline?.steps ?? []);
    steps.sort((a, b) => a.atMs.compareTo(b.atMs));
    return steps;
  }

  /// Index (into [_sortedSteps]) of the current step: the last step
  /// with `atMs <= _timeMs`, or -1 when none applies yet.
  int get _currentStepIndex {
    final steps = _sortedSteps;
    var current = -1;
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].atMs <= _timeMs) {
        current = i;
      } else {
        break;
      }
    }
    return current;
  }

  @override
  void initState() {
    super.initState();
    _manualToggles = visualInitialToggles(widget.scene);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.autoplay && !_autoplayHandled) {
      _autoplayHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !MediaQuery.of(context).disableAnimations) {
          _startPlaying();
        }
      });
    }
  }

  void _startPlaying() {
    if (_durationMs <= 0) return;
    if (MediaQuery.of(context).disableAnimations) return;
    // Restart the authored animation: manual overrides for tracked
    // parameters give way to the tracks.
    for (final track in widget.scene.timeline?.tracks ?? const []) {
      _manualParameters.remove(track.target);
    }
    if (_timeMs >= _durationMs) _timeMs = 0;
    final controller = _controller ??=
        AnimationController(
            vsync: this,
            duration: Duration(milliseconds: (_durationMs / _speed).round()),
          )
          ..addListener(_onTick)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              setState(() {
                _playing = false;
                _timeMs = _durationMs;
              });
            }
          });
    controller.value = (_timeMs / _durationMs).clamp(0, 1);
    controller.forward();
    setState(() => _playing = true);
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _timeMs = controller.value * _durationMs);
  }

  void _pause() {
    _controller?.stop();
    setState(() => _playing = false);
  }

  /// Switches playback speed, keeping the current position: the
  /// controller's value is a fraction of the authored duration, so
  /// changing its duration leaves `_timeMs` (value × duration) alone.
  void _setSpeed(double speed) {
    setState(() => _speed = speed);
    final controller = _controller;
    if (controller != null) {
      controller.duration = Duration(
        milliseconds: (_durationMs / _speed).round(),
      );
    }
  }

  void _seekTo(double timeMs) {
    final clamped = timeMs.clamp(0, _durationMs).toDouble();
    _controller?.value = _durationMs > 0 ? clamped / _durationMs : 0;
    setState(() => _timeMs = clamped);
  }

  void _jumpToStep(int index) {
    final steps = _sortedSteps;
    if (index < 0 || index >= steps.length) return;
    _seekTo(steps[index].atMs.toDouble());
  }

  /// Two-finger pinch/pan on the canvas (a `Listener`, not a gesture
  /// recogniser, so it never competes with the point-drag recogniser
  /// below: one-finger drags keep dragging points, and the pinch only
  /// starts when the second finger lands).
  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 2) {
      final points = _activePointers.values.toList();
      _pinchStartDistance = (points[0] - points[1]).distance;
      _pinchStartMidpoint = (points[0] + points[1]) / 2;
      _pinchStartZoom = _zoom;
      _pinchStartPan = _pan;
      setState(() => _pinching = true);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length != 2 || _pinchStartDistance <= 0) return;
    final points = _activePointers.values.toList();
    final distance = (points[0] - points[1]).distance;
    final midpoint = (points[0] + points[1]) / 2;
    setState(() {
      _zoom = (_pinchStartZoom * distance / _pinchStartDistance).clamp(
        0.5,
        4.0,
      );
      _pan = _pinchStartPan + (midpoint - _pinchStartMidpoint);
    });
  }

  void _onPointerUp(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2 && _pinching) {
      setState(() => _pinching = false);
    }
  }

  Future<void> _exportPng(
    VisualPalette palette,
    Map<String, double> parameters,
    Map<String, bool> toggles,
  ) async {
    try {
      // Export the frame on screen right now: the current time, with
      // the manual slider/toggle state layered over it.
      final bytes = await renderVisualPng(
        widget.scene,
        palette,
        parameters: parameters,
        toggles: toggles,
        pointOverrides: _pointOverrides,
        timeMs: _timeMs,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/visual-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.visualSavedTo(file.path))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.visualExportFailed)));
    }
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _formatTime(double timeMs) => '${(timeMs / 1000).toStringAsFixed(1)}s';

  String _formatSpeed(double speed) =>
      '${speed == speed.roundToDouble() ? speed.toInt() : speed}×';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = VisualPalette.fromColorScheme(scheme);
    final sliders = widget.scene.controls.whereType<SliderControl>().toList();
    final toggles = widget.scene.controls.whereType<ToggleControl>().toList();
    // Choice controls are parsed + validated but have no Phase 1
    // rendering effect, so they are not shown here.
    final title =
        widget.title ?? widget.scene.title ?? widget.scene.meta?.alt ?? '';
    // The animator is the single source of truth for the frame:
    // parameters/toggles/hidden ids are re-resolved from _timeMs on
    // every build (including every animation tick).
    final frame = resolveVisualFrame(widget.scene, _timeMs);
    final parameters = {...frame.parameters, ..._manualParameters};
    final effectiveToggles = {...frame.toggles, ..._manualToggles};
    final steps = _sortedSteps;
    final currentStepIndex = _currentStepIndex;
    final currentNote = currentStepIndex >= 0
        ? steps[currentStepIndex].note
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const Key('visual-reset-drag'),
            tooltip: context.l10n.visualResetDrag,
            onPressed: _pointOverrides.isEmpty
                ? null
                : () => setState(_pointOverrides.clear),
            icon: const Icon(Icons.restart_alt),
          ),
          IconButton(
            key: const Key('visual-reset-view'),
            tooltip: context.l10n.visualResetView,
            onPressed: _zoom == 1.0 && _pan == ui.Offset.zero
                ? null
                : () => setState(() {
                    _zoom = 1.0;
                    _pan = ui.Offset.zero;
                  }),
            icon: const Icon(Icons.fit_screen),
          ),
          IconButton(
            tooltip: context.l10n.visualExportPng,
            onPressed: () => _exportPng(palette, parameters, effectiveToggles),
            icon: const Icon(Icons.download),
          ),
          IconButton(
            tooltip: context.l10n.closePreview,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _VisualCanvas(
                  scene: widget.scene,
                  palette: palette,
                  parameters: parameters,
                  toggles: effectiveToggles,
                  hiddenElementIds: frame.hiddenElementIds,
                  pointOverrides: _pointOverrides,
                  timeMs: frame.timeMs,
                  stepIndex: frame.stepIndex,
                  zoom: _zoom,
                  pan: _pan,
                  dragEnabled: !_pinching,
                  onDragStart: (_) {
                    // A drag takes the scene over: stop the animation so
                    // the tracks do not fight the finger.
                    if (_playing) _pause();
                  },
                  onDragUpdate: (id, position) =>
                      setState(() => _pointOverrides[id] = position),
                ),
              ),
            ),
          ),
          if (_hasPlayer)
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (_durationMs > 0)
                        IconButton(
                          key: const Key('visual-play-pause'),
                          tooltip: _playing
                              ? context.l10n.visualPauseAnimation
                              : context.l10n.visualPlayAnimation,
                          onPressed: _playing ? _pause : _startPlaying,
                          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                        ),
                      if (_durationMs > 0)
                        Expanded(
                          child: Semantics(
                            label: context.l10n.visualSeek,
                            child: Slider(
                              key: const Key('visual-seek'),
                              value: _timeMs.clamp(0, _durationMs),
                              min: 0,
                              max: _durationMs,
                              label:
                                  '${_formatTime(_timeMs)} / ${_formatTime(_durationMs)}',
                              onChanged: _seekTo,
                            ),
                          ),
                        ),
                      if (_durationMs > 0)
                        Text(
                          '${_formatTime(_timeMs)} / ${_formatTime(_durationMs)}',
                          key: const Key('visual-time-label'),
                        ),
                      if (_durationMs > 0)
                        PopupMenuButton<double>(
                          key: const Key('visual-speed'),
                          tooltip: context.l10n.visualPlaybackSpeed,
                          initialValue: _speed,
                          onSelected: _setSpeed,
                          itemBuilder: (context) => [
                            for (final speed in _speeds)
                              PopupMenuItem(
                                value: speed,
                                child: Text(_formatSpeed(speed)),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              _formatSpeed(_speed),
                              key: const Key('visual-speed-label'),
                            ),
                          ),
                        ),
                      if (steps.isNotEmpty) ...[
                        IconButton(
                          key: const Key('visual-prev-step'),
                          tooltip: context.l10n.visualPreviousStep,
                          onPressed: currentStepIndex > 0
                              ? () => _jumpToStep(currentStepIndex - 1)
                              : null,
                          icon: const Icon(Icons.skip_previous),
                        ),
                        IconButton(
                          key: const Key('visual-next-step'),
                          tooltip: context.l10n.visualNextStep,
                          onPressed: currentStepIndex < steps.length - 1
                              ? () => _jumpToStep(currentStepIndex + 1)
                              : null,
                          icon: const Icon(Icons.skip_next),
                        ),
                      ],
                    ],
                  ),
                  if (currentNote != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        currentNote,
                        key: const Key('visual-step-note'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          if (sliders.isNotEmpty || toggles.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final control in sliders)
                    Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            control.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: parameters[control.id]!.clamp(
                              control.min,
                              control.max,
                            ),
                            min: control.min,
                            max: control.max,
                            divisions: control.step > 0
                                ? ((control.max - control.min) / control.step)
                                      .round()
                                      .clamp(1, 1000)
                                : null,
                            label: _formatValue(parameters[control.id]!),
                            onChanged: (value) => setState(
                              () => _manualParameters[control.id] = value,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            _formatValue(parameters[control.id]!),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  for (final control in toggles)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(control.label),
                      value: _manualToggles[control.id] ?? control.value,
                      onChanged: (value) =>
                          setState(() => _manualToggles[control.id] = value),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
