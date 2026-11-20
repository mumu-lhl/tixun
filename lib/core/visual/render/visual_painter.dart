import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart"
    show CustomPainter, TextPainter, TextSpan, TextStyle;

import "package:tixun/core/visual/math/sampling.dart";
import "package:tixun/core/visual/model/visual_scene.dart";

import "circuit_geometry.dart";
import "visual_theme.dart";

part "visual_coordinates.dart";
part "visual_element_painting.dart";

/// All elements flattened (groups expanded in place), in source order.
List<VisualElement> _flattenElements(List<VisualElement> elements) {
  final out = <VisualElement>[];
  void add(VisualElement element) {
    if (element is GroupElement) {
      for (final child in element.children) {
        add(child);
      }
    } else {
      out.add(element);
    }
  }

  for (final element in elements) {
    add(element);
  }
  return out;
}

/// Resolves a [VisualPoint] to model coordinates with [parameters].
/// Returns null when a `$param` binding has no value (the element is
/// skipped, never drawn half-resolved).
ui.Offset? resolvePoint(VisualPoint point, Map<String, double> parameters) {
  double? resolve(VisualCoord coord) {
    if (coord.isParam) {
      final value = parameters[coord.param];
      if (value == null || !value.isFinite) return null;
      return value;
    }
    return coord.value;
  }

  final x = resolve(point.x);
  final y = resolve(point.y);
  if (x == null || y == null) return null;
  return ui.Offset(x, y);
}

/// Whether [element] is shown given toggle state and the animator's
/// hidden set. Step visibility is resolved by the animator
/// ([resolveVisualFrame]) — the painter never interprets the timeline
/// itself.
bool _elementVisible(
  VisualElement element,
  VisualScene scene,
  Map<String, bool> toggles,
  Set<String> hiddenElementIds,
) {
  if (!element.visible) return false;
  final gate = element.visibleWhen;
  if (gate != null) {
    var value = toggles[gate.control];
    if (value == null) {
      final control = scene.controls.whereType<ToggleControl>().where(
        (c) => c.id == gate.control,
      );
      value = control.isEmpty ? false : control.first.value;
    }
    if (value != gate.equals) return false;
  }
  if (hiddenElementIds.contains(element.id)) return false;
  return true;
}

/// Elements that pass visibility, flattened and sorted by `layer`
/// (lower paints first; source order breaks ties).
List<VisualElement> _visibleElements(
  VisualScene scene,
  Map<String, bool> toggles,
  Set<String> hiddenElementIds,
) {
  final visible = <(int, VisualElement)>[];
  void visit(VisualElement element) {
    // A hidden ancestor hides the whole subtree, including hit targets
    // and math labels. Preserve source order before sorting by layer.
    if (!_elementVisible(element, scene, toggles, hiddenElementIds)) return;
    if (element is GroupElement) {
      for (final child in element.children) {
        visit(child);
      }
    } else {
      visible.add((visible.length, element));
    }
  }

  for (final element in scene.elements) {
    visit(element);
  }
  visible.sort((a, b) {
    final byLayer = a.$2.layer.compareTo(b.$2.layer);
    return byLayer != 0 ? byLayer : a.$1.compareTo(b.$1);
  });
  return [for (final (_, element) in visible) element];
}

/// Public view of [_visibleElements] for the widget layer (drag
/// hit-testing needs the same visibility rules as the painter).
List<VisualElement> visualVisibleElements(
  VisualScene scene,
  Map<String, bool> toggles,
  Set<String> hiddenElementIds,
) => _visibleElements(scene, toggles, hiddenElementIds);

/// The id of the topmost visible polygon containing [modelPoint], or null
/// when the point is outside every polygon. Used by region-select
/// questions: a tap on the visual answers with the tapped region's id.
/// Elements arrive in paint order (layer, then scene order); later
/// elements win because they paint on top.
String? visualRegionAtPoint(
  VisualScene scene,
  ui.Offset modelPoint,
  Map<String, double> parameters, {
  Map<String, bool> toggles = const {},
  Set<String> hiddenElementIds = const {},
}) {
  String? found;
  for (final element in visualVisibleElements(
    scene,
    toggles,
    hiddenElementIds,
  )) {
    if (element is PolygonElement) {
      final points = [
        for (final p in element.points) resolvePoint(p, parameters),
      ];
      if (points.any((p) => p == null)) continue;
      if (_pointInPolygon(modelPoint, points.cast<ui.Offset>())) {
        found = element.id;
      }
    }
  }
  return found;
}

