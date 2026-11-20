part of "visual_validator.dart";

extension _VisualSceneValidation on _Validator {
  void _checkModel(dynamic raw) {
    if (raw == null) return;
    if (!_isMap(raw)) {
      _error("invalid_type", "model 必须是对象。", "model");
      return;
    }
    final model = raw as Map<String, dynamic>;
    _checkUnknownFields(
      model,
      const {"expression", "parameters", "showAxes"},
      "model",
      "model",
    );
    if (model["parameters"] != null) {
      final params = model["parameters"];
      if (!_isMap(params)) {
        _error("invalid_type", "model 的 parameters 必须是对象。", "model.parameters");
      } else {
        for (final entry in (params as Map<String, dynamic>).entries) {
          final value = entry.value;
          if (value is! num || !value.toDouble().isFinite) {
            _error(
              "invalid_type",
              "参数 ${entry.key} 必须是有限数字。",
              "model.parameters.${entry.key}",
            );
            continue;
          }
          _parameters.add(entry.key);
          _parameterValues[entry.key] = value.toDouble();
        }
      }
    }
    if (model["showAxes"] != null && model["showAxes"] is! bool) {
      _error("invalid_type", "model 的 showAxes 必须是布尔值。", "model.showAxes");
    }
    final expression = model["expression"];
    if (expression != null) {
      if (expression is! String) {
        _error("invalid_type", "model 的 expression 必须是文字。", "model.expression");
      } else if (expression.trim().isEmpty) {
        _error("invalid_value", "model 的 expression 不能为空。", "model.expression");
      } else {
        _modelExpression = _checkExpression(expression, "model.expression")
            ? expression
            : null;
      }
    }
  }

  void _checkView(dynamic raw) {
    if (raw == null) return;
    if (!_isMap(raw)) {
      _error("invalid_type", "view 必须是对象。", "view");
      return;
    }
    final view = raw as Map<String, dynamic>;
    _checkUnknownFields(view, const {"x", "y"}, "view", "view");
    if (view["x"] != null) _checkRange(view["x"], "view.x", "view.x");
    if (view["y"] != null) _checkRange(view["y"], "view.y", "view.y");
  }

  void _checkAnnotations(dynamic raw) {
    if (raw == null) return;
    if (raw is! List) {
      _error("invalid_type", "annotations 必须是数组。", "annotations");
      return;
    }
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      final path = "annotations[$i]";
      if (!_isMap(item)) {
        _error("invalid_type", "标注必须是对象。", path);
        continue;
      }
      final annotation = item as Map<String, dynamic>;
      _checkUnknownFields(annotation, const {"at", "text"}, "标注", path);
      if (annotation["at"] == null) {
        _error("missing_field", "标注缺少字段：at。", "$path.at");
      } else {
        final at = _checkPoint(annotation["at"], "$path.at");
        if (at != null) _literalBounds.add((at.$1, at.$2, at.$1, at.$2));
      }
      final text = annotation["text"];
      if (text == null) {
        _error("missing_field", "标注缺少字段：text。", "$path.text");
      } else if (text is! String) {
        _error("invalid_type", "标注的 text 必须是文字。", "$path.text");
      } else if (text.isEmpty) {
        _error("invalid_value", "标注的 text 不能为空。", "$path.text");
      }
    }
  }

  void _checkMeta(dynamic raw) {
    if (raw == null) return;
    if (!_isMap(raw)) {
      _error("invalid_type", "meta 必须是对象。", "meta");
      return;
    }
    final meta = raw as Map<String, dynamic>;
    _checkUnknownFields(meta, const {"alt", "schematic"}, "meta", "meta");
    if (meta["alt"] != null && meta["alt"] is! String) {
      _error("invalid_type", "meta 的 alt 必须是文字。", "meta.alt");
    }
    if (meta["schematic"] != null && meta["schematic"] is! bool) {
      _error("invalid_type", "meta 的 schematic 必须是布尔值。", "meta.schematic");
    }
  }
}
