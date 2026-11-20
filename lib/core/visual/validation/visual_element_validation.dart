part of "visual_validator.dart";

extension _VisualElementValidation on _Validator {
  void _checkElements(dynamic raw) {
    if (raw == null) return;
    if (raw is! List) {
      _error("invalid_type", "elements 必须是数组。", "elements");
      _elementsMalformed = true;
      return;
    }
    var count = 0;
    void countAll(dynamic element) {
      if (element is Map<String, dynamic>) {
        count++;
        final children = element["children"];
        if (children is List) {
          for (final child in children) {
            countAll(child);
          }
        }
      }
    }

    for (final element in raw) {
      countAll(element);
    }
    if (count > visualMaxElements) {
      _error(
        "limit_exceeded",
        "图元数量超过 $visualMaxElements 个（共 $count 个）。",
        "elements",
      );
    }
    for (var i = 0; i < raw.length; i++) {
      _checkElement(raw[i], "elements[$i]", 0);
    }
  }

  void _checkElement(dynamic raw, String path, int groupDepth) {
    if (!_isMap(raw)) {
      _error("invalid_type", "图元必须是对象。", path);
      return;
    }
    final element = raw as Map<String, dynamic>;
    final type = element["type"];
    const common = {"id", "type", "style", "layer", "visible", "visibleWhen"};
    const perType = {
      "point": {"at", "label", "draggable"},
      "line": {"p1", "p2", "dashed"},
      "polyline": {"points"},
      "polygon": {"points", "fill"},
      "circle": {"center", "r"},
      "arc": {"center", "r", "startDeg", "sweepDeg"},
      "arrow": {"from", "to"},
      "text": {"at", "text"},
      "math_label": {"at", "tex"},
      "group": {"children"},
      "plot": {"expression", "domain", "samples"},
      "circuit": {"component", "from", "to", "at", "closed", "meter", "label"},
    };
    if (type is! String) {
      _error("missing_field", "图元缺少字段：type。", "$path.type");
      _checkUnknownFields(element, common, "图元", path);
      return;
    }
    if (!_elementTypes.contains(type)) {
      _error("unknown_element_type", "未知的图元类型：$type。", "$path.type");
      _checkUnknownFields(element, common, "图元", path);
      return;
    }
    if (type == "circuit") _hasCircuitElement = true;
    _checkUnknownFields(
      element,
      {...common, ...perType[type]!},
      "$type 图元",
      path,
    );

    final id = element["id"];
    if (id == null) {
      _error("missing_field", "图元缺少字段：id。", "$path.id");
    } else if (id is! String || id.isEmpty) {
      _error("invalid_type", "图元的 id 必须是非空文字。", "$path.id");
    } else if (!_elementIds.add(id)) {
      _error("duplicate_id", "图元 id 重复：$id。", "$path.id");
    }
    // First duplicate wins for constraint resolution: a duplicated id
    // already errors, but resolving to the first element keeps the
    // reported geometry stable instead of silently switching to the last.
    if (id is String && id.isNotEmpty) {
      _elementTypesById.putIfAbsent(id, () => type);
    }

    if (element["style"] != null) {
      final style = element["style"];
      if (style is! String || !_styles.contains(style)) {
        _error("invalid_value", "图元的 style 无效：$style。", "$path.style");
      }
    }
    if (element["layer"] != null && element["layer"] is! int) {
      _error("invalid_type", "图元的 layer 必须是整数。", "$path.layer");
    }
    if (element["visible"] != null && element["visible"] is! bool) {
      _error("invalid_type", "图元的 visible 必须是布尔值。", "$path.visible");
    }
    if (element["visibleWhen"] != null) {
      final gate = element["visibleWhen"];
      if (!_isMap(gate)) {
        _error("invalid_type", "图元的 visibleWhen 必须是对象。", "$path.visibleWhen");
      } else {
        final gateMap = gate as Map<String, dynamic>;
        _checkUnknownFields(
          gateMap,
          const {"control", "equals"},
          "visibleWhen",
          "$path.visibleWhen",
        );
        final control = gateMap["control"];
        if (control == null) {
          _error(
            "missing_field",
            "visibleWhen 缺少字段：control。",
            "$path.visibleWhen.control",
          );
        } else if (control is! String || control.isEmpty) {
          _error(
            "invalid_type",
            "visibleWhen 的 control 必须是非空文字。",
            "$path.visibleWhen.control",
          );
        } else {
          _visibleWhenRefs.add((
            control: control,
            path: "$path.visibleWhen.control",
          ));
        }
        if (gateMap["equals"] == null) {
          _error(
            "missing_field",
            "visibleWhen 缺少字段：equals。",
            "$path.visibleWhen.equals",
          );
        } else if (gateMap["equals"] is! bool) {
          _error(
            "invalid_type",
            "visibleWhen 的 equals 必须是布尔值。",
            "$path.visibleWhen.equals",
          );
        }
      }
    }

    switch (type) {
      case "point":
        final at = _checkPoint(element["at"], "$path.at");
        if (at != null) {
          _literalBounds.add((at.$1, at.$2, at.$1, at.$2));
          if (id is String) _pointPositions.putIfAbsent(id, () => at);
        } else if (id is String && _isBoundPoint(element["at"])) {
          _boundPointIds.add(id);
        } else if (element["at"] == null) {
          _error("missing_field", "point 图元缺少字段：at。", "$path.at");
        }
        if (at == null && id is String && !_boundPointIds.contains(id)) {
          // Literal geometry missing or malformed (and not bound): the
          // element error above covers the shape; record the id so a
          // constraint referencing it can say it is unresolvable
          // instead of silently skipping.
          _unresolvedPointIds.add(id);
        }
        if (element["label"] != null && element["label"] is! String) {
          _error("invalid_type", "point 图元的 label 必须是文字。", "$path.label");
        }
        if (element["draggable"] != null && element["draggable"] is! bool) {
          _error(
            "invalid_type",
            "point 图元的 draggable 必须是布尔值。",
            "$path.draggable",
          );
        } else if (element["draggable"] == true) {
          // A dragged point is positioned by the user's finger, so its
          // coordinates must be literals; a `$param`-bound point has no
          // fixed position to drag from.
          if (_isBoundPoint(element["at"])) {
            _error(
              "invalid_value",
              "draggable 的 point 图元的 at 必须是字面坐标，不能绑定参数。",
              "$path.draggable",
            );
          }
        }
      case "line":
        final linePoints = _checkLinePoints(element, path);
        if (linePoints.length == 2 && id is String) {
          _lineSegments.putIfAbsent(id, () => (linePoints[0], linePoints[1]));
        } else if (id is String &&
            (_isBoundPoint(element["p1"]) || _isBoundPoint(element["p2"]))) {
          _boundSegmentIds.add(id);
        } else if (id is String) {
          _unresolvedSegmentIds.add(id);
        }
        if (element["dashed"] != null && element["dashed"] is! bool) {
          _error("invalid_type", "line 图元的 dashed 必须是布尔值。", "$path.dashed");
        }
      case "polyline":
        final points = _checkPointList(
          element["points"],
          "$path.points",
          2,
          "polyline",
        );
        _addBounds(points);
      case "polygon":
        final points = _checkPointList(
          element["points"],
          "$path.points",
          3,
          "polygon",
        );
        _addBounds(points);
        if (element["fill"] != null && element["fill"] is! bool) {
          _error("invalid_type", "polygon 图元的 fill 必须是布尔值。", "$path.fill");
        }
      case "circle":
        final center = _checkPoint(element["center"], "$path.center");
        final r = _finiteNumber(element["r"], "$path.r", "circle 的 r");
        if (element["center"] == null) {
          _error("missing_field", "circle 图元缺少字段：center。", "$path.center");
        }
        if (element["r"] == null) {
          _error("missing_field", "circle 图元缺少字段：r。", "$path.r");
        } else if (r != null && r <= 0) {
          _error("invalid_range", "circle 的 r 必须大于 0。", "$path.r");
        }
        if (center != null && r != null && r > 0) {
          _literalBounds.add((
            center.$1 - r,
            center.$2 - r,
            center.$1 + r,
            center.$2 + r,
          ));
          if (id is String) _circles.putIfAbsent(id, () => (center, r));
        } else if (id is String && _isBoundPoint(element["center"])) {
          _boundCircleIds.add(id);
        } else if (id is String) {
          _unresolvedCircleIds.add(id);
        }
      case "arc":
        final center = _checkPoint(element["center"], "$path.center");
        final r = _finiteNumber(element["r"], "$path.r", "arc 的 r");
        // startDeg only needs the finiteness check; any angle is valid.
        _finiteNumber(element["startDeg"], "$path.startDeg", "arc 的 startDeg");
        final sweepDeg = _finiteNumber(
          element["sweepDeg"],
          "$path.sweepDeg",
          "arc 的 sweepDeg",
        );
        if (element["center"] == null) {
          _error("missing_field", "arc 图元缺少字段：center。", "$path.center");
        }
        if (element["r"] == null) {
          _error("missing_field", "arc 图元缺少字段：r。", "$path.r");
        } else if (r != null && r <= 0) {
          _error("invalid_range", "arc 的 r 必须大于 0。", "$path.r");
        }
        if (element["startDeg"] == null) {
          _error("missing_field", "arc 图元缺少字段：startDeg。", "$path.startDeg");
        }
        if (element["sweepDeg"] == null) {
          _error("missing_field", "arc 图元缺少字段：sweepDeg。", "$path.sweepDeg");
        } else if (sweepDeg != null && sweepDeg == 0) {
          _error("invalid_range", "arc 的 sweepDeg 不能为 0。", "$path.sweepDeg");
        }
        if (center != null && r != null && r > 0) {
          _literalBounds.add((
            center.$1 - r,
            center.$2 - r,
            center.$1 + r,
            center.$2 + r,
          ));
        }
      case "arrow":
        final arrowPoints = _checkLinePoints(element, path);
        if (arrowPoints.length == 2 && id is String) {
          _lineSegments.putIfAbsent(id, () => (arrowPoints[0], arrowPoints[1]));
        } else if (id is String &&
            (_isBoundPoint(element["from"]) || _isBoundPoint(element["to"]))) {
          _boundSegmentIds.add(id);
        } else if (id is String) {
          _unresolvedSegmentIds.add(id);
        }
      case "text":
        _checkLabeledPoint(element, path, "text", "text");
      case "math_label":
        _checkLabeledPoint(element, path, "math_label", "tex");
      case "group":
        if (groupDepth >= visualMaxGroupDepth) {
          _error(
            "invalid_value",
            "group 嵌套过深（最多 $visualMaxGroupDepth 层）。",
            path,
          );
          return;
        }
        final children = element["children"];
        if (children == null) {
          _error("missing_field", "group 图元缺少字段：children。", "$path.children");
        } else if (children is! List) {
          _error("invalid_type", "group 图元的 children 必须是数组。", "$path.children");
        } else {
          if (children.isEmpty) {
            _error("invalid_value", "group 图元至少需要一个子图元。", "$path.children");
          }
          for (var i = 0; i < children.length; i++) {
            _checkElement(children[i], "$path.children[$i]", groupDepth + 1);
          }
        }
      case "plot":
        final expression = element["expression"];
        var expressionOk = false;
        if (expression == null) {
          _error(
            "missing_field",
            "plot 图元缺少字段：expression。",
            "$path.expression",
          );
        } else if (expression is! String) {
          _error(
            "invalid_type",
            "plot 图元的 expression 必须是文字。",
            "$path.expression",
          );
        } else if (expression.trim().isEmpty) {
          _error(
            "invalid_value",
            "plot 图元的 expression 不能为空。",
            "$path.expression",
          );
        } else {
          expressionOk = _checkExpression(expression, "$path.expression");
        }
        if (element["domain"] != null) {
          // Domain validity is checked; its x-range is not used for the
          // view-vs-content warnings (the curve's y-range needs sampling,
          // which this validator deliberately does not do).
          _checkRange(element["domain"], "$path.domain", "plot 的 domain");
        }
        // The samples cap applies to the effective count, not just an
        // explicit value: a missing `samples` still renders at the
        // default, so the check runs on the resolved value either way.
        var effectiveSamples = visualDefaultPlotSamples;
        final rawSamples = element["samples"];
        if (rawSamples != null) {
          if (rawSamples is! int) {
            _error("invalid_type", "plot 图元的 samples 必须是整数。", "$path.samples");
          } else {
            effectiveSamples = rawSamples;
          }
        }
        if (effectiveSamples <= 0 || effectiveSamples > visualMaxPlotSamples) {
          _error(
            "invalid_range",
            "plot 图元的 samples 必须在 1~$visualMaxPlotSamples 之间。",
            "$path.samples",
          );
        }
        if (expressionOk) {
          _plotCurves.add((
            expression: expression as String,
            domain: _readRange(element["domain"]),
            samples: effectiveSamples,
            path: path,
          ));
        }
      case "circuit":
        const components = {"battery", "resistor", "switch", "wire", "meter"};
        final component = element["component"];
        if (component == null) {
          _error(
            "missing_field",
            "circuit 图元缺少字段：component。",
            "$path.component",
          );
        } else if (component is! String || !components.contains(component)) {
          _error(
            "invalid_value",
            "circuit 图元的 component 必须是 battery/resistor/switch/wire/meter 之一。",
            "$path.component",
          );
        } else if (component == "meter") {
          final at = _checkPoint(element["at"], "$path.at");
          if (at != null) {
            _literalBounds.add((at.$1, at.$2, at.$1, at.$2));
          } else if (element["at"] == null) {
            _error("missing_field", "meter 图元缺少字段：at。", "$path.at");
          }
          final meter = element["meter"];
          if (meter == null) {
            _error("missing_field", "meter 图元缺少字段：meter。", "$path.meter");
          } else if (meter is! String ||
              (meter != "ammeter" && meter != "voltmeter")) {
            _error(
              "invalid_value",
              "meter 图元的 meter 必须是 ammeter 或 voltmeter。",
              "$path.meter",
            );
          }
          if (element["from"] != null || element["to"] != null) {
            _error("invalid_value", "meter 图元不需要 from/to 字段。", "$path.from");
          }
        } else {
          _checkLinePoints(element, path);
          if (element["at"] != null) {
            _error("invalid_value", "circuit 图元不需要 at 字段。", "$path.at");
          }
          if (element["meter"] != null) {
            _error("invalid_value", "只有 meter 图元能带 meter 字段。", "$path.meter");
          }
        }
        if (element["closed"] != null && element["closed"] is! bool) {
          _error("invalid_type", "circuit 图元的 closed 必须是布尔值。", "$path.closed");
        } else if (element["closed"] == true && component != "switch") {
          _error("invalid_value", "只有 switch 图元能带 closed 字段。", "$path.closed");
        }
        if (element["label"] != null && element["label"] is! String) {
          _error("invalid_type", "circuit 图元的 label 必须是文字。", "$path.label");
        }
    }
  }

