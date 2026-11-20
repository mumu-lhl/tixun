import "dart:io";
import "dart:ui" as ui;

import "package:flutter/gestures.dart";
import "package:flutter_math_fork/flutter_math.dart";
import "package:material_ui/material_ui.dart";
import "package:path_provider/path_provider.dart";

import "package:tixun/core/l10n/app_strings.dart";
import "package:tixun/core/visual/model/visual_scene.dart";
import "package:tixun/core/visual/render/visual_animator.dart";
import "package:tixun/core/visual/render/visual_painter.dart";
import "package:tixun/core/visual/render/visual_png.dart";
import "package:tixun/core/visual/render/visual_theme.dart";

part "visual_canvas.dart";
part "visual_fullscreen.dart";

part "visual_playback.dart";

/// Opens [scene] fullscreen (a [PageRouteBuilder], not a go_router route —
/// same pattern as `showImageViewer`). When [autoplay] is true, playback
/// starts at time 0 once the page opens (unless animations are disabled).
///
/// [allowDrag] gates dragging points in the fullscreen page: the
/// standalone player allows exploratory dragging (local only, never
/// persisted); a question card passes false so its fullscreen stays
/// view-only and a fullscreen drag can never move the answer.
Future<void> showVisualFullscreen(
  BuildContext context,
  VisualScene scene, {
  String? title,
  bool autoplay = false,
  bool allowDrag = true,
  bool assessment = false,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, _, _) => _VisualFullscreenPage(
        scene: scene,
        title: title,
        autoplay: autoplay && !assessment,
        allowDrag: allowDrag && !assessment,
        assessment: assessment,
      ),
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

Map<String, bool> visualInitialToggles(VisualScene scene) => {
  for (final control in scene.controls.whereType<ToggleControl>())
    control.id: control.value,
};

/// A preview of the initial teaching frame or an inline answer control.
/// Graded selections stay visible, and question previews do not allow
/// exploratory fullscreen interactions to alter an answer.
class VisualCard extends StatelessWidget {
  const VisualCard({
    required this.scene,
    this.title,
    this.onTapModelPoint,
    this.dragEnabled = false,
    this.fullscreenAllowDrag = true,
    this.assessment = false,
    this.onFullscreen,
    this.assessmentFullscreen = false,
    this.pointOverrides = const {},
    this.onDragUpdate,
    this.onDragEnd,
    this.selectedPoint,
    this.selectedRegionId,
    super.key,
  });

  final VisualScene scene;

  /// Title override; defaults to the scene title, then `meta.alt`.
  final String? title;

  /// Tap-to-answer handler; null means "tap opens fullscreen".
  final ValueChanged<ui.Offset>? onTapModelPoint;

  final bool dragEnabled;

  /// Whether the fullscreen page opened from this card lets the user
  /// drag points. Question cards pass false (view-only fullscreen);
  /// standalone cards keep the exploratory drag. QuestionCard overrides the
  /// fullscreen action with its shared-attempt answer route instead.
  final bool fullscreenAllowDrag;

  /// Assessment snapshots expose only the initial frame in fullscreen;
  /// exploratory controls and teaching steps are not answer controls.
  final bool assessment;
  final VoidCallback? onFullscreen;
  final bool assessmentFullscreen;

  /// Local drag positions (element id → model coordinates).
  final Map<String, ui.Offset> pointOverrides;

  final void Function(String id, ui.Offset modelPosition)? onDragUpdate;

  final void Function(String id)? onDragEnd;

  /// Selected point (point-select answers), in model coordinates.
  final ui.Offset? selectedPoint;

  /// Selected region (region-select answers): the polygon element id.
  final String? selectedRegionId;

  String get _title => title ?? scene.title ?? scene.meta?.alt ?? "";

  bool get _hasTimeline {
    final timeline = scene.timeline;
    return !assessment &&
        timeline != null &&
        (timeline.durationMs > 0 || timeline.steps.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = VisualPalette.fromColorScheme(scheme);
    final frame = resolveVisualFrame(scene, 0);
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
                    _title.isEmpty ? context.l10n.visualUntitled : _title,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_hasTimeline)
                IconButton(
                  key: const Key("visual-play-card"),
                  tooltip: context.l10n.visualPlayAnimation,
                  onPressed: () => showVisualFullscreen(
                    context,
                    scene,
                    title: _title,
                    autoplay: true,
                    allowDrag: fullscreenAllowDrag,
                    assessment: assessment,
                  ),
                  icon: const Icon(Icons.play_arrow),
                ),
              if (!assessmentFullscreen)
                IconButton(
                  tooltip: context.l10n.visualViewFullscreen,
                  onPressed:
                      onFullscreen ??
                      () => showVisualFullscreen(
                        context,
                        scene,
                        title: _title,
                        allowDrag: fullscreenAllowDrag,
                        assessment: assessment,
                      ),
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
            onTap:
                !assessmentFullscreen && onTapModelPoint == null && !dragEnabled
                ? onFullscreen ??
                      () => showVisualFullscreen(
                        context,
                        scene,
                        title: _title,
                        allowDrag: fullscreenAllowDrag,
                        assessment: assessment,
                      )
                : null,
            child: _AssessmentViewport(
              expanded: assessmentFullscreen,
              // The figure itself is the accessible content: `meta.alt`
              // is the accessibility text (the title is only a fallback
              // when no alt text was authored).
              child: Semantics(
                label: scene.meta?.alt ?? scene.title ?? "",
                image: true,
                child: _VisualCanvas(
                  scene: scene,
                  palette: palette,
                  parameters: frame.parameters,
                  toggles: frame.toggles,
                  hiddenElementIds: frame.hiddenElementIds,
                  timeMs: frame.timeMs,
                  stepIndex: frame.stepIndex,
                  onTapModelPoint: onTapModelPoint,
                  dragEnabled: dragEnabled,
                  pointOverrides: pointOverrides,
                  onDragUpdate: onDragUpdate,
                  onDragEnd: onDragEnd,
                  selectedPoint: selectedPoint,
                  selectedRegionId: selectedRegionId,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
