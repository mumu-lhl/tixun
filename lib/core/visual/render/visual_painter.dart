import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart'
    show CustomPainter, TextPainter, TextSpan, TextStyle;

import 'package:tixun/core/visual/math/sampling.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';

import 'circuit_geometry.dart';
import 'visual_theme.dart';

/// Maps model coordinates to canvas coordinates, preserving aspect ratio
/// via letterboxing (the model view rect is fit into the canvas and
/// centered). The y axis points up.
class VisualCoordinateMapper {
  VisualCoordinateMapper._({
    required this.modelRect,
    required this.canvasRect,
    required this.scale,
    this.zoom = 1.0,
    this.pan = ui.Offset.zero,
  });

  /// The model-space rect being shown (view range or auto-fit).
  final ui.Rect modelRect;

  /// The canvas rect the model rect maps into (letterboxed).
  final ui.Rect canvasRect;

  /// Canvas pixels per model unit (uniform on both axes).
  final double scale;

  /// Fullscreen pinch zoom about the view centre (1.0 = fit view).
  final double zoom;

  /// Fullscreen pan in canvas pixels (added after the zoom).
  final ui.Offset pan;

  /// Model size of the shown view.
  ui.Size get viewSize => modelRect.size;

  factory VisualCoordinateMapper.fromScene(
    VisualScene scene,
    ui.Size canvasSize, {
    double zoom = 1.0,
    ui.Offset pan = ui.Offset.zero,
  }) {
    final modelRect = _resolveViewRect(scene);
    if (canvasSize.isEmpty) {
      return VisualCoordinateMapper._(
        modelRect: modelRect,
        canvasRect: ui.Rect.zero,
        scale: 1,
        zoom: zoom,
        pan: pan,
      );
    }
    final scale = math.min(
      canvasSize.width / modelRect.width,
      canvasSize.height / modelRect.height,
    );
    final width = modelRect.width * scale;
    final height = modelRect.height * scale;
    final canvasRect = ui.Rect.fromLTWH(
      (canvasSize.width - width) / 2,
      (canvasSize.height - height) / 2,
      width,
      height,
    );
    return VisualCoordinateMapper._(
      modelRect: modelRect,
      canvasRect: canvasRect,
      scale: scale,
      zoom: zoom,
      pan: pan,
    );
  }

  ui.Offset modelToCanvas(ui.Offset model) {
    final base = ui.Offset(
      canvasRect.left + (model.dx - modelRect.left) * scale,
      canvasRect.bottom - (model.dy - modelRect.top) * scale,
    );
    if (zoom == 1.0 && pan == ui.Offset.zero) return base;
    final center = canvasRect.center;
    return center + (base - center) * zoom + pan;
  }

  /// Inverse of [modelToCanvas]: a canvas position back to model
  /// coordinates (used for drag hit-testing). The y axis points up, so
  /// the canvas y is measured from the bottom of the letterboxed rect.
  ui.Offset canvasToModel(ui.Offset canvas) {
    var point = canvas;
    if (zoom != 1.0 || pan != ui.Offset.zero) {
      final center = canvasRect.center;
      point = center + (canvas - pan - center) / zoom;
    }
    return ui.Offset(
      modelRect.left + (point.dx - canvasRect.left) / scale,
      modelRect.top + (canvasRect.bottom - point.dy) / scale,
    );
  }

  /// Screen positions of the scene's `math_label` elements (for the
  /// widget's `Math.tex` overlays). Labels hidden by visibility rules are
  /// omitted.
  List<({ui.Offset at, String tex})> mathLabelPositions(
    VisualScene scene,
    Map<String, double> parameters, {
    Map<String, bool> toggles = const {},
    Set<String> hiddenElementIds = const {},
  }) {
    final out = <({ui.Offset at, String tex})>[];
    for (final element in _visibleElements(scene, toggles, hiddenElementIds)) {
      if (element is! MathLabelElement) continue;
      final at = resolvePoint(element.at, parameters);
      if (at == null) continue;
      out.add((at: modelToCanvas(at), tex: element.tex));
    }
    return out;
  }
}

