part of "visual_painter.dart";

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
    // Magnitude scale for the whole curve: the median |y| over all
    // its samples. It must be global, not per segment: the slope rule
    // splits the pole approach into its own small segments, whose
    // per-segment median is itself huge, so a per-segment threshold
    // would trim nothing exactly where trimming matters.
    final magnitudes = <double>[
      for (final segment in segments)
        for (final point in segment.points) point.dy.abs(),
    ]..sort();
    final median = magnitudes.isEmpty
        ? 0.0
        : magnitudes[magnitudes.length ~/ 2];
    for (var i = 0; i < segments.length; i++) {
      final points = segments[i].points;
      if (points.length == 1 &&
          median > 0 &&
          _isPoleSingleton(segments, i, min, max, 10 * median)) {
        // A lone sample wedged between two breaks next to a pole is
        // pole approach, not content: leave it out of auto-fit.
        continue;
      }
      out.addAll(_trimPoleTails(points, min, max, median));
    }
  } catch (_) {
    // A bad expression must not break auto-fit; the validator rejects it
    // before it reaches the renderer in normal flows.
  }
}

/// Whether the single sample of segment [index] is a pole neighbour
/// rather than an isolated peak. A lone sample strictly inside the
/// sampled range with |y| far above the curve's scale is pole
/// approach when the sample just outside it — the nearest endpoint
/// of an adjacent segment — is itself above the threshold: the
/// region on both sides is climbing the pole. A narrow peak instead
/// stands on a flat baseline, so its neighbours are small and the
/// sample is kept: it is the content, and dropping it from auto-fit
/// would clip the peak out of view.
bool _isPoleSingleton(
  List<SampledSegment> segments,
  int index,
  double min,
  double max,
  double threshold,
) {
  final point = segments[index].points.first;
  if (point.dx <= min || point.dx >= max) return false;
  if (point.dy.abs() <= threshold) return false;
  if (index > 0) {
    final prev = segments[index - 1].points.last;
    if (prev.dy.abs() > threshold) return true;
  }
  if (index + 1 < segments.length) {
    final next = segments[index + 1].points.first;
    if (next.dy.abs() > threshold) return true;
  }
  return false;
}

/// Drops the samples at the ends of a sampled segment that climb far
/// above the curve's own scale — the approach to a pole (tan, 1/x).
/// Only ends that stop strictly inside the sampled range are trimmed:
/// an end at the range edge is the curve's real extent, not a pole
/// approach (so a steep-but-continuous curve like exp is untouched).
/// A segment that is entirely pole approach is dropped altogether:
/// it is a sliver between two breaks, not the main body. Single
/// samples are kept as-is: a lone sample is as likely a narrow peak
/// (real content) as a pole neighbour.
List<ui.Offset> _trimPoleTails(
  List<ui.Offset> points,
  double min,
  double max,
  double median,
) {
  if (points.length < 2 || median <= 0) return points;
  final threshold = 10 * median;
  var start = 0;
  var end = points.length;
  while (start < end &&
      points[start].dx > min &&
      points[start].dy.abs() > threshold) {
    start++;
  }
  while (end > start &&
      points[end - 1].dx < max &&
      points[end - 1].dy.abs() > threshold) {
    end--;
  }
  return points.sublist(start, end);
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