// Even-odd ray casting uses a half-open boundary. Strict crossings avoid
// counting a shared vertex twice.
bool _pointInPolygon(ui.Offset p, List<ui.Offset> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

/// Whether this scene gets axes + grid: always for `plot2d`/`chart`;
/// for `geometry`/`physics`/`vector` when a view is present and
/// `model.showAxes` is not false; for `circuit`/`chemistry`/`geography`
/// (diagrams, not coordinate plots) only when `model.showAxes` is
/// explicitly true.
bool visualSceneDrawsAxes(VisualScene scene) {
  if (scene.kind == VisualSceneKind.plot2d ||
      scene.kind == VisualSceneKind.chart) {
    return true;
  }
  if (scene.kind == VisualSceneKind.circuit ||
      scene.kind == VisualSceneKind.chemistry ||
      scene.kind == VisualSceneKind.geography) {
    return scene.model?.showAxes == true;
  }
  return scene.view != null && scene.model?.showAxes != false;
}

double _niceStep(double span, int targetCount) {
  final raw = span / targetCount;
  if (raw <= 0 || !raw.isFinite) return span;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  if (magnitude <= 0 || !magnitude.isFinite) return span;
  for (final mult in const [1.0, 2.0, 5.0, 10.0]) {
    final step = mult * magnitude;
    if (span / step <= targetCount + 2) return step;
  }
  return 10 * magnitude;
}

/// Bounded integer indexing avoids non-progressing floating-point sums
/// (e.g. 1e16 + 0.5 == 1e16), including for old stored scenes.
List<double> _axisTicks(double min, double max) {
  final step = _niceStep(max - min, 6);
  if (!step.isFinite || step <= 0) return const [];
  final first = (min / step).ceilToDouble() * step;
  if (!first.isFinite) return const [];
  final ticks = <double>[];
  for (var i = 0; i < 16; i++) {
    final value = first + i * step;
    if (!value.isFinite || value > max) break;
    if (value >= min && (ticks.isEmpty || value > ticks.last)) ticks.add(value);
  }
  return ticks;
}

String _formatTick(double value) {
  // Keep distinguishable ticks at large offsets and avoid int saturation.
  if (value.abs() >= 1e15) return value.toString();
  if (value == value.roundToDouble()) return value.toInt().toString();
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceAll(RegExp(r"0+$"), "").replaceAll(RegExp(r"\.$"), "");
}

/// Renders a [VisualScene] onto a canvas.
///
/// `math_label` elements are NOT painted here — the widget overlays
/// `Math.tex` widgets positioned by [VisualCoordinateMapper].
/// `parameters` holds the current slider/parameter values; [toggles] the
/// current toggle-control values (defaults to each control's `value`).
/// Step visibility comes from [hiddenElementIds] (resolved by the
/// animator); [timeMs]/[stepIndex] only identify the frame for
/// [shouldRepaint] — the painter never interprets the timeline itself.
class VisualPainter extends CustomPainter {
  VisualPainter({
    required this.scene,
    required this.palette,
    required this.parameters,
    this.toggles = const {},
    this.hiddenElementIds = const {},
    this.pointOverrides = const {},
    this.timeMs = 0,
    this.stepIndex = 0,
    this.zoom = 1.0,
    this.pan = ui.Offset.zero,
    this.tickLabelStyle = const TextStyle(fontSize: 11),
  });

  final VisualScene scene;
  final VisualPalette palette;
  final Map<String, double> parameters;
  final Map<String, bool> toggles;

  final Set<String> hiddenElementIds;

  /// Local drag positions (element id → model coordinates), set by the
  /// fullscreen page while the user drags a point. They override the
  /// scene's coordinates for painting only — never persisted, and the
  /// fit view is still computed from the scene's own coordinates, so a
  /// drag never moves the axes under the finger.
  final Map<String, ui.Offset> pointOverrides;

  final double timeMs;
  final int stepIndex;

  /// Fullscreen pinch zoom (1.0 = fit view) and pan in canvas pixels.
  /// The chat card and PNG export always render the fit view.
  final double zoom;
  final ui.Offset pan;

  /// Style for axis tick labels (resolved in `build()` from the theme's
  /// `textTheme.bodySmall`; the painter never calls `Theme.of`).
  final TextStyle tickLabelStyle;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (size.isEmpty) return;
    final mapper = VisualCoordinateMapper.fromScene(
      scene,
      size,
      zoom: zoom,
      pan: pan,
    );
    canvas.drawRect(
      ui.Offset.zero & size,
      ui.Paint()..color = palette.background,
    );
    if (visualSceneDrawsAxes(scene)) {
      _paintAxes(canvas, mapper);
    }
    final modelExpression = scene.model?.expression;
    if (modelExpression != null &&
        (scene.kind == VisualSceneKind.plot2d ||
            scene.kind == VisualSceneKind.chart)) {
      _paintCurve(
        canvas,
        mapper,
        modelExpression,
        palette.primary,
        width: 2.5,
        maxSamples: 1024,
      );
    }
    for (final element in _visibleElements(scene, toggles, hiddenElementIds)) {
      _paintElement(canvas, mapper, element);
    }
    for (final annotation in scene.annotations) {
      final at = resolvePoint(annotation.at, parameters);
      if (at == null) continue;
      _paintText(
        canvas,
        mapper.modelToCanvas(at) + const ui.Offset(4, -8),
        annotation.text,
        const TextStyle(fontSize: 12),
        palette.textMuted,
      );
    }
  }

  void _paintAxes(ui.Canvas canvas, VisualCoordinateMapper mapper) {
    final rect = mapper.canvasRect;
    final model = mapper.modelRect;
    final xTicks = _axisTicks(model.left, model.right);
    final yTicks = _axisTicks(model.top, model.bottom);
    final gridPaint = ui.Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    for (final x in xTicks) {
      final px = mapper.modelToCanvas(ui.Offset(x, 0)).dx;
      canvas.drawLine(
        ui.Offset(px, rect.top),
        ui.Offset(px, rect.bottom),
        gridPaint,
      );
    }
    for (final y in yTicks) {
      final py = mapper.modelToCanvas(ui.Offset(0, y)).dy;
      canvas.drawLine(
        ui.Offset(rect.left, py),
        ui.Offset(rect.right, py),
        gridPaint,
      );
    }
    final axisPaint = ui.Paint()
      ..color = palette.axis
      ..strokeWidth = 1.5;
    if (model.left <= 0 && model.right >= 0) {
      final px = mapper.modelToCanvas(ui.Offset.zero).dx;
      canvas.drawLine(
        ui.Offset(px, rect.top),
        ui.Offset(px, rect.bottom),
        axisPaint,
      );
    }
    if (model.top <= 0 && model.bottom >= 0) {
      final py = mapper.modelToCanvas(ui.Offset.zero).dy;
      canvas.drawLine(
        ui.Offset(rect.left, py),
        ui.Offset(rect.right, py),
        axisPaint,
      );
    }
    final labelStyle = tickLabelStyle.copyWith(color: palette.textMuted);
    final xAxisY = model.top <= 0 && model.bottom >= 0
        ? mapper.modelToCanvas(ui.Offset.zero).dy
        : rect.bottom;
    for (final x in xTicks) {
      final px = mapper.modelToCanvas(ui.Offset(x, 0)).dx;
      _paintText(
        canvas,
        ui.Offset(px, xAxisY + 4),
        _formatTick(x),
        labelStyle,
        palette.textMuted,
        centerX: true,
      );
    }
    final yAxisX = model.left <= 0 && model.right >= 0
        ? mapper.modelToCanvas(ui.Offset.zero).dx
        : rect.left;
    for (final y in yTicks) {
      // The x-axis "0" already marks the origin; skip the y-axis "0"
      // when the origin is inside the view, or the two labels overlap.
      final isOrigin =
          y == 0 &&
          model.left <= 0 &&
          model.right >= 0 &&
          model.top <= 0 &&
          model.bottom >= 0;
      if (!isOrigin) {
        final py = mapper.modelToCanvas(ui.Offset(0, y)).dy;
        _paintText(
          canvas,
          ui.Offset(yAxisX - 4, py),
          _formatTick(y),
          labelStyle,
          palette.textMuted,
          alignRight: true,
          centerY: true,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant VisualPainter oldDelegate) {
    return oldDelegate.scene != scene ||
        oldDelegate.palette != palette ||
        !mapEquals(oldDelegate.parameters, parameters) ||
        !mapEquals(oldDelegate.toggles, toggles) ||
        !setEquals(oldDelegate.hiddenElementIds, hiddenElementIds) ||
        !mapEquals(oldDelegate.pointOverrides, pointOverrides) ||
        oldDelegate.timeMs != timeMs ||
        oldDelegate.stepIndex != stepIndex ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan ||
        oldDelegate.tickLabelStyle != tickLabelStyle;
  }
}
