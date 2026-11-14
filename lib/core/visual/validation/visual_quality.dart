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
  if (scene.model?.expression == null && scene.elements.isEmpty) {
    issues.add(
      const VisualQualityIssue(code: 'empty_scene', message: '图形没有任何内容。'),
    );
  }

  // Points outside the declared view: the view is explicit, so a
  // literal coordinate outside it never renders. (Without an explicit
  // view the auto-fit always contains every literal point.)
  final view = scene.view;
  if (view?.x != null && view?.y != null) {
    final xMin = view!.x!.min;
    final xMax = view.x!.max;
    final yMin = view.y!.min;
    final yMax = view.y!.max;
    for (final element in _allElements(scene.elements)) {
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
          if (issues.where((i) => i.code == 'point_outside_view').length >= 5) {
            break;
          }
        }
      }
      if (issues.where((i) => i.code == 'point_outside_view').length >= 5) {
        break;
      }
    }
  }

  // Curves with no visible samples: the expression parses (validation
  // passed) but draws nothing inside the view.
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
    if (!_hasSamples(element.expression, parameters, range.$1, range.$2)) {
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
  // expression at each reported zero/extremum independently.
  if (modelExpression != null) {
    try {
      final expr = Expression.parse(modelExpression);
      final derived = computeDerivedValues(scene);
      for (final zero in (derived['zeros'] as List).cast<double>()) {
        final y = _tryEvaluate(expr, parameters, zero);
        if (y == null || y.abs() > 1e-6) {
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
        if (actual == null || (actual - y).abs() > 1e-6) {
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

bool _hasSamples(
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

/// Literal coordinates carried by [element] (bound `$param` points are
/// skipped: their value depends on the controls).
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
    case CircleElement(center: final center):
      add(center);
    case ArcElement(center: final center):
      add(center);
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
