/// Structural + semantic validation for Visual DSL v1 scenes.
///
/// [validateVisualScene] walks raw decoded JSON and returns a
/// [VisualValidation] instead of throwing: every malformed shape is reported
/// as an issue with a stable `code`, a human-readable `message` and a JSON
/// path (e.g. `elements[2].r`). The only inputs that can still throw are
/// non-JSON values that cannot be inspected at all (the entry point takes a
/// `Map`, so this is limited to programmer error, not model output).
///
/// `verificationStatus` rule (v1, kept simple by design):
/// - `unverified` — any error (`ok` is false);
/// - `schematic` — no errors, but `meta.schematic == true` (the scene is
///   declared a not-to-scale sketch) or a warning about unverifiable
///   content;
/// - `verified` — no errors and no unverifiable-content warnings.
///
/// In v1 the "unverifiable content" warnings are `schematic_content`
/// (explicit `meta.schematic`) and `constraint_unverifiable` (a
/// constraint references `$param`-bound geometry that cannot be checked
/// statically). A structurally valid scene whose math can be checked
/// locally is `verified`.
///
/// `computed` is intentionally an empty map: derived values (zeros,
/// intersections, extrema) are computed by the tool layer with
/// `computeDerivedValues` and attached to the tool result (documented
/// layering, not a gap). The one sampling-flavoured check this validator
/// does own is the finite-sample probe for plot curves (see
/// [_checkCurveSamples]): it evaluates the expression at the render
/// resolution to count finite samples in view, using only the expression
/// evaluator — full curve sampling (segments, pole breaks) stays in the
/// math slice.
library;

import "dart:convert";
import "dart:math" as math;

import "package:tixun/core/visual/math/expression.dart";
import "package:tixun/core/visual/model/visual_constraints.dart";
import "package:tixun/core/visual/model/visual_elements.dart";

part "visual_element_validation.dart";
part "visual_constraint_validation.dart";
part "visual_interaction_validation.dart";
part "visual_scene_diagnostics.dart";

part "visual_scene_validation.dart";

/// Maximum serialized scene JSON size, in UTF-8 bytes of the
/// `jsonEncode` output (not UTF-16 code units: a 40000-character CJK
/// title is ~120 KiB and must count as over the limit).
const visualMaxSceneJsonBytes = 64 * 1024;

/// Maximum element count, counting group children.
const visualMaxElements = 256;

const visualMaxPlotSamples = 4096;

/// Default curve samples when a `plot` element omits `samples`
/// (mirrors the renderer default).
const visualDefaultPlotSamples = 1024;

const visualMaxControls = 12;

const visualMaxTracks = 32;

const visualMaxSteps = 30;

const visualMaxRangeSpan = 1e9;
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

const _kinds = {
  "plot2d",
  "geometry",
  "physics",
  "vector",
  "chart",
  "circuit",
  "chemistry",
  "geography",
};

const _elementTypes = {
  "point",
  "line",
  "polyline",
  "polygon",
  "circle",
  "arc",
  "arrow",
  "text",
  "math_label",
  "group",
  "plot",
  "circuit",
};

final _styles = VisualStyle.values.map((s) => s.name).toSet();

class VisualIssue {
  const VisualIssue({
    required this.code,
    required this.message,
    this.path,
    required this.isError,
  });

  /// Stable machine-readable code, e.g. `unknown_field`, `unknown_variable`.
  final String code;

  /// Human-readable message (Chinese, suitable for logs; user-facing text
  /// is composed by the caller).
  final String message;

  /// JSON path of the offending value, e.g. `elements[2].r`.
  final String? path;

  final bool isError;
}

class VisualValidation {
  const VisualValidation({
    required this.ok,
    required this.errors,
    required this.warnings,
    required this.computed,
    required this.verificationStatus,
  });

  final bool ok;
  final List<VisualIssue> errors;
  final List<VisualIssue> warnings;

  /// Derived values (zeros, intersections, extrema). Always empty from
  /// this validator; the tool layer fills it via `computeDerivedValues`.
  final Map<String, dynamic> computed;

  /// `'verified' | 'schematic' | 'unverified'`.
  final String verificationStatus;
}

/// Validates a decoded Visual DSL v1 scene document.
///
/// Never throws on malformed model output: wrong types, missing fields,
/// unknown fields, bad ranges and bad expressions are all reported as
/// issues.
VisualValidation validateVisualScene(Map<String, dynamic> json) {
  final v = _Validator();
  return v.run(json);
}

