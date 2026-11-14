import 'dart:math' as math;

import '../math/expression.dart';
import '../math/sampling.dart';
import '../model/visual_scene.dart';

/// One finding of the static quality auto-check (Phase 4).
///
/// Not a validation error: the scene is valid and renders, but something
/// about it is likely wrong for teaching. The create/update tools attach
/// these to their result so the model can fix the figure in the next
/// round instead of shipping a silently bad one.
class VisualQualityIssue {
  const VisualQualityIssue({
    required this.code,
    required this.message,
    this.path,
  });

  /// Stable code: `missing_alt`, `empty_scene`, `point_outside_view`,
  /// `curve_not_visible`, `derived_mismatch`.
  final String code;

  /// Human-readable (Chinese) description.
  final String message;

  /// Element id or JSON path the issue is about, when it has one.
  final String? path;

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (path != null) 'path': path,
  };
}

/// Static quality auto-check for a scene.
///
/// Catches the mistakes that pass validation but make a bad teaching
/// figure: a figure with no text alternative, nothing in it, a point
/// outside the declared view, a curve with no visible samples, or
/// derived values that do not reproduce the curve. Pure and total:
/// never throws (a check that cannot run is skipped).
List<VisualQualityIssue> checkVisualQuality(VisualScene scene) {
  final issues = <VisualQualityIssue>[];
  final alt = scene.meta?.alt?.trim() ?? '';
  final title = scene.title?.trim() ?? '';
  if (alt.isEmpty && title.isEmpty) {
    issues.add(
      const VisualQualityIssue(
        code: 'missing_alt',
        message: '图形缺少文字说明（alt 或标题），读屏器无法描述它。',
      ),
    );
  }
  if (scene.model?.expression == null &&
      scene.elements.isEmpty &&
      scene.annotations.isEmpty) {
    issues.add(
      const VisualQualityIssue(code: 'empty_scene', message: '图形没有任何内容。'),
    );
  }

  // Points outside the declared view: the view is explicit, so a
  // literal coordinate outside it never renders. (Without an explicit
  // view the auto-fit always contains every literal point.) Circles
  // and arcs are checked by their full extent instead of the centre:
  // a circle whose centre is outside the view but whose arc reaches
  // inside it is visible, and must not be reported.
  final view = scene.view;
  if (view?.x != null && view?.y != null) {
    final xMin = view!.x!.min;
    final xMax = view.x!.max;
    final yMin = view.y!.min;
    final yMax = view.y!.max;
    var outsideCount = 0;
    for (final element in _allElements(scene.elements)) {
      if (outsideCount >= 5) break;
      final extent = _shapeExtent(element);
      if (extent != null) {
        if (extent.maxX < xMin ||
            extent.minX > xMax ||
            extent.maxY < yMin ||
            extent.minY > yMax) {
          issues.add(
            VisualQualityIssue(
              code: 'point_outside_view',
              message: '图元 ${element.id} 的图形完全在视图范围外，不会显示。',
              path: element.id,
            ),
          );
          outsideCount++;
        }
        continue;
      }
      for (final point in _literalPoints(element)) {
        if (point.dx < xMin ||
            point.dx > xMax ||
            point.dy < yMin ||
            point.dy > yMax) {
          issues.add(
            VisualQualityIssue(
              code: 'point_outside_view',
              message:
                  '图元 ${element.id} 的坐标 (${_fmt(point.dx)}, ${_fmt(point.dy)}) 在视图范围外，不会显示。',
              path: element.id,
            ),
          );
          outsideCount++;
          if (outsideCount >= 5) break;
        }
      }
    }
  }

  // Curves with no visible samples: the expression parses (validation
  // passed) but draws nothing inside the view. Sampled at the same
  // resolution the canvas uses (1024, or the plot element's own
  // sample count), so the check and the renderer agree on what counts
  // as visible — including single-point segments, which the canvas
  // draws as dots.
  final parameters = scene.model?.parameters ?? const <String, double>{};
  final modelExpression = scene.model?.expression;
  if (modelExpression != null) {
    final range = view?.x != null ? (view!.x!.min, view.x!.max) : (-10.0, 10.0);
    if (!_hasSamples(modelExpression, parameters, range.$1, range.$2)) {
      issues.add(
        const VisualQualityIssue(
          code: 'curve_not_visible',
          message: '函数图像在视图内没有任何可见点。',
        ),
      );
    }
  }
  for (final element in _allElements(scene.elements)) {
    if (element is! PlotElement) continue;
    final range =
        element.domain ??
        (view?.x != null ? (view!.x!.min, view.x!.max) : (-10.0, 10.0));
    if (!_hasSamples(
      element.expression,
      parameters,
      range.$1,
      range.$2,
      maxSamples: element.samples ?? 1024,
    )) {
      issues.add(
        VisualQualityIssue(
          code: 'curve_not_visible',
          message: '图元 ${element.id} 的函数图像在视图内没有任何可见点。',
          path: element.id,
        ),
      );
    }
  }

  // Derived values must reproduce the curve: re-evaluate the model
  // expression at each reported zero/extremum independently. The
  // tolerance is relative to the function's own scale: a zero refined
  // to ~1e-9 in x re-evaluates to ~|f'| * 1e-9, which is far above an
  // absolute 1e-6 on a steep slope (e.g. 1e9*(x-0.5) re-evaluates to
  // ~0.5) without anything being wrong. Derived values come from the
  // same expression and the same evaluator, so re-evaluation
  // reproduces them up to this relative tolerance by construction;
  // the check stays as a defensive guard, not a live tripwire.
  if (modelExpression != null) {
    try {
      final expr = Expression.parse(modelExpression);
      final derived = computeDerivedValues(scene);
      final range = view?.x != null
          ? (view!.x!.min, view.x!.max)
          : (-10.0, 10.0);
      final yScale = _yScale(modelExpression, parameters, range.$1, range.$2);
      final zeroTol = 1e-6 * math.max(1.0, yScale);
      for (final zero in (derived['zeros'] as List).cast<double>()) {
        final y = _tryEvaluate(expr, parameters, zero);
        if (y == null || y.abs() > zeroTol) {
          issues.add(
            VisualQualityIssue(
              code: 'derived_mismatch',
              message: '计算出的零点 x=${_fmt(zero)} 处函数值不是 0。',
            ),
          );
          break;
        }
      }
      for (final extremum in (derived['extrema'] as List).cast<Map>()) {
        final x = (extremum['x'] as num).toDouble();
        final y = (extremum['y'] as num).toDouble();
        final actual = _tryEvaluate(expr, parameters, x);
        final extremumTol =
            1e-6 * math.max(1.0, math.max(y.abs(), actual?.abs() ?? 0.0));
        if (actual == null || (actual - y).abs() > extremumTol) {
          issues.add(
            VisualQualityIssue(
              code: 'derived_mismatch',
              message: '计算出的极值点 x=${_fmt(x)} 处函数值与报告值不一致。',
            ),
          );
          break;
        }
      }
    } catch (_) {
      // A check that cannot run is skipped, never a crash.
    }
  }
  return issues;
}

