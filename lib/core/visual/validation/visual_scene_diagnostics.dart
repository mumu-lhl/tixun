part of "visual_validator.dart";

extension _VisualSceneDiagnostics on _Validator {
  void _checkWarnings(Map<String, dynamic> json) {
    final title = json["title"];
    final meta = json["meta"];
    final alt = _isMap(meta) ? (meta as Map<String, dynamic>)["alt"] : null;
    final hasTitle = title is String && title.trim().isNotEmpty;
    final hasAlt = alt is String && alt.trim().isNotEmpty;
    if (!hasTitle && !hasAlt) {
      _warning("missing_accessibility_text", "场景没有标题也没有替代说明（meta.alt）。");
    }

    if (_isMap(meta) && (meta as Map<String, dynamic>)["schematic"] == true) {
      _warning(
        "schematic_content",
        "场景声明为示意图（meta.schematic），内容不按严格比例验证。",
        "meta.schematic",
      );
    }

    final view = json["view"];
    if (_isMap(view) && (_literalBounds.isNotEmpty || _plotCurves.isNotEmpty)) {
      final viewMap = view as Map<String, dynamic>;
      final viewX = _readRange(viewMap["x"]);
      final viewY = _readRange(viewMap["y"]);
      // Content spans: literal bounds cover both axes; plot domains
      // contribute their x-range (a curve's y-range needs sampling,
      // which the finite-sample probe below handles separately).
      double? contentMinX;
      double? contentMaxX;
      double? contentMinY;
      double? contentMaxY;
      for (final b in _literalBounds) {
        contentMinX = contentMinX == null ? b.$1 : math.min(contentMinX, b.$1);
        contentMaxX = contentMaxX == null ? b.$3 : math.max(contentMaxX, b.$3);
        contentMinY = contentMinY == null ? b.$2 : math.min(contentMinY, b.$2);
        contentMaxY = contentMaxY == null ? b.$4 : math.max(contentMaxY, b.$4);
      }
      for (final curve in _plotCurves) {
        final domain = curve.domain;
        if (domain == null) continue;
        contentMinX = contentMinX == null
            ? domain.$1
            : math.min(contentMinX, domain.$1);
        contentMaxX = contentMaxX == null
            ? domain.$2
            : math.max(contentMaxX, domain.$2);
      }
      // A view range more than 5x the content span on either axis usually
      // means the author picked a range far larger than the drawing.
      // A zero-span axis (a single point) still warns: its effective
      // span is 1e-6 of its coordinate magnitude, so any macroscopic
      // view around it counts as much larger.
      const factor = 5.0;
      if (viewX != null && contentMinX != null && contentMaxX != null) {
        final span = _effectiveSpan(contentMinX, contentMaxX);
        if (viewX.$2 - viewX.$1 > span * factor) {
          _warning(
            "view_much_larger_than_content",
            "view.x 的范围远大于图形内容。",
            "view.x",
          );
        }
      }
      if (viewY != null && contentMinY != null && contentMaxY != null) {
        final span = _effectiveSpan(contentMinY, contentMaxY);
        if (viewY.$2 - viewY.$1 > span * factor) {
          _warning(
            "view_much_larger_than_content",
            "view.y 的范围远大于图形内容。",
            "view.y",
          );
        }
      }
      // Elements outside the view: each axis is checked independently
      // (a view may declare only x or only y), and a bound counts when
      // it is entirely outside OR straddles an edge — judging only
      // whole-bounding-box disjointness misses content the view clips.
      if (viewX != null || viewY != null) {
        bool outsideX((double, double) span) =>
            viewX != null && (span.$2 < viewX.$1 || span.$1 > viewX.$2);
        bool straddlesX((double, double) span) =>
            viewX != null &&
            ((span.$1 < viewX.$1 && span.$2 >= viewX.$1) ||
                (span.$1 <= viewX.$2 && span.$2 > viewX.$2));
        bool outsideY((double, double) span) =>
            viewY != null && (span.$2 < viewY.$1 || span.$1 > viewY.$2);
        bool straddlesY((double, double) span) =>
            viewY != null &&
            ((span.$1 < viewY.$1 && span.$2 >= viewY.$1) ||
                (span.$1 <= viewY.$2 && span.$2 > viewY.$2));
        var outside = false;
        for (final b in _literalBounds) {
          if (outsideX((b.$1, b.$3)) ||
              straddlesX((b.$1, b.$3)) ||
              outsideY((b.$2, b.$4)) ||
              straddlesY((b.$2, b.$4))) {
            outside = true;
            break;
          }
        }
        if (!outside) {
          for (final curve in _plotCurves) {
            final domain = curve.domain;
            if (domain == null) continue;
            if (outsideX(domain) || straddlesX(domain)) {
              outside = true;
              break;
            }
          }
        }
        if (outside) {
          _warning("element_outside_view", "有图元全部或部分位于 view 范围之外。");
        }
      }
    }

    // Curves with fewer than 2 finite samples in view (contract
    // warnings list): the curve parses and validates, but draws nothing
    // (or a single dot) inside the view. With no view at all the whole
    // domain counts as in view (auto-fit shows everything).
    final viewMap = _isMap(view) ? view as Map<String, dynamic> : null;
    final viewX = viewMap == null ? null : _readRange(viewMap["x"]);
    final viewY = viewMap == null ? null : _readRange(viewMap["y"]);
    for (final curve in _plotCurves) {
      if (_countFiniteInViewSamples(
            curve.expression,
            curve.domain,
            curve.samples,
            viewX,
            viewY,
          ) <
          2) {
        _warning(
          "curve_few_finite_samples",
          "曲线在视图内的有限采样少于 2 个，图像可能不可见。",
          curve.path,
        );
      }
    }
    final modelExpression = _modelExpression;
    if (modelExpression != null &&
        _countFiniteInViewSamples(
              modelExpression,
              null,
              visualDefaultPlotSamples,
              viewX,
              viewY,
            ) <
            2) {
      _warning(
        "curve_few_finite_samples",
        "曲线在视图内的有限采样少于 2 个，图像可能不可见。",
        "model.expression",
      );
    }
  }