/// The model-space rect to show: explicit `view` when both axes are
/// present, otherwise auto-fit from literal element coordinates + sampled
/// curves with 10% padding (missing axes are auto-fit individually).
ui.Rect _resolveViewRect(VisualScene scene) {
  final view = scene.view;
  final points = <ui.Offset>[];
  for (final element in _flattenElements(scene.elements)) {
    _collectPoints(element, scene, points);
  }
  for (final annotation in scene.annotations) {
    final at = annotation.at.literal;
    if (at != null) points.add(ui.Offset(at.$1, at.$2));
  }
  final modelExpression = scene.model?.expression;
  if (modelExpression != null) {
    final range = view?.x != null ? (view!.x!.min, view.x!.max) : (-10.0, 10.0);
    _collectCurvePoints(
      modelExpression,
      scene.model?.parameters ?? const {},
      range.$1,
      range.$2,
      points,
    );
  }
  double xMin = view?.x?.min ?? double.infinity;
  double xMax = view?.x?.max ?? double.negativeInfinity;
  double yMin = view?.y?.min ?? double.infinity;
  double yMax = view?.y?.max ?? double.negativeInfinity;
  if (points.isNotEmpty) {
    for (final p in points) {
      if (view?.x == null) {
        if (p.dx < xMin) xMin = p.dx;
        if (p.dx > xMax) xMax = p.dx;
      }
      if (view?.y == null) {
        if (p.dy < yMin) yMin = p.dy;
        if (p.dy > yMax) yMax = p.dy;
      }
    }
  }
  if (xMin.isInfinite || xMax.isInfinite) {
    xMin = -10;
    xMax = 10;
  }
  if (yMin.isInfinite || yMax.isInfinite) {
    yMin = -10;
    yMax = 10;
  }
  if (xMin == xMax) {
    xMin -= 0.5;
    xMax += 0.5;
  }
  if (yMin == yMax) {
    yMin -= 0.5;
    yMax += 0.5;
  }
  // 10% padding on the auto-fit axes only; explicit view ranges are used
  // as-is.
  if (view?.x == null) {
    final pad = (xMax - xMin) * 0.1;
    xMin -= pad;
    xMax += pad;
  }
  if (view?.y == null) {
    final pad = (yMax - yMin) * 0.1;
    yMin -= pad;
    yMax += pad;
  }
  return ui.Rect.fromLTRB(xMin, yMin, xMax, yMax);
}

void _collectCurvePoints(
  String expression,
  Map<String, double> parameters,
  double min,
  double max,
  List<ui.Offset> out,
) {
  try {
    final segments = sampleFunction(
      expression,
      variables: parameters,
      min: min,
      max: max,
      maxSamples: 256,
    );
    for (final segment in segments) {
      out.addAll(segment.points);
    }
  } catch (_) {
    // A bad expression must not break auto-fit; the validator rejects it
    // before it reaches the renderer in normal flows.
  }
}

void _collectPoints(
  VisualElement element,
  VisualScene scene,
  List<ui.Offset> out,
) {
  ui.Offset? literal(VisualPoint p) {
    final pair = p.literal;
    return pair == null ? null : ui.Offset(pair.$1, pair.$2);
  }

  void add(VisualPoint? p) {
    if (p == null) return;
    final point = literal(p);
    if (point != null) out.add(point);
  }

  switch (element) {
    case PointElement(at: final at):
    case TextElement(at: final at):
    case MathLabelElement(at: final at):
      add(at);
    case LineElement(p1: final p1, p2: final p2):
    case ArrowElement(from: final p1, to: final p2):
      add(p1);
      add(p2);
    case PolylineElement(points: final points):
    case PolygonElement(points: final points):
      for (final p in points) {
        add(p);
      }
    case CircleElement(center: final center, r: final r):
    case ArcElement(center: final center, r: final r):
      final c = literal(center);
      if (c != null) {
        out.addAll([
          ui.Offset(c.dx - r, c.dy - r),
          ui.Offset(c.dx + r, c.dy + r),
        ]);
      }
    case CircuitElement(from: final from, to: final to, at: final at):
      add(from);
      add(to);
      add(at);
    case PlotElement(expression: final expression, domain: final domain):
      final range = domain ?? (-10.0, 10.0);
      _collectCurvePoints(
        expression,
        scene.model?.parameters ?? const {},
        range.$1,
        range.$2,
        out,
      );
    case GroupElement():
      break; // Children are already flattened by the caller.
  }
}

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
  final flat = _flattenElements(scene.elements);
  final visible = <(int, VisualElement)>[];
  for (var i = 0; i < flat.length; i++) {
    final element = flat[i];
    if (_elementVisible(element, scene, toggles, hiddenElementIds)) {
      visible.add((i, element));
    }
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

/// Even-odd ray casting: a point on an edge counts as inside.
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
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  for (final mult in const [1.0, 2.0, 5.0, 10.0]) {
    final step = mult * magnitude;
    if (span / step <= targetCount + 2) return step;
  }
  return 10 * magnitude;
}

