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
Future<Uint8List> renderVisualPng(
  VisualScene scene,
  VisualPalette palette, {
  ui.Size size = const ui.Size(1200, 800),
  double pixelRatio = 2.0,
  Map<String, double> parameters = const {},
  Map<String, bool> toggles = const {},
  Map<String, ui.Offset> pointOverrides = const {},
  int stepIndex = 0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(pixelRatio, pixelRatio);
  // Step visibility is resolved by the animator (the painter no longer
  // interprets the timeline): render at the requested step, as before.
  final timeline = scene.timeline;
  final hiddenElementIds =
      timeline != null && stepIndex >= 0 && stepIndex < timeline.steps.length
      ? resolveVisualFrame(scene, 0, stepIndex).hiddenElementIds
      : const <String>{};
  VisualPainter(
    scene: scene,
    palette: palette,
    parameters: parameters,
    toggles: toggles,
    hiddenElementIds: hiddenElementIds,
    pointOverrides: pointOverrides,
    stepIndex: stepIndex,
    tickLabelStyle: TextStyle(fontSize: 20, color: palette.textMuted),
  ).paint(canvas, size);
  // Math labels as plain text: the only text the painter skips.
  final mapper = VisualCoordinateMapper.fromScene(scene, size);
  final labels = mapper.mathLabelPositions(
    scene,
    parameters,
    toggles: toggles,
    hiddenElementIds: hiddenElementIds,
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
