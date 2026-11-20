part of "visual_validator.dart";

extension _VisualConstraintValidation on _Validator {
  /// True when [raw] is a well-formed `[x, y]` point with at least one
  /// `$param`-bound component: a component counts as bound only when it
  /// is exactly `{"$param": "<name>"}` — any other map (a typo, a stray
  /// field) is malformed, not a binding, and already errors elsewhere.
  bool _isBoundPoint(dynamic raw) {
    if (raw is! List || raw.length != 2) return false;
    return _isParamBinding(raw[0]) || _isParamBinding(raw[1]);
  }

  static bool _isParamBinding(dynamic component) =>
      component is Map<String, dynamic> &&
      component.length == 1 &&
      component[r"$param"] is String &&
      (component[r"$param"] as String).isNotEmpty;

  void _checkConstraints(dynamic raw) {
    if (raw == null) return;
    if (raw is! List) {
      _error("invalid_type", "constraints 必须是数组。", "constraints");
      return;
    }
    if (raw.length > visualMaxConstraints) {
      _error(
        "limit_exceeded",
        "约束数量超过 $visualMaxConstraints 个（共 ${raw.length} 个）。",
        "constraints",
      );
    }
    for (var i = 0; i < raw.length; i++) {
      _checkConstraint(raw[i], "constraints[$i]");
    }
  }