/// Whether the segments [a] and [b] (each a pair of endpoints) intersect.
///
/// Standard orientation test: the segments cross when the endpoints of
/// each lie on opposite sides of the other segment's line; collinear
/// cases count as intersecting when the projections overlap, endpoints
/// included (so touching at an endpoint, or a segment lying on top of
/// another, both intersect). Parallelism alone says nothing — two
/// non-parallel segments can still miss each other.
bool _segmentsIntersect(
  ((double, double), (double, double)) a,
  ((double, double), (double, double)) b,
) {
  double orient((double, double) p, (double, double) q, (double, double) r) =>
      (q.$1 - p.$1) * (r.$2 - p.$2) - (q.$2 - p.$2) * (r.$1 - p.$1);
  bool onSegment((double, double) p, (double, double) q, (double, double) r) =>
      q.$1 >= math.min(p.$1, r.$1) &&
      q.$1 <= math.max(p.$1, r.$1) &&
      q.$2 >= math.min(p.$2, r.$2) &&
      q.$2 <= math.max(p.$2, r.$2);

  final (a1, a2) = a;
  final (b1, b2) = b;
  final o1 = orient(a1, a2, b1);
  final o2 = orient(a1, a2, b2);
  final o3 = orient(b1, b2, a1);
  final o4 = orient(b1, b2, a2);
  if (((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) &&
      ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0))) {
    return true;
  }
  if (o1 == 0 && onSegment(a1, b1, a2)) return true;
  if (o2 == 0 && onSegment(a1, b2, a2)) return true;
  if (o3 == 0 && onSegment(b1, a1, b2)) return true;
  if (o4 == 0 && onSegment(b1, a2, b2)) return true;
  return false;
}

class _Validator {
  final errors = <VisualIssue>[];
  final warnings = <VisualIssue>[];

  final _parameters = <String>{};

  /// Parameter values declared by `model.parameters`, for folding
  /// `if()`/`&&`/`||` conditions when checking unknown variables: a
  /// branch whose condition folds to a constant under these values can
  /// never run, so its variables are not reported.
  final _parameterValues = <String, double>{};

  /// All element ids (including group children).
  final _elementIds = <String>{};

  /// Literal bounding boxes of elements, for view warnings.
  /// Each entry is (minX, minY, maxX, maxY) in model coordinates.
  final _literalBounds = <(double, double, double, double)>[];

  final _controlKinds = <String, String>{};

  /// `visibleWhen` references to check after controls are known.
  final _visibleWhenRefs = <({String control, String path})>[];

  var _hasCircuitElement = false;

  final _elementTypesById = <String, String>{};

  /// Literal positions of `point` elements (absent when `$param`-bound).
  final _pointPositions = <String, (double, double)>{};

  final _lineSegments = <String, ((double, double), (double, double))>{};

  final _circles = <String, ((double, double), double)>{};

  /// Ids whose geometry is `$param`-bound (present but unchecked).
  final _boundPointIds = <String>{};
  final _boundSegmentIds = <String>{};
  final _boundCircleIds = <String>{};

  /// Ids whose element type is known but whose literal geometry is
  /// missing or malformed (not bound): the element error already covers
  /// the shape, but a constraint referencing such an id must still
  /// record that it cannot be checked, instead of silently skipping.
  final _unresolvedPointIds = <String>{};
  final _unresolvedSegmentIds = <String>{};
  final _unresolvedCircleIds = <String>{};

  /// Whether the `elements` section itself was malformed (present but
  /// not an array): the geometry maps are then empty by construction,
  /// so constraint evaluation would only produce cascade noise and is
  /// skipped entirely.
  var _elementsMalformed = false;

  /// Plot curves to probe for finite samples once the view is known
  /// (expression, domain, effective sample count, JSON path). The model
  /// expression is recorded separately (domain-less).
  final _plotCurves =
      <
        ({
          String expression,
          (double, double)? domain,
          int samples,
          String path,
        })
      >[];
  String? _modelExpression;

  /// Whether `meta.schematic` is true (set in `run` before element and
  /// constraint checks, so violations can downgrade to warnings).
  var _schematic = false;

  void _error(String code, String message, [String? path]) {
    errors.add(
      VisualIssue(code: code, message: message, path: path, isError: true),
    );
  }

