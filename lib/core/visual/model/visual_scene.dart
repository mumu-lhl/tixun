/// Visual DSL v1 scene model (`VisualScene` + controls, timeline,
/// annotations, meta).
///
/// JSON shape follows `~/workspace/push-tmp/tixun-visual-dsl-v1.md`.
/// `VisualScene.fromJson` rejects unknown fields at every level and runs
/// the full validator first (see `visual_validator.dart`), mirroring
/// `QuestionSpec.fromJson`: malformed input throws [AppFormatException],
/// never a raw [TypeError].
library;

import "package:tixun/core/l10n/app_error.dart";
import "package:tixun/core/visual/model/visual_constraints.dart";
import "package:tixun/core/visual/model/visual_elements.dart";
import "package:tixun/core/visual/validation/visual_validator.dart";

export "package:tixun/core/visual/model/visual_elements.dart";

part "visual_controls.dart";
part "visual_timeline.dart";

/// Circuit elements use a dedicated renderer. Charts use the common
/// element engine and express curves with plot elements.
enum VisualSceneKind {
  plot2d,
  geometry,
  physics,
  vector,
  chart,
  circuit,
  chemistry,
  geography,
}

/// `[min, max]` range (view axes, plot domains).
class VisualRange {
  const VisualRange(this.min, this.max);

  final double min;
  final double max;

  double get span => max - min;

  factory VisualRange.fromJson(dynamic json) {
    if (json is! List || json.length != 2) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        "范围必须是 [min, max] 形式的数组。",
        ["range"],
      );
    }
    final min = json[0];
    final max = json[1];
    if (min is! num ||
        max is! num ||
        !min.toDouble().isFinite ||
        !max.toDouble().isFinite) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeNumber,
        "范围端点必须是有限数字。",
      );
    }
    final range = VisualRange(min.toDouble(), max.toDouble());
    if (range.min >= range.max) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        "范围下限必须小于上限。",
        ["range"],
      );
    }
    if (range.span > visualMaxRangeSpan) {
      throw AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        "范围跨度超过 $visualMaxRangeSpan。",
        ["range"],
      );
    }
    return range;
  }

  List<double> toJson() => [min, max];

  @override
  bool operator ==(Object other) =>
      other is VisualRange && min == other.min && max == other.max;

  @override
  int get hashCode => Object.hash(min, max);
}

/// Model parameters are available in expressions and as coordinate bindings.
class VisualModel {
  const VisualModel({
    this.expression,
    this.parameters = const {},
    this.showAxes,
  });

  final String? expression;
  final Map<String, double> parameters;
  final bool? showAxes;

  factory VisualModel.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {
      "expression",
      "parameters",
      "showAxes",
    }, "model");
    Map<String, double> parameters = const {};
    if (json["parameters"] != null) {
      final raw = json["parameters"];
      if (raw is! Map<String, dynamic>) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          "model 的 parameters 必须是对象。",
          ["parameters"],
        );
      }
      parameters = raw.map((key, value) {
        if (value is! num || !value.toDouble().isFinite) {
          throw AppFormatException(
            AppErrorCode.errorParameterMustBeNumber,
            "参数 $key 必须是有限数字。",
            [key],
          );
        }
        return MapEntry(key, value.toDouble());
      });
    }
    final expression = json["expression"];
    if (expression != null && expression is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        "model 的 expression 必须是文字。",
      );
    }
    final showAxes = json["showAxes"];
    if (showAxes != null && showAxes is! bool) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        "model 的 showAxes 必须是布尔值。",
        ["showAxes"],
      );
    }
    return VisualModel(
      expression: expression as String?,
      parameters: parameters,
      showAxes: showAxes as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (expression != null) "expression": expression,
    if (parameters.isNotEmpty) "parameters": parameters,
    if (showAxes != null) "showAxes": showAxes,
  };
}

/// Visible coordinate ranges. Absent ranges are auto-fit by the renderer.
class VisualView {
  const VisualView({this.x, this.y});

  final VisualRange? x;
  final VisualRange? y;

  factory VisualView.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {"x", "y"}, "view");
    return VisualView(
      x: json["x"] == null ? null : VisualRange.fromJson(json["x"]),
      y: json["y"] == null ? null : VisualRange.fromJson(json["y"]),
    );
  }

  Map<String, dynamic> toJson() => {
    if (x != null) "x": x!.toJson(),
    if (y != null) "y": y!.toJson(),
  };
}

class VisualAnnotation {
  const VisualAnnotation({required this.at, required this.text});

  final VisualPoint at;
  final String text;

  factory VisualAnnotation.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {"at", "text"}, "annotation");
    final at = json["at"];
    if (at == null) {
      throw const AppFormatException(
        AppErrorCode.errorMissingParameter,
        "标注缺少字段：at。",
      );
    }
    final text = json["text"];
    if (text is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        "标注的 text 必须是文字。",
      );
    }
    return VisualAnnotation(at: VisualPoint.fromJson(at), text: text);
  }

  Map<String, dynamic> toJson() => {"at": at.toJson(), "text": text};
}

/// Non-executable metadata. `alt` is the accessibility text (required when
/// the scene has no `title`); `schematic` marks the scene as a
/// not-to-scale sketch whose content is not strictly verified.
class VisualMeta {
  const VisualMeta({this.alt, this.schematic = false});

  final String? alt;
  final bool schematic;

  factory VisualMeta.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {"alt", "schematic"}, "meta");
    final alt = json["alt"];
    if (alt != null && alt is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        "meta 的 alt 必须是文字。",
      );
    }
    final schematic = json["schematic"];
    if (schematic != null && schematic is! bool) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        "meta 的 schematic 必须是布尔值。",
        ["schematic"],
      );
    }
    return VisualMeta(
      alt: alt as String?,
      schematic: schematic as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    if (alt != null) "alt": alt,
    if (schematic) "schematic": true,
  };
}