/// Largest |y| the expression takes over [min, max] (256 samples), or
/// 0 when it has no finite sample. The scale for the relative
/// derived-value tolerance.
double _yScale(
  String expression,
  Map<String, double> parameters,
  double min,
  double max,
) {
  try {
    final segments = sampleFunction(
      expression,
      variables: parameters,
      min: min,
      max: max,
      maxSamples: 256,
    );
    var scale = 0.0;
    for (final segment in segments) {
      for (final point in segment.points) {
        final magnitude = point.dy.abs();
        if (magnitude > scale) scale = magnitude;
      }
    }
    return scale;
  } catch (_) {
    return 0.0;
  }
}

bool _hasSamples(
  String expression,
  Map<String, double> parameters,
  double min,
  double max, {
  int maxSamples = 1024,
}) {
  try {
    final segments = sampleFunction(
      expression,
      variables: parameters,
      min: min,
      max: max,
      maxSamples: maxSamples,
    );
    return segments.any((s) => s.points.isNotEmpty);
  } catch (_) {
    return false;
  }
}

double? _tryEvaluate(
  Expression expr,
  Map<String, double> parameters,
  double x,
) {
  try {
    final value = expr.evaluate({...parameters, 'x': x});
    return value.isFinite ? value : null;
  } catch (_) {
    return null;
  }
}