  /// Effective span of a content axis for the much-larger check: the
  /// real span when positive, else a floor of 1e-6 of the coordinate
  /// magnitude, so single-point content still warns on a macroscopic
  /// view instead of dividing by zero.
  static double _effectiveSpan(double min, double max) {
    final span = max - min;
    if (span > 0) return span;
    return 1e-6 * math.max(1, math.max(min.abs(), max.abs()));
  }

  /// Counts finite samples of [expression] that fall inside the view:
  /// sampled over the plot [domain] (the renderer samples the domain,
  /// defaulting to (-10, 10)), keeping only samples whose x lies in
  /// [viewX] (when present) and whose y lies in [viewY] (when present).
  /// Returns early once 2 are found. Only the expression evaluator is
  /// used — no segment math, so this stays a bounded probe, not full
  /// curve sampling.
  int _countFiniteInViewSamples(
    String expression,
    (double, double)? domain,
    int samples,
    (double, double)? viewX,
    (double, double)? viewY,
  ) {
    final min = domain?.$1 ?? -10.0;
    final max = domain?.$2 ?? 10.0;
    if (min >= max) return 0;
    Expression expr;
    try {
      expr = Expression.parse(expression);
    } on FormatException {
      return 0;
    }
    final count = math.min(math.max(samples, 2), visualMaxPlotSamples);
    var finite = 0;
    for (var i = 0; i < count; i++) {
      final x = min + (max - min) * i / (count - 1);
      if (viewX != null && (x < viewX.$1 || x > viewX.$2)) continue;
      double y;
      try {
        y = expr.evaluate({..._parameterValues, "x": x});
      } on FormatException {
        continue; // Non-finite (or unevaluatable) at this x.
      }
      if (!y.isFinite) continue;
      if (viewY != null && (y < viewY.$1 || y > viewY.$2)) continue;
      finite++;
      if (finite >= 2) return finite;
    }
    return finite;
  }

  /// Reads a validated `[min, max]` range without reporting issues
  /// (validation already happened in [_checkView]).
  (double, double)? _readRange(dynamic raw) {
    if (raw is! List || raw.length != 2) return null;
    final min = raw[0];
    final max = raw[1];
    if (min is! num || max is! num) return null;
    final a = min.toDouble();
    final b = max.toDouble();
    if (!a.isFinite || !b.isFinite || a >= b) return null;
    return (a, b);
  }
}
