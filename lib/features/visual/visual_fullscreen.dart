part of "visual_card.dart";

class _VisualFullscreenPage extends StatefulWidget {
  const _VisualFullscreenPage({
    required this.scene,
    this.title,
    this.autoplay = false,
    this.allowDrag = true,
    this.assessment = false,
  });

  final VisualScene scene;
  final String? title;

  /// Start playback at time 0 once the page opens (unless animations
  /// are disabled).
  final bool autoplay;

  /// Whether points can be dragged in this page. Question cards open
  /// view-only (false); the standalone player allows exploratory
  /// dragging (local only, never persisted).
  final bool allowDrag;
  final bool assessment;

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

  double _timeMs = 0;
  bool _playing = false;
  AnimationController? _controller;
  bool _autoplayHandled = false;

  /// Playback speed multiplier (0.5×, 1×, 2×). The animation clock runs
  /// at this rate; the authored duration stays the source of truth.
  double _speed = 1.0;
  static const _speeds = [0.5, 1.0, 2.0];

  double get _durationMs => visualDurationMs(widget.scene);

  bool get _hasPlayer {
    final timeline = widget.scene.timeline;
    return !widget.assessment &&
        timeline != null &&
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

  void _updatePlayback(VoidCallback update) => setState(update);

  String _formatValue(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceAll(RegExp(r"0+$"), "").replaceAll(RegExp(r"\.$"), "");
  }

  String _formatTime(double timeMs) => "${(timeMs / 1000).toStringAsFixed(1)}s";

  String _formatSpeed(double speed) =>
      "${speed == speed.roundToDouble() ? speed.toInt() : speed}×";

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = VisualPalette.fromColorScheme(scheme);
    final sliders = widget.assessment
        ? <SliderControl>[]
        : widget.scene.controls.whereType<SliderControl>().toList();
    final toggles = widget.assessment
        ? <ToggleControl>[]
        : widget.scene.controls.whereType<ToggleControl>().toList();
    // Choice controls have no rendering effect in this player.
    final title =
        widget.title ?? widget.scene.title ?? widget.scene.meta?.alt ?? "";
    // The animator is the single source of truth for the frame:
    // parameters/toggles/hidden ids are re-resolved from _timeMs on
    // every build (including every animation tick).
    final frame = resolveVisualFrame(
      widget.scene,
      widget.assessment ? 0 : _timeMs,
    );
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
          if (widget.allowDrag)
            IconButton(
              key: const Key("visual-reset-drag"),
              tooltip: context.l10n.visualResetDrag,
              onPressed: _pointOverrides.isEmpty
                  ? null
                  : () => setState(_pointOverrides.clear),
              icon: const Icon(Icons.restart_alt),
            ),
          IconButton(
            key: const Key("visual-reset-view"),
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
          if (widget.assessment)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(context.l10n.visualAssessmentView),
            ),
          if (widget.scene.meta?.schematic == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                context.l10n.visualSchematicNote,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
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
                  dragEnabled: widget.allowDrag && !_pinching,
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
          if (widget.assessment)
            TextButton.icon(
              key: const Key("visual-return-to-answer"),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(context.l10n.visualReturnToAnswer),
            ),
          if (_hasPlayer)
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              // Compact padding keeps all controls visible at phone widths.
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (_durationMs > 0)
                        IconButton(
                          key: const Key("visual-play-pause"),
                          tooltip: _playing
                              ? context.l10n.visualPauseAnimation
                              : context.l10n.visualPlayAnimation,
                          // With animations disabled playback never
                          // starts: grey the button out instead of
                          // leaving a tap that silently does nothing.
                          onPressed: MediaQuery.of(context).disableAnimations
                              ? null
                              : _playing
                              ? _pause
                              : _startPlaying,
                          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                        ),
                      if (_durationMs > 0)
                        Expanded(
                          child: Semantics(
                            label: context.l10n.visualSeek,
                            child: Slider(
                              key: const Key("visual-seek"),
                              value: _timeMs.clamp(0, _durationMs),
                              min: 0,
                              max: _durationMs,
                              label:
                                  "${_formatTime(_timeMs)} / ${_formatTime(_durationMs)}",
                              onChanged: _seekTo,
                            ),
                          ),
                        ),
                      if (_durationMs > 0)
                        Text(
                          "${_formatTime(_timeMs)} / ${_formatTime(_durationMs)}",
                          key: const Key("visual-time-label"),
                        ),
                      if (_durationMs > 0)
                        PopupMenuButton<double>(
                          key: const Key("visual-speed"),
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
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              _formatSpeed(_speed),
                              key: const Key("visual-speed-label"),
                            ),
                          ),
                        ),
                      if (steps.isNotEmpty) ...[
                        IconButton(
                          key: const Key("visual-prev-step"),
                          tooltip: context.l10n.visualPreviousStep,
                          onPressed: currentStepIndex > 0
                              ? () => _jumpToStep(currentStepIndex - 1)
                              : null,
                          icon: const Icon(Icons.skip_previous),
                        ),
                        IconButton(
                          key: const Key("visual-next-step"),
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
                        key: const Key("visual-step-note"),
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