String _formatTick(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
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

  /// Element ids hidden by the current teaching step (animator output).
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
    final xStep = _niceStep(model.width, 6);
    final yStep = _niceStep(model.height, 6);
    final gridPaint = ui.Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    // Gridlines.
    var x = (model.left / xStep).ceil() * xStep;
    while (x <= model.right) {
      final px = mapper.modelToCanvas(ui.Offset(x, 0)).dx;
      canvas.drawLine(
        ui.Offset(px, rect.top),
        ui.Offset(px, rect.bottom),
        gridPaint,
      );
      x += xStep;
    }
    var y = (model.top / yStep).ceil() * yStep;
    while (y <= model.bottom) {
      final py = mapper.modelToCanvas(ui.Offset(0, y)).dy;
      canvas.drawLine(
        ui.Offset(rect.left, py),
        ui.Offset(rect.right, py),
        gridPaint,
      );
      y += yStep;
    }
    // Axis lines (x = 0 / y = 0) when inside the view.
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
    // Tick labels.
    final labelStyle = tickLabelStyle.copyWith(color: palette.textMuted);
    final xAxisY = model.top <= 0 && model.bottom >= 0
        ? mapper.modelToCanvas(ui.Offset.zero).dy
        : rect.bottom;
    x = (model.left / xStep).ceil() * xStep;
    while (x <= model.right) {
      final px = mapper.modelToCanvas(ui.Offset(x, 0)).dx;
      _paintText(
        canvas,
        ui.Offset(px, xAxisY + 4),
        _formatTick(x),
        labelStyle,
        palette.textMuted,
        centerX: true,
      );
      x += xStep;
    }
    final yAxisX = model.left <= 0 && model.right >= 0
        ? mapper.modelToCanvas(ui.Offset.zero).dx
        : rect.left;
    y = (model.top / yStep).ceil() * yStep;
    while (y <= model.bottom) {
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
      y += yStep;
    }
  }

  void _paintText(
    ui.Canvas canvas,
    ui.Offset at,
    String text,
    TextStyle style,
    ui.Color color, {
    bool centerX = false,
    bool alignRight = false,
    bool centerY = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(color: color),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    var offset = at;
    if (centerX) offset -= ui.Offset(painter.width / 2, 0);
    if (alignRight) offset -= ui.Offset(painter.width, 0);
    if (centerY) offset -= ui.Offset(0, painter.height / 2);
    painter.paint(canvas, offset);
  }

  void _paintCurve(
    ui.Canvas canvas,
    VisualCoordinateMapper mapper,
    String expression,
    ui.Color color, {
    double width = 2,
    bool dashed = false,
    int maxSamples = 1024,
    (double, double)? domain,
  }) {
    final range = domain ?? (mapper.modelRect.left, mapper.modelRect.right);
    List<SampledSegment> segments;
    try {
      segments = sampleFunction(
        expression,
        variables: parameters,
        min: range.$1,
        max: range.$2,
        maxSamples: maxSamples,
      );
    } catch (_) {
      return; // Bad expression: skip silently, never crash paint().
    }
    final paint = ui.Paint()
      ..color = color
      ..strokeWidth = width
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round;
    for (final segment in segments) {
      if (segment.points.length < 2) continue;
      final points = [for (final p in segment.points) mapper.modelToCanvas(p)];
      if (dashed) {
        _drawDashedPath(canvas, points, paint);
      } else {
        final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
        for (final p in points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  /// Draws a polyline as dashes (6px on, 4px off).
  void _drawDashedPath(
    ui.Canvas canvas,
    List<ui.Offset> points,
    ui.Paint paint,
  ) {
    const dash = 6.0;
    const gap = 4.0;
    var draw = true;
    var remaining = dash;
    for (var i = 0; i + 1 < points.length; i++) {
      var a = points[i];
      final b = points[i + 1];
      var left = (b - a).distance;
      while (left > 0) {
        final step = math.min(remaining, left);
        final dir = (b - a) / (b - a).distance;
        final end = a + dir * step;
        if (draw) canvas.drawLine(a, end, paint);
        a = end;
        left -= step;
        remaining -= step;
        if (remaining <= 0) {
          draw = !draw;
          remaining = draw ? dash : gap;
        }
      }
    }
  }

  void _paintElement(
    ui.Canvas canvas,
    VisualCoordinateMapper mapper,
    VisualElement element,
  ) {
    final color = palette.colorForStyle(element.style);
    // Success is drawn dashed (same hue as primary): color alone never
    // carries meaning.
    final dashed = element.style == VisualStyle.success;
    ui.Paint stroke({double width = 2}) => ui.Paint()
      ..color = color
      ..strokeWidth = width
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round;

    switch (element) {
      case PointElement(at: final at, label: final label):
        final point =
            pointOverrides[element.id] ?? resolvePoint(at, parameters);
        if (point == null) return;
        final center = mapper.modelToCanvas(point);
        canvas.drawCircle(center, 4, ui.Paint()..color = color);
        if (label != null) {
          _paintText(
            canvas,
            center + const ui.Offset(7, -7),
            label,
            const TextStyle(fontSize: 12),
            palette.textMuted,
          );
        }
      case LineElement(p1: final p1, p2: final p2, dashed: final isDashed):
        final a = resolvePoint(p1, parameters);
        final b = resolvePoint(p2, parameters);
        if (a == null || b == null) return;
        final pa = mapper.modelToCanvas(a);
        final pb = mapper.modelToCanvas(b);
        if (isDashed || dashed) {
          _drawDashedPath(canvas, [pa, pb], stroke());
        } else {
          canvas.drawLine(pa, pb, stroke());
        }
      case PolylineElement(points: final points):
        final resolved = [for (final p in points) resolvePoint(p, parameters)];
        if (resolved.any((p) => p == null) || resolved.length < 2) return;
        final canvasPoints = [
          for (final p in resolved) mapper.modelToCanvas(p!),
        ];
        _drawDashedPathOrLine(canvas, canvasPoints, stroke(), dashed);
      case PolygonElement(points: final points, fill: final fill):
        final resolved = [for (final p in points) resolvePoint(p, parameters)];
        if (resolved.any((p) => p == null) || resolved.length < 3) return;
        final canvasPoints = [
          for (final p in resolved) mapper.modelToCanvas(p!),
        ];
        final path = ui.Path()
          ..moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
        for (final p in canvasPoints.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        path.close();
        if (fill) {
          canvas.drawPath(
            path,
            ui.Paint()
              ..color = color.withValues(alpha: 0.15)
              ..style = ui.PaintingStyle.fill,
          );
        }
        canvas.drawPath(path, stroke());
      case CircleElement(center: final center, r: final r):
        final c = resolvePoint(center, parameters);
        if (c == null) return;
        canvas.drawCircle(mapper.modelToCanvas(c), r * mapper.scale, stroke());
      case ArcElement(
        center: final center,
        r: final r,
        startDeg: final startDeg,
        sweepDeg: final sweepDeg,
      ):
        final c = resolvePoint(center, parameters);
        if (c == null) return;
        // Model angles are counter-clockwise from +x with y up; canvas
        // angles run clockwise with y down, hence the sign flip.
        canvas.drawArc(
          ui.Rect.fromCircle(
            center: mapper.modelToCanvas(c),
            radius: r * mapper.scale,
          ),
          -startDeg * math.pi / 180,
          -sweepDeg * math.pi / 180,
          false,
          stroke(),
        );
      case ArrowElement(from: final from, to: final to):
        final a = resolvePoint(from, parameters);
        final b = resolvePoint(to, parameters);
        if (a == null || b == null) return;
        final pa = mapper.modelToCanvas(a);
        final pb = mapper.modelToCanvas(b);
        final paint = stroke(width: 2);
        if (dashed) {
          _drawDashedPath(canvas, [pa, pb], paint);
        } else {
          canvas.drawLine(pa, pb, paint);
        }
        final dir = (pb - pa);
        final length = dir.distance;
        if (length > 0) {
          final unit = dir / length;
          const headLength = 12.0;
          const headAngle = 25 * math.pi / 180;
          for (final sign in const [1.0, -1.0]) {
            final angle = math.atan2(unit.dy, unit.dx) + sign * headAngle;
            final tip = ui.Offset(
              math.cos(angle + math.pi),
              math.sin(angle + math.pi),
            );
            canvas.drawLine(pb, pb + tip * headLength, paint);
          }
        }
      case TextElement(at: final at, text: final text):
        final point = resolvePoint(at, parameters);
        if (point == null) return;
        _paintText(
          canvas,
          mapper.modelToCanvas(point) + const ui.Offset(4, -8),
          text,
          const TextStyle(fontSize: 14),
          color,
        );
      case MathLabelElement():
        // Rendered as a Math.tex overlay by the widget, never on canvas.
        return;
      case GroupElement():
        // Flattened before painting; unreachable.
        return;
      case PlotElement(
        expression: final expression,
        domain: final domain,
        samples: final samples,
      ):
        _paintCurve(
          canvas,
          mapper,
          expression,
          color,
          width: 2,
          dashed: dashed,
          maxSamples: samples ?? 1024,
          domain: domain,
        );
      case CircuitElement(
        component: final component,
        from: final from,
        to: final to,
        at: final at,
        closed: final closed,
        meter: final meter,
        label: final label,
      ):
        // A const-constructed element may lack the fields its component
        // requires; fromJson guarantees them, so treat a missing one as
        // unresolvable (skip the element) rather than throwing.
        ui.Offset? pointOf(VisualPoint? p) =>
            p == null ? null : resolvePoint(p, parameters);
        ui.Offset? mid;
        switch (component) {
          case CircuitComponent.wire:
            final a = pointOf(from);
            final b = pointOf(to);
            if (a == null || b == null) return;
            mid = (a + b) / 2;
            final pa = mapper.modelToCanvas(a);
            final pb = mapper.modelToCanvas(b);
            if (dashed) {
              _drawDashedPath(canvas, [pa, pb], stroke());
            } else {
              canvas.drawLine(pa, pb, stroke());
            }
            final dot = ui.Paint()..color = color;
            canvas.drawCircle(pa, 2.5, dot);
            canvas.drawCircle(pb, 2.5, dot);
          case CircuitComponent.resistor:
            final a = pointOf(from);
            final b = pointOf(to);
            if (a == null || b == null) return;
            mid = (a + b) / 2;
            final canvasPoints = [
              for (final p in circuitZigzagPoints(a, b))
                mapper.modelToCanvas(p),
            ];
            final path = ui.Path()
              ..moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
            for (final p in canvasPoints.skip(1)) {
              path.lineTo(p.dx, p.dy);
            }
            canvas.drawPath(path, stroke());
          case CircuitComponent.battery:
            final a = pointOf(from);
            final b = pointOf(to);
            if (a == null || b == null) return;
            mid = (a + b) / 2;
            final plates = circuitBatteryPlates(a, b);
            final longCenter = (plates.longA + plates.longB) / 2;
            final shortCenter = (plates.shortA + plates.shortB) / 2;
            canvas.drawLine(
              mapper.modelToCanvas(a),
              mapper.modelToCanvas(longCenter),
              stroke(),
            );
            canvas.drawLine(
              mapper.modelToCanvas(shortCenter),
              mapper.modelToCanvas(b),
              stroke(),
            );
            canvas.drawLine(
              mapper.modelToCanvas(plates.longA),
              mapper.modelToCanvas(plates.longB),
              stroke(width: 2.5),
            );
            canvas.drawLine(
              mapper.modelToCanvas(plates.shortA),
              mapper.modelToCanvas(plates.shortB),
              stroke(width: 2.5),
            );
          case CircuitComponent.powerSwitch:
            final a = pointOf(from);
            final b = pointOf(to);
            if (a == null || b == null) return;
            mid = (a + b) / 2;
            for (final (s, e) in circuitSwitchSegments(a, b, closed)) {
              final ps = mapper.modelToCanvas(s);
              final pe = mapper.modelToCanvas(e);
              if (dashed && closed) {
                _drawDashedPath(canvas, [ps, pe], stroke());
              } else {
                canvas.drawLine(ps, pe, stroke());
              }
            }
            if (!closed) {
              // Contact dot at the open end (65% along).
              final contact = a + (b - a) * 0.65;
              canvas.drawCircle(
                mapper.modelToCanvas(contact),
                2.5,
                ui.Paint()..color = color,
              );
            }
          case CircuitComponent.meter:
            final point = pointOf(at);
            if (point == null) return;
            mid = point;
            final center = mapper.modelToCanvas(point);
            canvas.drawCircle(center, 14, stroke());
            _paintText(
              canvas,
              center + const ui.Offset(-4, -8),
              meter == CircuitMeterKind.ammeter ? 'A' : 'V',
              const TextStyle(fontSize: 14),
              color,
            );
        }
        if (label != null) {
          _paintText(
            canvas,
            mapper.modelToCanvas(mid) + const ui.Offset(7, -7),
            label,
            const TextStyle(fontSize: 12),
            palette.textMuted,
          );
        }
    }
  }

  void _drawDashedPathOrLine(
    ui.Canvas canvas,
    List<ui.Offset> points,
    ui.Paint paint,
    bool dashed,
  ) {
    if (dashed) {
      _drawDashedPath(canvas, points, paint);
      return;
    }
    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
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
