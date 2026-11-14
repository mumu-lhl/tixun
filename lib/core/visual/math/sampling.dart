/// Sampling + derived values for TiXun Visual DSL v1 (math slice).
///
/// Pure Dart: no widgets/material imports. `dart:ui` is used only for
/// [Offset] as a model-coordinate point pair, which `flutter test` handles.
/// Nothing here executes generated code: every expression goes through
/// [Expression], which builds an AST and evaluates it.
///
/// Discontinuity handling in [sampleFunction]: a segment breaks when a
/// sample is non-finite (evaluation throws), when |Δy| exceeds half the
/// sampled y-span, or when the local slope jumps by more than 50x the
/// median slope of the recent edges in the current segment. The goal is
/// never to draw a line across an asymptote (e.g. tan). Extra splits are
/// harmless for rendering: they only omit one sample-step of line between
/// two adjacent segments.
///
/// The slope rule compares against the *current* segment's recent median
/// slope (windowed, see [_slopeWindow]), not the previous completed
/// segment: a branch right after an asymptote starts with a huge slope,
/// so comparing against the previous segment would split off a spurious
/// one-point segment at every branch start.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:tixun/core/visual/model/visual_scene.dart';

import 'expression.dart';

/// Hard cap on samples per curve (DSL resource limit).
const maxSamplesHardCap = 4096;

/// Fine sweep resolution used by [findZeros] and [findIntersections].
const _zeroSweepIntervals = 2048;

/// Sweep resolution used by [findExtrema].
const _extremaSweepIntervals = 2048;

/// Bisection tolerance in x.
const _rootTolerance = 1e-9;

/// Roots/extrema closer than this are considered the same point.
const _dedupeTolerance = 1e-6;

/// How many recent edge slopes the slope-jump rule looks at. Windowed so
/// the median stays cheap and so the rule tracks gradual slope growth
/// (e.g. exp) instead of splitting it.
const _slopeWindow = 64;

/// One continuous polyline in model coordinates.
class SampledSegment {
  const SampledSegment(this.points);

  final List<Offset> points;
}

/// Evaluates [expr] at [x] with [variables] plus `x`.
///
/// Returns null when evaluation fails (unknown variable, non-finite
/// intermediate or final result). Callers treat null as a discontinuity.
double? _tryEvaluate(Expression expr, Map<String, double> variables, double x) {
  final vars = Map<String, double>.of(variables)..['x'] = x;
  try {
    return expr.evaluate(vars);
  } on FormatException {
    return null;
  }
}