  void _checkConstraint(dynamic raw, String path) {
    if (!_isMap(raw)) {
      _error("invalid_type", "约束必须是对象。", path);
      return;
    }
    final constraint = raw as Map<String, dynamic>;
    final typeRaw = constraint["type"];
    if (typeRaw == null) {
      _error("missing_field", "约束缺少字段：type。", "$path.type");
      return;
    }
    final type = typeRaw is String
        ? VisualConstraintType.fromDslName(typeRaw)
        : null;
    if (type == null) {
      _error("invalid_value", "未知的约束类型：$typeRaw。", "$path.type");
      return;
    }
    // Reject unrelated fields so the snapshot cannot retain unused constraint data.
    const perTypeFields = {
      VisualConstraintType.distance: {"type", "a", "b", "value"},
      VisualConstraintType.parallel: {"type", "a", "b"},
      VisualConstraintType.perpendicular: {"type", "a", "b"},
      VisualConstraintType.intersect: {"type", "a", "b"},
      VisualConstraintType.onCircle: {"type", "point", "circle"},
      VisualConstraintType.angle: {"type", "a", "b", "value"},
      VisualConstraintType.midpoint: {"type", "point", "a", "b"},
    };
    _checkUnknownFields(constraint, perTypeFields[type]!, "约束", path);
    var shapeOk = true;
    String? idField(String key) {
      final value = constraint[key];
      if (value == null) return null;
      if (value is! String || value.isEmpty) {
        _error("invalid_type", "约束的 $key 必须是非空文字。", "$path.$key");
        // A present-but-malformed id must not reach the `a!` / `value!`
        // dereferences below: mark the shape invalid so the early return
        // after the `need(...)` checks skips evaluation.
        shapeOk = false;
        return null;
      }
      return value;
    }

    double? value;
    final rawValue = constraint["value"];
    if (rawValue != null) {
      if (rawValue is! num || !rawValue.toDouble().isFinite) {
        _error("invalid_type", "约束的 value 必须是有限数字。", "$path.value");
        shapeOk = false;
      } else {
        value = rawValue.toDouble();
      }
    }
    final a = idField("a");
    final b = idField("b");
    final point = idField("point");
    final circle = idField("circle");
    void need(String key, bool present) {
      if (!present) {
        _error("missing_field", "约束缺少字段：$key。", "$path.$key");
        shapeOk = false;
      }
    }

    switch (type) {
      case VisualConstraintType.distance:
        need("a", constraint["a"] != null);
        need("b", constraint["b"] != null);
        need("value", constraint["value"] != null);
        if (value != null && value < 0) {
          _error("invalid_range", "distance 约束的 value 不能小于 0。", "$path.value");
          shapeOk = false;
        }
      case VisualConstraintType.parallel:
      case VisualConstraintType.perpendicular:
      case VisualConstraintType.intersect:
        need("a", constraint["a"] != null);
        need("b", constraint["b"] != null);
      case VisualConstraintType.onCircle:
        need("point", constraint["point"] != null);
        need("circle", constraint["circle"] != null);
      case VisualConstraintType.angle:
        need("a", constraint["a"] != null);
        need("b", constraint["b"] != null);
        need("value", constraint["value"] != null);
        if (value != null && (value < 0 || value > 180)) {
          _error(
            "invalid_range",
            "angle 约束的 value 必须在 0~180 度之间。",
            "$path.value",
          );
          shapeOk = false;
        }
      case VisualConstraintType.midpoint:
        need("point", constraint["point"] != null);
        need("a", constraint["a"] != null);
        need("b", constraint["b"] != null);
    }
    if (!shapeOk) return;

    switch (type) {
      case VisualConstraintType.distance:
        final pa = _pointOf(a!, path);
        final pb = _pointOf(b!, path);
        if (pa == null || pb == null) return;
        final actual = _dist(pa, pb);
        // Relative tolerance: an absolute 1e-6 floor leaves small-scale
        // geometry effectively unchecked (a 1e-9 triangle passes any
        // value within 1e-6). The scale is the distance itself; when
        // the required distance is 0, fall back to the coordinate
        // magnitude so coincident points are still checkable.
        final distanceTol =
            1e-6 *
            (value! == 0
                ? math.max(_coordMagnitude(pa), _coordMagnitude(pb))
                : value.abs());
        if ((actual - value).abs() > distanceTol) {
          _violation(
            "点 $a 与 $b 的距离是 ${_Validator._fmt(actual)}，不是 ${_Validator._fmt(value)}。",
            path,
          );
        }
      case VisualConstraintType.parallel:
      case VisualConstraintType.perpendicular:
      case VisualConstraintType.angle:
      case VisualConstraintType.intersect:
        final sa = _segmentOf(a!, path);
        final sb = _segmentOf(b!, path);
        if (sa == null || sb == null) return;
        final d1 = (sa.$2.$1 - sa.$1.$1, sa.$2.$2 - sa.$1.$2);
        final d2 = (sb.$2.$1 - sb.$1.$1, sb.$2.$2 - sb.$1.$2);
        final len1 = _dist(sa.$1, sa.$2);
        final len2 = _dist(sb.$1, sb.$2);
        if (len1 == 0 || len2 == 0) {
          _error("invalid_value", "约束引用的线段退化为点，无法比较方向。", path);
          return;
        }
        final cross = d1.$1 * d2.$2 - d1.$2 * d2.$1;
        final dot = d1.$1 * d2.$1 + d1.$2 * d2.$2;
        // One shared angle tolerance for the parallel, perpendicular
        // and angle checks below, so the same geometric fact cannot get
        // two different verdicts. A direction derived from coordinates
        // rounded to ~1e-6 can be off by up to ~1e-6 / length radians,
        // so short segments get a proportionally wider tolerance; for
        // ordinary lengths the 1e-4-degree floor applies.
        //
        // The parallel/perpendicular tests compare sin/cos against
        // sin(tolerance): for the small deviations involved, |sin θ| ≤
        // sin(tol) is equivalent to the angle being within tol of 0°
        // (parallel, 180° included) and |cos θ| ≤ sin(tol) is equivalent
        // to the angle being within tol of 90° (perpendicular).
        final angleTolDeg = math.max(
          1e-4,
          1e-6 / math.min(len1, len2) * 180 / math.pi,
        );
        final angleTolSin = math.sin(angleTolDeg * math.pi / 180);
        final parallel = cross.abs() <= angleTolSin * len1 * len2;
        switch (type) {
          case VisualConstraintType.parallel:
            if (!parallel) {
              _violation("线段 $a 与 $b 不平行。", path);
            }
          case VisualConstraintType.perpendicular:
            if (dot.abs() > angleTolSin * len1 * len2) {
              _violation("线段 $a 与 $b 不垂直。", path);
            }
          case VisualConstraintType.angle:
            final cosA = (dot / (len1 * len2)).clamp(-1.0, 1.0);
            final degrees = math.acos(cosA) * 180 / math.pi;
            if ((degrees - value!).abs() > angleTolDeg) {
              _violation(
                "线段 $a 与 $b 的夹角是 ${_Validator._fmt(degrees)}°，不是 ${_Validator._fmt(value)}°。",
                path,
              );
            }
          case VisualConstraintType.intersect:
            if (!_segmentsIntersect(sa, sb)) {
              _violation("线段 $a 与 $b 不相交。", path);
            }
          case VisualConstraintType.distance:
          case VisualConstraintType.onCircle:
          case VisualConstraintType.midpoint:
            break; // Unreachable: handled by the outer switch.
        }
      case VisualConstraintType.onCircle:
        final p = _pointOf(point!, path);
        final c = _circleOf(circle!, path);
        if (p == null || c == null) return;
        final actual = _dist(p, c.$1);
        // Scale by the radius so the same relative error is detected in tiny circles.
        if ((actual - c.$2).abs() > 1e-6 * c.$2) {
          _violation(
            "点 $point 不在圆 $circle 上（到圆心距离 ${_Validator._fmt(actual)}，半径 ${_Validator._fmt(c.$2)}）。",
            path,
          );
        }
      case VisualConstraintType.midpoint:
        final p = _pointOf(point!, path);
        final pa = _pointOf(a!, path);
        final pb = _pointOf(b!, path);
        if (p == null || pa == null || pb == null) return;
        final mid = ((pa.$1 + pb.$1) / 2, (pa.$2 + pb.$2) / 2);
        // Relative to the coordinate scale of the three points, so a
        // 1e-9-scale midpoint is checked at 1e-15, not at an absolute
        // 1e-6 that would swallow the whole figure.
        final midpointTol =
            1e-6 *
            math.max(
              _coordMagnitude(p),
              math.max(_coordMagnitude(pa), _coordMagnitude(pb)),
            );
        if ((p.$1 - mid.$1).abs() > midpointTol ||
            (p.$2 - mid.$2).abs() > midpointTol) {
          _violation("点 $point 不是 $a 与 $b 的中点。", path);
        }
    }
  }