  /// Validates a pair of points (`line`: p1/p2, `arrow`: from/to) and
  /// records their bounds. Returns the literal endpoints found (empty
  /// when either is missing or `$param`-bound).
  List<(double, double)> _checkLinePoints(
    Map<String, dynamic> element,
    String path,
  ) {
    final type = element["type"] as String;
    final firstKey = type == "line" ? "p1" : "from";
    final secondKey = type == "line" ? "p2" : "to";
    final points = <(double, double)>[];
    for (final key in [firstKey, secondKey]) {
      if (element[key] == null) {
        _error("missing_field", "$type 图元缺少字段：$key。", "$path.$key");
        continue;
      }
      final point = _checkPoint(element[key], "$path.$key");
      if (point != null) points.add(point);
    }
    _addBounds(points);
    return points;
  }

  void _checkLabeledPoint(
    Map<String, dynamic> element,
    String path,
    String type,
    String textKey,
  ) {
    final at = _checkPoint(element["at"], "$path.at");
    if (at != null) {
      _literalBounds.add((at.$1, at.$2, at.$1, at.$2));
    } else if (element["at"] == null) {
      _error("missing_field", "$type 图元缺少字段：at。", "$path.at");
    }
    final text = element[textKey];
    if (text == null) {
      _error("missing_field", "$type 图元缺少字段：$textKey。", "$path.$textKey");
    } else if (text is! String) {
      _error("invalid_type", "$type 图元的 $textKey 必须是文字。", "$path.$textKey");
    } else if (text.isEmpty) {
      _error("invalid_value", "$type 图元的 $textKey 不能为空。", "$path.$textKey");
    } else if (text.length > 500) {
      _error(
        "invalid_value",
        "$type 图元的 $textKey 不能超过 500 个字符。",
        "$path.$textKey",
      );
    }
  }

  /// Validates a list of points with a minimum length; returns the literal
  /// points found (empty when the list itself is invalid).
  List<(double, double)> _checkPointList(
    dynamic raw,
    String path,
    int minLength,
    String type,
  ) {
    if (raw == null) {
      _error("missing_field", "$type 图元缺少字段：points。", path);
      return const [];
    }
    if (raw is! List) {
      _error("invalid_type", "$type 图元的 points 必须是数组。", path);
      return const [];
    }
    if (raw.length < minLength) {
      _error("invalid_value", "$type 图元至少需要 $minLength 个点。", path);
    }
    final points = <(double, double)>[];
    for (var i = 0; i < raw.length; i++) {
      final point = _checkPoint(raw[i], "$path[$i]");
      if (point != null) points.add(point);
    }
    return points;
  }
}
