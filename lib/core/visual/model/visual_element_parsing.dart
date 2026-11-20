part of "visual_elements.dart";

sealed class VisualElement {
  const VisualElement({
    required this.id,
    required this.style,
    required this.layer,
    required this.visible,
    this.visibleWhen,
  });

  final String id;
  final VisualStyle style;
  final int layer;
  final bool visible;
  final VisualVisibilityGate? visibleWhen;

  /// The DSL `type` string, e.g. `point`.
  String get type;

  /// This element's id plus, for groups, every descendant id.
  List<String> get allIds => [id];

  Map<String, dynamic> toJson();

  /// Parses one element. [groupDepth] counts enclosing groups (0 at the
  /// top level); nested groups deeper than [visualMaxGroupDepth] are
  /// rejected.
  factory VisualElement.fromJson(
    Map<String, dynamic> json, {
    int groupDepth = 0,
  }) {
    final type = _reqString(json, "type", "图元");
    switch (type) {
      case "point":
        checkNoUnknownFields(json, {
          ..._commonFields,
          "at",
          "label",
          "draggable",
        }, "point 图元");
        final c = _parseCommonFields(json);
        final at = json["at"];
        if (at == null) {
          throw const AppFormatException(
            AppErrorCode.errorMissingParameter,
            "point 图元缺少字段：at。",
          );
        }
        return PointElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          at: VisualPoint.fromJson(at),
          draggable: _optBool(json, "draggable", "point 图元"),
          label: switch (json["label"]) {
            null => null,
            final String s => s,
            _ => throw const AppFormatException(
              AppErrorCode.errorParameterMustBeText,
              "point 图元的 label 必须是文字。",
            ),
          },
        );
      case "line":
        checkNoUnknownFields(json, {
          ..._commonFields,
          "p1",
          "p2",
          "dashed",
        }, "line 图元");
        final c = _parseCommonFields(json);
        return LineElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          p1: VisualPoint.fromJson(json["p1"]),
          p2: VisualPoint.fromJson(json["p2"]),
          dashed: _optBool(json, "dashed", "line 图元"),
        );
      case "polyline":
        checkNoUnknownFields(json, {..._commonFields, "points"}, "polyline 图元");
        final c = _parseCommonFields(json);
        return PolylineElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          points: _parsePoints(json["points"], "polyline", 2),
        );
      case "polygon":
        checkNoUnknownFields(json, {
          ..._commonFields,
          "points",
          "fill",
        }, "polygon 图元");
        final c = _parseCommonFields(json);
        return PolygonElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          points: _parsePoints(json["points"], "polygon", 3),
          fill: _optBool(json, "fill", "polygon 图元"),
        );
      case "circle":
        checkNoUnknownFields(json, {
          ..._commonFields,
          "center",
          "r",
        }, "circle 图元");
        final c = _parseCommonFields(json);
        final circleR = _reqNumber(json, "r", "circle 图元");
        if (circleR <= 0) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "circle 图元的 r 必须大于 0。",
            ["r"],
          );
        }
        return CircleElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          center: VisualPoint.fromJson(json["center"]),
          r: circleR,
        );
      case "arc":
        checkNoUnknownFields(json, {
          ..._commonFields,
          "center",
          "r",
          "startDeg",
          "sweepDeg",
        }, "arc 图元");
        final c = _parseCommonFields(json);
        final arcR = _reqNumber(json, "r", "arc 图元");
        if (arcR <= 0) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "arc 图元的 r 必须大于 0。",
            ["r"],
          );
        }
        final arcSweep = _reqNumber(json, "sweepDeg", "arc 图元");
        if (arcSweep == 0) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "arc 图元的 sweepDeg 不能为 0。",
            ["sweepDeg"],
          );
        }
        return ArcElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          center: VisualPoint.fromJson(json["center"]),
          r: arcR,
          startDeg: _reqNumber(json, "startDeg", "arc 图元"),
          sweepDeg: arcSweep,
        );
      case "arrow":
        checkNoUnknownFields(json, {
          ..._commonFields,
          "from",
          "to",
        }, "arrow 图元");
        final c = _parseCommonFields(json);
        return ArrowElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          from: VisualPoint.fromJson(json["from"]),
          to: VisualPoint.fromJson(json["to"]),
        );
      case "text":
        checkNoUnknownFields(json, {..._commonFields, "at", "text"}, "text 图元");
        final c = _parseCommonFields(json);
        final textValue = _reqString(json, "text", "text 图元");
        _checkTextLength(textValue, "text 图元");
        return TextElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          at: VisualPoint.fromJson(json["at"]),
          text: textValue,
        );
      case "math_label":
        checkNoUnknownFields(json, {
          ..._commonFields,
          "at",
          "tex",
        }, "math_label 图元");
        final c = _parseCommonFields(json);
        final texValue = _reqString(json, "tex", "math_label 图元");
        _checkTextLength(texValue, "math_label 图元");
        return MathLabelElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          at: VisualPoint.fromJson(json["at"]),
          tex: texValue,
        );
      case "group":
        checkNoUnknownFields(json, {..._commonFields, "children"}, "group 图元");
        if (groupDepth >= visualMaxGroupDepth) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "group 嵌套过深（最多 $visualMaxGroupDepth 层）。",
            ["children"],
          );
        }
        final c = _parseCommonFields(json);
        final rawChildren = json["children"];
        if (rawChildren is! List) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "group 图元的 children 必须是数组。",
            ["children"],
          );
        }
        if (rawChildren.isEmpty) {
          // The contract writes `children: [element, ...]` — a group
          // with no children is not a group; the validator rejects it
          // too, so the layers agree.
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "group 图元至少需要一个子图元。",
            ["children"],
          );
        }
        return GroupElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          children: rawChildren.map((child) {
            if (child is! Map<String, dynamic>) {
              throw const AppFormatException(
                AppErrorCode.errorInvalidParameterType,
                "group 的子图元必须是对象。",
                ["children"],
              );
            }
            return VisualElement.fromJson(child, groupDepth: groupDepth + 1);
          }).toList(),
        );
      case "plot":
        checkNoUnknownFields(json, {
          ..._commonFields,
          "expression",
          "domain",
          "samples",
        }, "plot 图元");
        final c = _parseCommonFields(json);
        (double, double)? domain;
        if (json["domain"] != null) {
          final raw = json["domain"];
          if (raw is! List || raw.length != 2) {
            throw const AppFormatException(
              AppErrorCode.errorInvalidParameterType,
              "plot 图元的 domain 必须是 [min, max] 形式的数组。",
              ["domain"],
            );
          }
          final min = raw[0];
          final max = raw[1];
          if (min is! num ||
              max is! num ||
              !min.toDouble().isFinite ||
              !max.toDouble().isFinite) {
            throw const AppFormatException(
              AppErrorCode.errorParameterMustBeNumber,
              "plot 图元的 domain 必须是有限数字。",
            );
          }
          domain = (min.toDouble(), max.toDouble());
          if (domain.$1 >= domain.$2) {
            throw const AppFormatException(
              AppErrorCode.errorInvalidParameterType,
              "plot 图元的 domain 下限必须小于上限。",
              ["domain"],
            );
          }
        }
        int? samples;
        if (json["samples"] != null) {
          final raw = json["samples"];
          if (raw is! int) {
            throw const AppFormatException(
              AppErrorCode.errorParameterMustBeNumber,
              "plot 图元的 samples 必须是整数。",
            );
          }
          // Mirrors visualMaxPlotSamples in visual_validator.dart (the
          // model layer cannot import the validator: it imports this
          // file, so a cycle would result).
          if (raw <= 0 || raw > 4096) {
            throw const AppFormatException(
              AppErrorCode.errorInvalidParameterType,
              "plot 图元的 samples 必须在 1~4096 之间。",
              ["samples"],
            );
          }
          samples = raw;
        }
        return PlotElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          expression: _reqString(json, "expression", "plot 图元"),
          domain: domain,
          samples: samples,
        );
      case "circuit":
        checkNoUnknownFields(json, {
          ..._commonFields,
          "component",
          "from",
          "to",
          "at",
          "closed",
          "meter",
          "label",
        }, "circuit 图元");
        final c = _parseCommonFields(json);
        final componentRaw = json["component"];
        if (componentRaw == null) {
          throw const AppFormatException(
            AppErrorCode.errorMissingParameter,
            "circuit 图元缺少字段：component。",
          );
        }
        final component = CircuitComponent.values.where(
          (v) => v.dslName == componentRaw,
        );
        if (component.isEmpty) {
          throw AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "circuit 图元的 component 未知：$componentRaw。",
            [componentRaw.toString()],
          );
        }
        final comp = component.first;
        VisualPoint? from;
        VisualPoint? to;
        VisualPoint? at;
        CircuitMeterKind? meter;
        if (comp == CircuitComponent.meter) {
          at = VisualPoint.fromJson(json["at"]);
          final meterRaw = json["meter"];
          if (meterRaw == null) {
            throw const AppFormatException(
              AppErrorCode.errorMissingParameter,
              "meter 图元缺少字段：meter。",
            );
          }
          final kinds = CircuitMeterKind.values.where(
            (v) => v.name == meterRaw,
          );
          if (kinds.isEmpty) {
            throw AppFormatException(
              AppErrorCode.errorInvalidParameterType,
              "meter 图元的 meter 未知：$meterRaw。",
              [meterRaw.toString()],
            );
          }
          meter = kinds.first;
          if (json["from"] != null || json["to"] != null) {
            throw const AppFormatException(
              AppErrorCode.errorInvalidParameterType,
              "meter 图元不需要 from/to 字段。",
              ["from"],
            );
          }
        } else {
          from = VisualPoint.fromJson(json["from"]);
          to = VisualPoint.fromJson(json["to"]);
          if (json["at"] != null) {
            throw const AppFormatException(
              AppErrorCode.errorInvalidParameterType,
              "circuit 图元不需要 at 字段。",
              ["at"],
            );
          }
          if (json["meter"] != null) {
            throw const AppFormatException(
              AppErrorCode.errorInvalidParameterType,
              "只有 meter 图元能带 meter 字段。",
              ["meter"],
            );
          }
        }
        final closed = _optBool(json, "closed", "circuit 图元");
        if (closed && comp != CircuitComponent.powerSwitch) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "只有 switch 图元能带 closed 字段。",
            ["closed"],
          );
        }
        return CircuitElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          component: comp,
          from: from,
          to: to,
          at: at,
          closed: closed,
          meter: meter,
          label: switch (json["label"]) {
            null => null,
            final String s => s,
            _ => throw const AppFormatException(
              AppErrorCode.errorParameterMustBeText,
              "circuit 图元的 label 必须是文字。",
            ),
          },
        );
      default:
        throw AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          "未知的图元类型：$type。",
          [type],
        );
    }
  }
}

