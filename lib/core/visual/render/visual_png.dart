import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart'
    show TextPainter, TextSpan, TextStyle;
import 'package:tixun/core/visual/model/visual_scene.dart';

import 'visual_animator.dart';
import 'visual_painter.dart';
import 'visual_theme.dart';

/// Renders [scene] to PNG bytes without any widget.
///
/// Uses the same [VisualPainter] as the on-screen card, so the export
/// matches what the user sees, with two known Phase 1 limitations:
/// `math_label` elements are drawn as plain text (there is no TeX layout
/// in an offscreen picture — on screen they are `Math.tex` overlays), and
/// the canvas is always the fit view (no pan/zoom state).
///
/// [timeMs] renders the frame at that moment: tracks are evaluated at
/// [timeMs] and the teaching steps active then hide their elements. An
/// explicit [stepIndex] (>= 0) pins the frame to that step instead
/// (tracks evaluated at the step's `atMs`, as the animator defines).
/// [parameters]/[toggles] override the resolved frame (manual slider and
/// toggle state win over the animation), exactly like the fullscreen page.
Future<Uint8List> renderVisualPng(
  VisualScene scene,
  VisualPalette palette, {
  ui.Size size = const ui.Size(1200, 800),
  double pixelRatio = 2.0,
  Map<String, double> parameters = const {},
  Map<String, bool> toggles = const {},
  Map<String, ui.Offset> pointOverrides = const {},
  double timeMs = 0,
  int stepIndex = -1,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(pixelRatio, pixelRatio);
  // Step visibility is resolved by the animator (the painter no longer
  // interprets the timeline): render the requested frame.
  final frame = stepIndex >= 0
      ? resolveVisualFrame(scene, timeMs, stepIndex)
      : resolveVisualFrame(scene, timeMs);
  final effectiveParameters = {...frame.parameters, ...parameters};
  final effectiveToggles = {...frame.toggles, ...toggles};
  VisualPainter(
    scene: scene,
    palette: palette,
    parameters: effectiveParameters,
    toggles: effectiveToggles,
    hiddenElementIds: frame.hiddenElementIds,
    pointOverrides: pointOverrides,
    timeMs: frame.timeMs,
    stepIndex: frame.stepIndex,
    tickLabelStyle: TextStyle(fontSize: 20, color: palette.textMuted),
  ).paint(canvas, size);
  // Math labels as plain text: the only text the painter skips.
  final mapper = VisualCoordinateMapper.fromScene(scene, size);
  final labels = mapper.mathLabelPositions(
    scene,
    effectiveParameters,
    toggles: effectiveToggles,
    hiddenElementIds: frame.hiddenElementIds,
  );
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(
        text: label.tex,
        style: TextStyle(fontSize: 22, color: palette.onBackground),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      label.at - ui.Offset(painter.width / 2, painter.height / 2),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (size.width * pixelRatio).round(),
    (size.height * pixelRatio).round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