  void _warning(String code, String message, [String? path]) {
    warnings.add(
      VisualIssue(code: code, message: message, path: path, isError: false),
    );
  }

  VisualValidation run(Map<String, dynamic> json) {
    try {
      // UTF-8 bytes, not String.length (UTF-16 units): the limit is a
      // wire-size bound, and a CJK-heavy scene is ~3x its .length.
      if (utf8.encode(jsonEncode(json)).length > visualMaxSceneJsonBytes) {
        _error(
          "scene_too_large",
          "场景数据超过 ${visualMaxSceneJsonBytes ~/ 1024} KiB。",
        );
      }
    } on Object {
      _error("invalid_json", "场景无法序列化为 JSON。");
    }

    _checkUnknownFields(json, _topLevelFields, "场景", null);

    final v = json["v"];
    if (v == null) {
      _error("missing_field", "场景缺少字段：v。", "v");
    } else if (v is! num || v.toDouble() != 1) {
      _error("unsupported_version", "只支持 DSL v1（v 必须为 1）。", "v");
    }

    final kind = json["kind"];
    if (kind == null) {
      _error("missing_field", "场景缺少字段：kind。", "kind");
    } else if (kind is! String || !_kinds.contains(kind)) {
      _error("unknown_kind", "未知的场景类型：$kind。", "kind");
    }

    final title = json["title"];
    if (title != null && title is! String) {
      _error("invalid_type", "title 必须是文字。", "title");
    }

    _schematic =
        json["meta"] is Map<String, dynamic> &&
        (json["meta"] as Map<String, dynamic>)["schematic"] == true;

    _checkModel(json["model"]);
    _checkView(json["view"]);
    _checkElements(json["elements"]);
    // When the elements section itself is malformed the geometry maps
    // are empty by construction; evaluating constraints against them
    // would only add cascade noise on top of the elements error.
    if (!_elementsMalformed) _checkConstraints(json["constraints"]);
    _checkControls(json["controls"]);
    _checkTimeline(json["timeline"]);
    _checkAnnotations(json["annotations"]);
    _checkMeta(json["meta"]);

    for (final ref in _visibleWhenRefs) {
      final kind = _controlKinds[ref.control];
      if (kind == null) {
        _error(
          "unknown_control",
          "visibleWhen 引用了不存在的控件：${ref.control}。",
          ref.path,
        );
      } else if (kind != "toggle") {
        _error(
          "invalid_control_kind",
          "visibleWhen 只能引用 toggle 控件：${ref.control} 是 $kind。",
          ref.path,
        );
      }
    }

    _checkWarnings(json);

    // A circuit scene with no circuit element is almost certainly a
    // wrong kind (or a missing element): warn rather than fail, since
    // the scene may legitimately be only wires-as-lines plus labels.
    if (kind == "circuit" && !_hasCircuitElement) {
      _warning(
        "no_circuit_element",
        "circuit 场景里没有 circuit 图元，请确认 kind 是否写错。",
        "elements",
      );
    }

    final status = errors.isNotEmpty
        ? "unverified"
        : (_schematic ||
              warnings.any(
                (w) =>
                    w.code == "schematic_content" ||
                    w.code == "constraint_unverifiable",
              ))
        ? "schematic"
        : "verified";
    return VisualValidation(
      ok: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      computed: const {},
      verificationStatus: status,
    );
  }

  void _checkUnknownFields(
    Map<String, dynamic> json,
    Set<String> allowed,
    String what,
    String? path,
  ) {
    for (final key in json.keys) {
      if (!allowed.contains(key)) {
        _error(
          "unknown_field",
          "$what 包含未知字段：$key。",
          path == null ? key : "$path.$key",
        );
      }
    }
  }

  bool _isMap(dynamic value) => value is Map<String, dynamic>;

  /// Returns the finite double value of [value], or null (after reporting).
  /// A null value returns null silently: callers report it as a missing
  /// field so a missing value is never reported twice.
  double? _finiteNumber(dynamic value, String path, String what) {
    if (value == null) return null;
    if (value is! num) {
      _error("invalid_type", "$what 必须是数字。", path);
      return null;
    }
    final d = value.toDouble();
    if (!d.isFinite) {
      _error("non_finite_number", "$what 必须是有有限数字。", path);
      return null;
    }
    return d;
  }