double _median(List<double> values) {
  final sorted = List<double>.of(values)..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Uniformly samples [expression] over `[min, max]` into segments split at
/// discontinuities (see the library doc comment).
///
/// [variables] holds parameters and `t`; `x` is the sweep variable and any
/// caller-supplied `x` entry is overwritten per sample. [maxSamples] is
/// the number of uniform samples (default 1024, hard cap
/// [maxSamplesHardCap]).
///
/// Throws [ArgumentError] when `min >= max`, when [maxSamples] is below 2,
/// or when it exceeds [maxSamplesHardCap]. Throws [FormatException] when
/// [expression] fails to parse.
List<SampledSegment> sampleFunction(
  String expression, {
  required Map<String, double> variables,
  required double min,
  required double max,
  int maxSamples = 1024,
}) {
  if (min >= max) {
    throw ArgumentError('Sampling range must satisfy min < max.');
  }
  if (maxSamples < 2) {
    throw ArgumentError('maxSamples must be at least 2.');
  }
  if (maxSamples > maxSamplesHardCap) {
    throw ArgumentError('maxSamples must not exceed $maxSamplesHardCap.');
  }
  final expr = Expression.parse(expression);
  final step = (max - min) / (maxSamples - 1);
  final ys = <double?>[
    for (var i = 0; i < maxSamples; i++)
      _tryEvaluate(expr, variables, min + step * i),
  ];
  // ySpan over the finite samples; fallback 1.0 when there is nothing
  // finite or the curve is constant.
  double? yMin;
  double? yMax;
  for (final y in ys) {
    if (y == null) continue;
    yMin = yMin == null ? y : math.min(yMin, y);
    yMax = yMax == null ? y : math.max(yMax, y);
  }
  var ySpan = 1.0;
  if (yMin != null && yMax != null) {
    final span = yMax - yMin;
    if (span > 0) ySpan = span;
  }

  final segments = <SampledSegment>[];
  var current = <Offset>[];
  final recentSlopes = <double>[];
  void flush() {
    if (current.isNotEmpty) {
      segments.add(SampledSegment(current));
    }
    current = <Offset>[];
    recentSlopes.clear();
  }

  for (var i = 0; i < maxSamples; i++) {
    final y = ys[i];
    final x = min + step * i;
    if (y == null) {
      flush();
      continue;
    }
    if (current.isNotEmpty) {
      final prevY = current.last.dy;
      final dy = (y - prevY).abs();
      var breaks = dy > 0.5 * ySpan;
      if (!breaks && recentSlopes.isNotEmpty) {
        final slope = dy / step;
        final median = _median(recentSlopes);
        if (median > 0 && slope > 50 * median) {
          breaks = true;
        }
      }
      if (breaks) {
        flush();
      } else {
        recentSlopes.add(dy / step);
        if (recentSlopes.length > _slopeWindow) {
          recentSlopes.removeAt(0);
        }
      }
    }
    current.add(Offset(x, y));
  }
  flush();
  return segments;
}

bool _oppositeSigns(double a, double b) => (a < 0 && b > 0) || (a > 0 && b < 0);

/// Bisects [f] on `[a, b]` where `f(a)` and `f(b)` have opposite signs
/// (`fa` is `f(a)`).
///
/// Returns null when the bracket turns out to contain a discontinuity
/// (a midpoint evaluation fails) instead of a root.
double? _bisect(double? Function(double x) f, double a, double b, double fa) {
  var lo = a;
  var hi = b;
  var flo = fa;
  for (var i = 0; i < 100; i++) {
    if (hi - lo < _rootTolerance) break;
    final mid = (lo + hi) / 2;
    final fm = f(mid);
    if (fm == null) return null;
    if (fm == 0.0) return mid;
    if (_oppositeSigns(flo, fm)) {
      hi = mid;
    } else {
      lo = mid;
      flo = fm;
    }
  }
  return (lo + hi) / 2;
}

List<double> _dedupeSorted(List<double> sorted) {
  final out = <double>[];
  for (final value in sorted) {
    if (out.isEmpty || (value - out.last).abs() >= _dedupeTolerance) {
      out.add(value);
    }
  }
  return out;
}

/// Finds zeros of [f] over `[min, max]` by a fine sweep with bisection on
/// sign changes. Exact hits (`f == 0.0` at a sample) are recorded too;
/// tangent touches that fall between samples are not detected.
List<double> _findZerosOf(
  double? Function(double x) f,
  double min,
  double max,
) {
  final roots = <double>[];
  final n = _zeroSweepIntervals;
  final step = (max - min) / n;
  var prevX = min;
  var prevY = f(min);
  if (prevY == 0.0) {
    roots.add(prevX);
  }
  for (var i = 1; i <= n; i++) {
    final x = min + step * i;
    final y = f(x);
    if (y == 0.0) {
      roots.add(x);
    } else if (prevY != null && y != null && _oppositeSigns(prevY, y)) {
      final root = _bisect(f, prevX, x, prevY);
      if (root != null) {
        roots.add(root);
      }
    }
    prevX = x;
    prevY = y;
  }
  roots.sort();
  return _dedupeSorted(roots);
}

/// Finds the zeros of [expression] over `[min, max]` by bisection on sign
/// changes over a fine sweep (2048 subintervals), refined to a tolerance
/// of 1e-9 in x. Roots closer than 1e-6 are deduped.
///
/// Throws [ArgumentError] when `min >= max` and [FormatException] when
/// [expression] fails to parse.
List<double> findZeros(
  String expression,
  Map<String, double> variables,
  double min,
  double max,
) {
  if (min >= max) {
    throw ArgumentError('Range must satisfy min < max.');
  }
  final expr = Expression.parse(expression);
  return _findZerosOf((x) => _tryEvaluate(expr, variables, x), min, max);
}

/// Finds the intersections of `e1` and `e2` over `[min, max]` as the zeros
/// of `e1 - e2`, returned as `Offset(x, y)` with `y` evaluated from `e1`.
///
/// Throws [ArgumentError] when `min >= max` and [FormatException] when
/// either expression fails to parse.
List<Offset> findIntersections(
  String e1,
  String e2,
  Map<String, double> variables,
  double min,
  double max,
) {
  if (min >= max) {
    throw ArgumentError('Range must satisfy min < max.');
  }
  final first = Expression.parse(e1);
  final second = Expression.parse(e2);
  double? diff(double x) {
    final a = _tryEvaluate(first, variables, x);
    final b = _tryEvaluate(second, variables, x);
    if (a == null || b == null) return null;
    final d = a - b;
    return d.isFinite ? d : null;
  }

  final xs = _findZerosOf(diff, min, max);
  final points = <Offset>[];
  for (final x in xs) {
    final y = _tryEvaluate(first, variables, x);
    if (y != null) {
      points.add(Offset(x, y));
    }
  }
  return points;
}

/// Finds local extrema of [expression] over `[min, max]` via sampled
/// derivative sign changes, refined by bisection on the numerical
/// derivative (central difference, `h = 1e-6 * span`).
///
/// Returns records sorted by x with `kind` `'min'` or `'max'`.
/// Throws [ArgumentError] when `min >= max` and [FormatException] when
/// [expression] fails to parse.
List<({double x, double y, String kind})> findExtrema(
  String expression,
  Map<String, double> variables,
  double min,
  double max,
) {
  if (min >= max) {
    throw ArgumentError('Range must satisfy min < max.');
  }
  final expr = Expression.parse(expression);
  final span = max - min;
  final h = 1e-6 * span;
  double? derivative(double x) {
    final plus = _tryEvaluate(expr, variables, x + h);
    final minus = _tryEvaluate(expr, variables, x - h);
    if (plus == null || minus == null) return null;
    final d = (plus - minus) / (2 * h);
    return d.isFinite ? d : null;
  }

  final n = _extremaSweepIntervals;
  final step = span / n;
  final ds = <double?>[for (var i = 0; i <= n; i++) derivative(min + step * i)];
  final found = <({double x, double y, String kind})>[];
  void addExtremum(double x, String kind) {
    final y = _tryEvaluate(expr, variables, x);
    if (y != null) {
      found.add((x: x, y: y, kind: kind));
    }
  }

  for (var i = 0; i <= n; i++) {
    final x = min + step * i;
    final d = ds[i];
    if (d == 0.0) {
      // Exact stationary point on the grid: classify from the neighbours.
      final before = i > 0 ? ds[i - 1] : null;
      final after = i < n ? ds[i + 1] : null;
      if (before != null && after != null && _oppositeSigns(before, after)) {
        addExtremum(x, before > 0 ? 'max' : 'min');
      }
      continue;
    }
    if (i == 0) continue;
    final prevD = ds[i - 1];
    if (prevD != null && d != null && _oppositeSigns(prevD, d)) {
      final root = _bisect(derivative, x - step, x, prevD);
      if (root != null) {
        addExtremum(root, prevD > 0 ? 'max' : 'min');
      }
    }
  }
  found.sort((a, b) => a.x.compareTo(b.x));
  final deduped = <({double x, double y, String kind})>[];
  for (final e in found) {
    if (deduped.isEmpty || (e.x - deduped.last.x).abs() >= _dedupeTolerance) {
      deduped.add(e);
    }
  }
  return deduped;
}

/// The x-range derived values are computed over: the scene view's x range,
/// or `[-10, 10]` when the scene has no (valid) view range.
(double, double) _sceneRange(VisualScene scene) {
  final x = scene.view?.x;
  if (x != null && x.min < x.max) {
    return (x.min, x.max);
  }
  return (-10, 10);
}

/// All elements in the scene, including group children.
Iterable<VisualElement> _allElements(VisualScene scene) sync* {
  for (final element in scene.elements) {
    yield element;
    if (element is GroupElement) {
      yield* _flattenGroup(element);
    }
  }
}

Iterable<VisualElement> _flattenGroup(GroupElement group) sync* {
  for (final child in group.children) {
    yield child;
    if (child is GroupElement) {
      yield* _flattenGroup(child);
    }
  }
}

/// Computes derived values for [scene]: zeros and extrema of
/// `model.expression` over the scene view (or `[-10, 10]`), and for each
/// `plot` element its zeros plus its intersections with the model
/// expression (keyed by element id).
///
/// Returns plain JSON-safe values only (numbers, strings, lists, maps).
/// Never throws on weird scenes: per-expression failures are recorded
/// under `'errors'` instead of failing the whole computation.
///
/// Shape:
/// ```dart
/// {
///   'zeros': [double, ...],
///   'extrema': [{'x': .., 'y': .., 'kind': 'min'|'max'}, ...],
///   'elements': {  // only when the scene has plot elements
///     '<id>': {
///       'zeros': [double, ...],
///       'intersections': [{'x': .., 'y': ..}, ...],  // only when the
///       // scene also has a model expression
///     },
///   },
///   'errors': ['model: ...', 'element <id>: ...'],  // only on failure
/// }
/// ```
Map<String, dynamic> computeDerivedValues(VisualScene scene) {
  final result = <String, dynamic>{
    'zeros': <double>[],
    'extrema': <Map<String, dynamic>>[],
  };
  final errors = <String>[];
  final parameters = scene.model?.parameters ?? const <String, double>{};
  final modelRange = _sceneRange(scene);
  final modelExpression = scene.model?.expression;
  if (modelExpression != null) {
    try {
      result['zeros'] = findZeros(
        modelExpression,
        parameters,
        modelRange.$1,
        modelRange.$2,
      );
      final extrema = findExtrema(
        modelExpression,
        parameters,
        modelRange.$1,
        modelRange.$2,
      );
      result['extrema'] = [
        for (final e in extrema) {'x': e.x, 'y': e.y, 'kind': e.kind},
      ];
    } catch (e) {
      errors.add('model: $e');
    }
  }
  final elements = <String, dynamic>{};
  for (final element in _allElements(scene)) {
    if (element is! PlotElement) continue;
    final range = element.domain ?? _sceneRange(scene);
    try {
      final entry = <String, dynamic>{
        'zeros': findZeros(element.expression, parameters, range.$1, range.$2),
      };
      if (modelExpression != null) {
        // Intersections are best-effort: a bad model expression must not
        // drop the plot element's own zeros.
        try {
          final points = findIntersections(
            element.expression,
            modelExpression,
            parameters,
            range.$1,
            range.$2,
          );
          entry['intersections'] = [
            for (final p in points) {'x': p.dx, 'y': p.dy},
          ];
        } catch (e) {
          errors.add('element ${element.id} intersections: $e');
        }
      }
      elements[element.id] = entry;
    } catch (e) {
      errors.add('element ${element.id}: $e');
    }
  }
  if (elements.isNotEmpty) {
    result['elements'] = elements;
  }
  if (errors.isNotEmpty) {
    result['errors'] = errors;
  }
  return result;
}