List<VisualPoint> _parsePoints(dynamic raw, String what, int minLength) {
  if (raw is! List) {
    throw AppFormatException(
      AppErrorCode.errorInvalidParameterType,
      "$what 图元的 points 必须是数组。",
      ["points"],
    );
  }
  if (raw.length < minLength) {
    throw AppFormatException(
      AppErrorCode.errorInvalidParameterType,
      "$what 图元至少需要 $minLength 个点。",
      ["points"],
    );
  }
  return raw.map((p) => VisualPoint.fromJson(p)).toList();
}

/// Text/math_label content must be non-empty and at most 500 chars
/// (contract table); an empty label renders nothing, a longer one is
/// almost certainly a paste error.
void _checkTextLength(String text, String what) {
  if (text.isEmpty) {
    throw AppFormatException(
      AppErrorCode.errorInvalidParameterType,
      "$what 的文字不能为空。",
    );
  }
  if (text.length > 500) {
    throw AppFormatException(
      AppErrorCode.errorInvalidParameterType,
      "$what 的文字不能超过 500 个字符。",
    );
  }
}

bool _optBool(Map<String, dynamic> json, String key, String what) {
  final value = json[key];
  if (value == null) return false;
  if (value is! bool) {
    throw AppFormatException(
      AppErrorCode.errorInvalidParameterType,
      "$what 的 $key 必须是布尔值。",
      [key],
    );
  }
  return value;
}