List<VisualElement> _allElements(List<VisualElement> elements) {
  final out = <VisualElement>[];
  for (final element in elements) {
    out.add(element);
    if (element is GroupElement) out.addAll(_allElements(element.children));
  }
  return out;
}

/// Bounding box of a circle or arc element in model coordinates, or
/// null for other element types (and for `$param`-bound centres, whose
/// extent depends on the controls).
///
/// For an arc the box covers the swept arc itself (endpoints plus any
/// cardinal direction inside the sweep), not the full circle: an arc
/// that only spans the right half has a much smaller box than its
/// circle would.
({double minX, double maxX, double minY, double maxY})? _shapeExtent(
  VisualElement element,
) {
  switch (element) {
    case CircleElement(center: final center, r: final r):
      final c = center.literal;
      if (c == null) return null;
      return (minX: c.$1 - r, maxX: c.$1 + r, minY: c.$2 - r, maxY: c.$2 + r);
    case ArcElement(
      center: final center,
      r: final r,
      startDeg: final startDeg,
      sweepDeg: final sweepDeg,
    ):
      final c = center.literal;
      if (c == null) return null;
      (double, double) at(double deg) {
        final rad = deg * math.pi / 180;
        return (c.$1 + r * math.cos(rad), c.$2 + r * math.sin(rad));
      }

      final points = [at(startDeg), at(startDeg + sweepDeg)];
      final low = math.min(startDeg, startDeg + sweepDeg);
      final high = math.max(startDeg, startDeg + sweepDeg);
      for (final deg in const [0.0, 90.0, 180.0, 270.0]) {
        // Smallest angle congruent to deg (mod 360) at or above low.
        final k = ((low - deg) / 360).ceil();
        final candidate = deg + 360 * k;
        if (candidate <= high) points.add(at(candidate));
      }
      var minX = double.infinity;
      var maxX = double.negativeInfinity;
      var minY = double.infinity;
      var maxY = double.negativeInfinity;
      for (final p in points) {
        if (p.$1 < minX) minX = p.$1;
        if (p.$1 > maxX) maxX = p.$1;
        if (p.$2 < minY) minY = p.$2;
        if (p.$2 > maxY) maxY = p.$2;
      }
      return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
    default:
      return null;
  }
}

/// Literal coordinates carried by [element] (bound `$param` points are
/// skipped: their value depends on the controls). Circles and arcs are
/// not listed here: their extent is checked by [_shapeExtent] instead
/// of their centre.
List<({double dx, double dy})> _literalPoints(VisualElement element) {
  final out = <({double dx, double dy})>[];
  void add(VisualPoint? point) {
    final literal = point?.literal;
    if (literal != null) out.add((dx: literal.$1, dy: literal.$2));
  }

  void addAll(List<VisualPoint> points) {
    for (final point in points) {
      add(point);
    }
  }

  switch (element) {
    case PointElement(at: final at):
      add(at);
    case LineElement(p1: final p1, p2: final p2):
      add(p1);
      add(p2);
    case PolylineElement(points: final points):
      addAll(points);
    case PolygonElement(points: final points):
      addAll(points);
    case ArrowElement(from: final from, to: final to):
      add(from);
      add(to);
    case TextElement(at: final at):
      add(at);
    case MathLabelElement(at: final at):
      add(at);
    case CircuitElement(from: final from, to: final to, at: final at):
      add(from);
      add(to);
      add(at);
    default:
      break;
  }
  return out;
}

String _fmt(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value
      .toStringAsFixed(4)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}