  /// Validates an expression string; reports parse failures and references
  /// to variables outside [allowedVars] (plus the built-ins x/t/pi/e).
  /// The unknown-variable check respects `if()`/`&&`/`||` laziness: a
  /// variable that only appears in a branch whose condition folds to a
  /// constant under the model parameters can never be read, so it is not
  /// reported (see [Expression.variablesReachable]). Returns true when
  /// no issue was recorded for this expression.
  bool _checkExpression(String source, String path) {
    Expression expr;
    try {
      expr = Expression.parse(source);
    } on FormatException catch (e) {
      _error("expression_error", "表达式无效：${e.message}", path);
      return false;
    }
    const allowed = {"x", "t", "pi", "e"};
    var ok = true;
    for (final name in expr.variablesReachable(_parameterValues)) {
      if (!allowed.contains(name) && !_parameters.contains(name)) {
        _error("unknown_variable", "表达式引用了未知变量：$name。", path);
        ok = false;
      }
    }
    return ok;
  }

  /// Validates a coordinate component; returns its literal value, or null
  /// for a `$param` binding (after checking the parameter exists).
  double? _checkCoord(dynamic raw, String path) {
    if (raw is num) {
      return _finiteNumber(raw, path, "坐标");
    }
    if (raw is Map<String, dynamic>) {
      _checkUnknownFields(raw, const {r"$param"}, "坐标绑定", path);
      final name = raw[r"$param"];
      if (name == null) {
        _error("missing_field", r"坐标绑定缺少字段：$param。", path);
        return null;
      }
      if (name is! String || name.isEmpty) {
        _error("invalid_type", r"坐标绑定的 $param 必须是非空文字。", path);
        return null;
      }
      if (!_parameters.contains(name)) {
        _error("unknown_parameter", "坐标绑定了未知参数：$name。", path);
      }
      return null;
    }
    _error("invalid_type", "坐标必须是数字或参数绑定。", path);
    return null;
  }

  /// Validates a `[x, y]` point; returns the literal pair, or null when
  /// any component is a binding or invalid. A null input returns null
  /// silently: callers report it as a missing field, so a missing value
  /// is never reported twice (once here as `invalid_type`, once there
  /// as `missing_field`).
  (double, double)? _checkPoint(dynamic raw, String path) {
    if (raw == null) return null;
    if (raw is! List || raw.length != 2) {
      _error("invalid_type", "坐标点必须是 [x, y] 形式的数组。", path);
      return null;
    }
    final x = _checkCoord(raw[0], "$path[0]");
    final y = _checkCoord(raw[1], "$path[1]");
    if (x == null || y == null) return null;
    return (x, y);
  }

  (double, double)? _checkRange(dynamic raw, String path, String what) {
    if (raw is! List || raw.length != 2) {
      _error("invalid_type", "$what 必须是 [min, max] 形式的数组。", path);
      return null;
    }
    if (raw[0] == null || raw[1] == null) {
      _error("invalid_type", "$what 的端点必须是数字。", path);
      return null;
    }
    final min = _finiteNumber(raw[0], "$path[0]", "$what 的下限");
    final max = _finiteNumber(raw[1], "$path[1]", "$what 的上限");
    if (min == null || max == null) return null;
    if (min >= max) {
      _error("invalid_range", "$what 的下限必须小于上限。", path);
      return null;
    }
    if (max - min > visualMaxRangeSpan) {
      _error("invalid_range", "$what 的跨度超过 $visualMaxRangeSpan。", path);
      return null;
    }
    // Preserve enough relative precision to subdivide the range safely.
    // Bounded painter ticks additionally protect legacy/constructed scenes.
    final subdivision = (max - min) / 16;
    if (min + subdivision == min || max - subdivision == max) {
      _error("invalid_range", "$what 的端点精度不足，无法安全绘制刻度。", path);
      return null;
    }
    return (min, max);
  }

  static String _fmt(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(4);

  void _addBounds(List<(double, double)> points) {
    if (points.isEmpty) return;
    var minX = points.first.$1;
    var minY = points.first.$2;
    var maxX = minX;
    var maxY = minY;
    for (final p in points) {
      if (p.$1 < minX) minX = p.$1;
      if (p.$2 < minY) minY = p.$2;
      if (p.$1 > maxX) maxX = p.$1;
      if (p.$2 > maxY) maxY = p.$2;
    }
    _literalBounds.add((minX, minY, maxX, maxY));
  }
}
