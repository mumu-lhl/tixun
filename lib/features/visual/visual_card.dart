import 'dart:io';

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
class VisualCard extends StatelessWidget {
  const VisualCard({required this.scene, this.title, super.key});

  final VisualScene scene;

  /// Title override; defaults to the scene title, then `meta.alt`.
  final String? title;

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
          GestureDetector(
            onTap: () => showVisualFullscreen(context, scene, title: _title),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _VisualCanvas(
                scene: scene,
                palette: palette,
                parameters: visualInitialParameters(scene),
                toggles: visualInitialToggles(scene),
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
class _VisualCanvas extends StatelessWidget {
  const _VisualCanvas({
    required this.scene,
    required this.palette,
    required this.parameters,
    required this.toggles,
    this.hiddenElementIds = const {},
    this.timeMs = 0,
    this.stepIndex = 0,
  });

  final VisualScene scene;
  final VisualPalette palette;
  final Map<String, double> parameters;
  final Map<String, bool> toggles;

  /// Element ids hidden by the current teaching step (animator output).
  final Set<String> hiddenElementIds;

  /// Current playback time (only identifies the frame for repaint).
  final double timeMs;
  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    final tickStyle = Theme.of(context).textTheme.bodySmall;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final mapper = VisualCoordinateMapper.fromScene(scene, size);
        final labels = mapper.mathLabelPositions(
          scene,
          parameters,
          toggles: toggles,
          hiddenElementIds: hiddenElementIds,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: VisualPainter(
                  scene: scene,
                  palette: palette,
                  parameters: parameters,
                  toggles: toggles,
                  hiddenElementIds: hiddenElementIds,
                  timeMs: timeMs,
                  stepIndex: stepIndex,
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
                      color: palette.onBackground,
                    ),
                    onErrorFallback: (_) => Text(
                      label.tex,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.onBackground,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
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

  /// Current playback time in milliseconds.
  double _timeMs = 0;
  bool _playing = false;
  AnimationController? _controller;
  bool _autoplayHandled = false;

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
            duration: Duration(milliseconds: _durationMs.round()),
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

  Future<void> _exportPng(
    VisualPalette palette,
    Map<String, double> parameters,
    Map<String, bool> toggles,
  ) async {
    try {
      final bytes = await renderVisualPng(
        widget.scene,
        palette,
        parameters: parameters,
        toggles: toggles,
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
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _VisualCanvas(
                scene: widget.scene,
                palette: palette,
                parameters: parameters,
                toggles: effectiveToggles,
                hiddenElementIds: frame.hiddenElementIds,
                timeMs: frame.timeMs,
                stepIndex: frame.stepIndex,
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
