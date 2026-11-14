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
/// `math_label` elements are drawn as cleaned plain text (see
/// [texToPlainText] — there is no TeX layout in an offscreen picture;
/// on screen they are `Math.tex` overlays), and the canvas is always
/// the fit view (no pan/zoom state).
///
/// [timeMs] renders the frame at that moment: tracks are evaluated at
/// [timeMs] and the teaching steps active then hide their elements. An
/// explicit [stepIndex] (>= 0) pins the frame to that step instead:
/// [stepIndex] indexes the original (unsorted) step list, and the frame
/// is resolved cumulatively (every step with `atMs <=` that step's
/// `atMs` applies, tracks evaluated at the step's `atMs`), as the
/// animator defines.
/// [parameters]/[toggles] override the resolved frame (manual slider and
/// toggle state win over the animation), exactly like the fullscreen page.
/// Minimal TeX-to-plain-text cleaning for PNG export.
///
/// The offscreen picture has no TeX layout (on screen `math_label`s
/// are `Math.tex` overlays), so a raw `\frac{1}{2}` would land in the
/// image as a literal string. This turns the common shapes into
/// readable plain text instead: `\frac{a}{b}` → `a/b`, `\sqrt{x}` →
/// `√x`, other `\commands` are dropped, grouping braces are removed,
/// and `^`/`_` are kept as-is. Anything unusual degrades to the
/// source text minus its commands, never to an exception.
String texToPlainText(String tex) {
  final out = StringBuffer();
  var i = 0;
  while (i < tex.length) {
    final ch = tex[i];
    if (ch == r'\') {
      var j = i + 1;
      while (j < tex.length) {
        final c = tex.codeUnitAt(j);
        if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) {
          j++;
        } else {
          break;
        }
      }
      final name = tex.substring(i + 1, j);
      if (name == 'frac') {
        final first = _readGroup(tex, j);
        if (first == null) {
          // No braced groups: drop the command, let the tokens render.
          i = j;
          continue;
        }
        final second = _readGroup(tex, first.$2);
        if (second == null) {
          out.write(texToPlainText(first.$1));
          i = first.$2;
        } else {
          out.write(texToPlainText(first.$1));
          out.write('/');
          out.write(texToPlainText(second.$1));
          i = second.$2;
        }
      } else if (name == 'sqrt') {
        final group = _readGroup(tex, j);
        if (group == null) {
          // `\sqrt2`: the next character is the radicand.
          out.write('√');
          i = j;
        } else {
          out.write('√');
          out.write(texToPlainText(group.$1));
          i = group.$2;
        }
      } else {
        // Any other command is dropped (its argument braces, if any,
        // are processed as plain grouping below).
        i = j;
      }
      continue;
    }
    if (ch == '{' || ch == '}') {
      // Grouping braces carry no text.
      i++;
      continue;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}

/// Reads a `{...}` group starting at [start] (skipping spaces):
/// returns the inner text and the index just past the closing brace,
/// or null when there is no group there. Nested braces are balanced.
(String, int)? _readGroup(String tex, int start) {
  var i = start;
  while (i < tex.length && tex[i] == ' ') {
    i++;
  }
  if (i >= tex.length || tex[i] != '{') return null;
  var depth = 0;
  final inner = StringBuffer();
  i++; // Past '{'.
  while (i < tex.length) {
    final ch = tex[i];
    if (ch == '{') {
      depth++;
      inner.write(ch);
    } else if (ch == '}') {
      if (depth == 0) return (inner.toString(), i + 1);
      depth--;
      inner.write(ch);
    } else {
      inner.write(ch);
    }
    i++;
  }
  return null; // Unbalanced: no group.
}

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
  // TeX source is cleaned to readable plain text first (see
  // [texToPlainText]): a raw `\frac{1}{2}` in the image would be a
  // literal string, not a fraction.
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
        text: texToPlainText(label.tex),
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