  /// A violated constraint is an error for an exact construction, and a
  /// warning when the scene declares itself a schematic.
  void _violation(String message, String path) {
    if (_schematic) {
      _warning("schematic_constraint", "示意图未按比例：$message", path);
    } else {
      _error("constraint_violated", message, path);
    }
  }

  /// Literal position of a `point` element, or null (with an issue
  /// recorded) when the id is unknown, not a point, `$param`-bound, or
  /// its geometry is missing/malformed.
  (double, double)? _pointOf(String id, String path) {
    final type = _elementTypesById[id];
    if (type == null) {
      _error("unknown_element", "约束引用了不存在的图元：$id。", path);
      return null;
    }
    if (type != "point") {
      _error("invalid_value", "约束引用了非 point 图元：$id 是 $type。", path);
      return null;
    }
    if (_boundPointIds.contains(id)) {
      _warning("constraint_unverifiable", "约束引用的点 $id 绑定了参数，无法静态检查。", path);
      return null;
    }
    final position = _pointPositions[id];
    if (position == null && _unresolvedPointIds.contains(id)) {
      _error("unresolved_geometry", "约束引用的点 $id 坐标无效，无法检查该约束。", path);
      return null;
    }
    return position;
  }

  /// Literal endpoints of a `line`/`arrow` element, or null (with an
  /// issue recorded) when the id is unknown, not a segment, bound, or
  /// its geometry is missing/malformed.
  ((double, double), (double, double))? _segmentOf(String id, String path) {
    final type = _elementTypesById[id];
    if (type == null) {
      _error("unknown_element", "约束引用了不存在的图元：$id。", path);
      return null;
    }
    if (type != "line" && type != "arrow") {
      _error("invalid_value", "约束引用了非线段图元：$id 是 $type。", path);
      return null;
    }
    if (_boundSegmentIds.contains(id)) {
      _warning("constraint_unverifiable", "约束引用的线段 $id 绑定了参数，无法静态检查。", path);
      return null;
    }
    final segment = _lineSegments[id];
    if (segment == null && _unresolvedSegmentIds.contains(id)) {
      _error("unresolved_geometry", "约束引用的线段 $id 端点无效，无法检查该约束。", path);
      return null;
    }
    return segment;
  }

  /// Literal center and radius of a `circle` element, or null (with an
  /// issue recorded) when the id is unknown, not a circle, bound, or
  /// its geometry is missing/malformed.
  ((double, double), double)? _circleOf(String id, String path) {
    final type = _elementTypesById[id];
    if (type == null) {
      _error("unknown_element", "约束引用了不存在的图元：$id。", path);
      return null;
    }
    if (type != "circle") {
      _error("invalid_value", "约束引用了非 circle 图元：$id 是 $type。", path);
      return null;
    }
    if (_boundCircleIds.contains(id)) {
      _warning("constraint_unverifiable", "约束引用的圆 $id 绑定了参数，无法静态检查。", path);
      return null;
    }
    final circle = _circles[id];
    if (circle == null && _unresolvedCircleIds.contains(id)) {
      _error("unresolved_geometry", "约束引用的圆 $id 圆心或半径无效，无法检查该约束。", path);
      return null;
    }
    return circle;
  }

  /// Distance between two points, computed hypot-style: scaling by the
  /// larger component first avoids `dx * dx` overflowing at |dx| ~ 1e200
  /// (and underflowing to 0 at |dx| ~ 1e-200). A component difference
  /// that itself overflows (coordinates near ±1.7e308) yields infinity,
  /// which is the honest double answer for such a separation.
  static double _dist((double, double) a, (double, double) b) {
    final dx = (a.$1 - b.$1).abs();
    final dy = (a.$2 - b.$2).abs();
    if (!dx.isFinite || !dy.isFinite) return double.infinity;
    final m = math.max(dx, dy);
    if (m == 0) return 0;
    final x = dx / m;
    final y = dy / m;
    return m * math.sqrt(x * x + y * y);
  }

  /// Coordinate magnitude of a point (largest |component|), the scale
  /// relative tolerances fall back to when the compared value is 0.
  static double _coordMagnitude((double, double) p) =>
      math.max(p.$1.abs(), p.$2.abs());
}