const _topLevelFields = {
  "v",
  "kind",
  "title",
  "model",
  "view",
  "elements",
  "controls",
  "timeline",
  "annotations",
  "meta",
  "constraints",
};

/// A Visual DSL v1 scene.
///
/// Direct `const` construction bypasses validation by design (the model
/// classes are plain data holders); every entry point that accepts
/// untrusted JSON — `VisualScene.fromJson` and `VisualStore.create` /
/// `revise` — runs the full validator first, so an unvalidated scene
/// cannot be stored or rebuilt from a stored row. Changing the
/// constructors to validate would be a breaking API change and is
/// deliberately not done.
class VisualScene {
  const VisualScene({
    this.v = 1,
    required this.kind,
    this.title,
    this.model,
    this.view,
    this.elements = const [],
    this.controls = const [],
    this.timeline,
    this.annotations = const [],
    this.meta,
    this.constraints = const [],
  });

  final int v;
  final VisualSceneKind kind;
  final String? title;
  final VisualModel? model;
  final VisualView? view;
  final List<VisualElement> elements;
  final List<VisualControl> controls;
  final VisualTimeline? timeline;
  final List<VisualAnnotation> annotations;
  final VisualMeta? meta;
  final List<VisualConstraint> constraints;

  List<String> get allElementIds => [
    for (final element in elements) ...element.allIds,
  ];

  /// Total element count, counting group children (limit: 256).
  int get elementCount => allElementIds.length;

  Set<String> get parameterNames => model?.parameters.keys.toSet() ?? {};

  factory VisualScene.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, _topLevelFields, "场景");
    final validation = validateVisualScene(json);
    if (validation.errors.isNotEmpty) {
      final first = validation.errors.first;
      throw AppFormatException(
        _errorCodeFor(first),
        first.message,
        first.path == null ? const [] : [first.path!],
      );
    }
    final kindRaw = json["kind"] as String;
    final kind = VisualSceneKind.values.firstWhere((k) => k.name == kindRaw);
    VisualModel? model;
    if (json["model"] != null) {
      model = VisualModel.fromJson(json["model"] as Map<String, dynamic>);
    }
    VisualView? view;
    if (json["view"] != null) {
      view = VisualView.fromJson(json["view"] as Map<String, dynamic>);
    }
    List<VisualElement> elements = const [];
    if (json["elements"] != null) {
      elements = (json["elements"] as List)
          .map((e) => VisualElement.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    List<VisualControl> controls = const [];
    if (json["controls"] != null) {
      controls = (json["controls"] as List)
          .map((c) => VisualControl.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    VisualTimeline? timeline;
    if (json["timeline"] != null) {
      timeline = VisualTimeline.fromJson(
        json["timeline"] as Map<String, dynamic>,
      );
    }
    List<VisualAnnotation> annotations = const [];
    if (json["annotations"] != null) {
      annotations = (json["annotations"] as List)
          .map((a) => VisualAnnotation.fromJson(a as Map<String, dynamic>))
          .toList();
    }
    VisualMeta? meta;
    if (json["meta"] != null) {
      meta = VisualMeta.fromJson(json["meta"] as Map<String, dynamic>);
    }
    List<VisualConstraint> constraints = const [];
    if (json["constraints"] != null) {
      constraints = (json["constraints"] as List)
          .map((c) => VisualConstraint.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    final title = json["title"];
    return VisualScene(
      v: (json["v"] as num).toInt(),
      kind: kind,
      title: title as String?,
      model: model,
      view: view,
      elements: elements,
      controls: controls,
      timeline: timeline,
      annotations: annotations,
      meta: meta,
      constraints: constraints,
    );
  }

  /// Maps the first validation error to the most specific
  /// [AppErrorCode] available. The enum has no codes for range,
  /// expression, reference or constraint failures, so those stay
  /// [AppErrorCode.errorInvalidParameterType]. `invalid_type` is refined
  /// by the validator's own message wording (text- vs number-expected):
  /// the issue carries no expected-type field, and the messages are the
  /// validator's stable strings.
  static AppErrorCode _errorCodeFor(VisualIssue issue) {
    switch (issue.code) {
      case "unknown_field":
        return AppErrorCode.errorUnknownParameter;
      case "missing_field":
        return AppErrorCode.errorMissingParameter;
      case "non_finite_number":
        return AppErrorCode.errorParameterMustBeNumber;
      case "invalid_type":
        if (issue.message.contains("必须是文字")) {
          return AppErrorCode.errorParameterMustBeText;
        }
        if (issue.message.contains("必须是数字") ||
            issue.message.contains("必须是整数") ||
            issue.message.contains("必须是有限数字")) {
          return AppErrorCode.errorParameterMustBeNumber;
        }
        return AppErrorCode.errorInvalidParameterType;
      default:
        return AppErrorCode.errorInvalidParameterType;
    }
  }

  Map<String, dynamic> toJson() => {
    "v": v,
    "kind": kind.name,
    if (title != null) "title": title,
    if (model != null) "model": model!.toJson(),
    if (view != null) "view": view!.toJson(),
    if (elements.isNotEmpty)
      "elements": elements.map((e) => e.toJson()).toList(),
    if (controls.isNotEmpty)
      "controls": controls.map((c) => c.toJson()).toList(),
    if (timeline != null) "timeline": timeline!.toJson(),
    if (annotations.isNotEmpty)
      "annotations": annotations.map((a) => a.toJson()).toList(),
    if (meta != null) "meta": meta!.toJson(),
    if (constraints.isNotEmpty)
      "constraints": constraints.map((c) => c.toJson()).toList(),
  };
}
