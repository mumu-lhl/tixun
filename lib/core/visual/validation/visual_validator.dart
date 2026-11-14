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
/// `computed` is intentionally an empty map for now: derived values
/// (zeros, intersections, extrema) are filled by the math slice via a
/// separate function. Sampling-based warnings (e.g. a curve with fewer
/// than 2 finite samples in view) are likewise deferred to the math slice
/// — this validator must not implement sampling.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:tixun/core/visual/math/expression.dart';
import 'package:tixun/core/visual/model/visual_constraints.dart';
import 'package:tixun/core/visual/model/visual_elements.dart';

/// Maximum serialized scene JSON size (bytes of `jsonEncode` output).
const visualMaxSceneJsonBytes = 64 * 1024;

/// Maximum element count, counting group children.
const visualMaxElements = 256;

/// Maximum curve samples per `plot` element.
const visualMaxPlotSamples = 4096;

/// Maximum controls per scene.
const visualMaxControls = 12;

/// Maximum timeline tracks per scene.
const visualMaxTracks = 32;

/// Maximum teaching steps per scene.
const visualMaxSteps = 30;

/// Maximum view / plot-domain span.
const visualMaxRangeSpan = 1e9;
const _topLevelFields = {
  'v',
  'kind',
  'title',
  'model',
  'view',
  'elements',
  'controls',
  'timeline',
  'annotations',
  'meta',
  'constraints',
};

const _kinds = {
  'plot2d',
  'geometry',
  'physics',
  'vector',
  'chart',
  'circuit',
  'chemistry',
  'geography',
};

const _elementTypes = {
  'point',
  'line',
  'polyline',
  'polygon',
  'circle',
  'arc',
  'arrow',
  'text',
  'math_label',
  'group',
  'plot',
  'circuit',
};

final _styles = VisualStyle.values.map((s) => s.name).toSet();

/// One validation finding.
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

  /// True for errors (which make [VisualValidation.ok] false).
  final bool isError;
}

/// The result of [validateVisualScene].
class VisualValidation {
  const VisualValidation({
    required this.ok,
    required this.errors,
    required this.warnings,
    required this.computed,
    required this.verificationStatus,
  });

  /// True when there are no errors (warnings allowed).
  final bool ok;
  final List<VisualIssue> errors;
  final List<VisualIssue> warnings;

  /// Derived values (zeros, intersections, extrema). Empty in v1; the
  /// math slice fills this via a separate function.
  // TODO(visual-math): populate computed values (zeros/intersections/extrema).
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

  /// Parameter names declared by `model.parameters`.
  final _parameters = <String>{};

  /// All element ids (including group children).
  final _elementIds = <String>{};

  /// Literal bounding boxes of elements, for view warnings.
  /// Each entry is (minX, minY, maxX, maxY) in model coordinates.
  final _literalBounds = <(double, double, double, double)>[];

  /// Control id -> kind.
  final _controlKinds = <String, String>{};

  /// `visibleWhen` references to check after controls are known.
  final _visibleWhenRefs = <({String control, String path})>[];

  /// Whether any `circuit` element was seen (any depth).
  var _hasCircuitElement = false;

  /// Element id -> element type, for constraint reference checks.
  final _elementTypesById = <String, String>{};

  /// Literal positions of `point` elements (absent when `$param`-bound).
  final _pointPositions = <String, (double, double)>{};

  /// Literal endpoints of `line`/`arrow` elements.
  final _lineSegments = <String, ((double, double), (double, double))>{};

  /// Literal centers and radii of `circle` elements.
  final _circles = <String, ((double, double), double)>{};

  /// Ids whose geometry is `$param`-bound (present but unchecked).
  final _boundPointIds = <String>{};
  final _boundSegmentIds = <String>{};
  final _boundCircleIds = <String>{};

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
      if (jsonEncode(json).length > visualMaxSceneJsonBytes) {
        _error(
          'scene_too_large',
          '场景数据超过 ${visualMaxSceneJsonBytes ~/ 1024} KiB。',
        );
      }
    } on Object {
      _error('invalid_json', '场景无法序列化为 JSON。');
    }

    _checkUnknownFields(json, _topLevelFields, '场景', null);

    // --- v ---
    final v = json['v'];
    if (v == null) {
      _error('missing_field', '场景缺少字段：v。', 'v');
    } else if (v is! num || v.toDouble() != 1) {
      _error('unsupported_version', '只支持 DSL v1（v 必须为 1）。', 'v');
    }

    // --- kind ---
    final kind = json['kind'];
    if (kind == null) {
      _error('missing_field', '场景缺少字段：kind。', 'kind');
    } else if (kind is! String || !_kinds.contains(kind)) {
      _error('unknown_kind', '未知的场景类型：$kind。', 'kind');
    }

    // --- title ---
    final title = json['title'];
    if (title != null && title is! String) {
      _error('invalid_type', 'title 必须是文字。', 'title');
    }

    _schematic =
        json['meta'] is Map<String, dynamic> &&
        (json['meta'] as Map<String, dynamic>)['schematic'] == true;

    _checkModel(json['model']);
    _checkView(json['view']);
    _checkElements(json['elements']);
    _checkConstraints(json['constraints']);
    _checkControls(json['controls']);
    _checkTimeline(json['timeline']);
    _checkAnnotations(json['annotations']);
    _checkMeta(json['meta']);

    // Cross-checks that need the full picture.
    for (final ref in _visibleWhenRefs) {
      final kind = _controlKinds[ref.control];
      if (kind == null) {
        _error(
          'unknown_control',
          'visibleWhen 引用了不存在的控件：${ref.control}。',
          ref.path,
        );
      } else if (kind != 'toggle') {
        _error(
          'unknown_control',
          'visibleWhen 只能引用 toggle 控件：${ref.control} 是 $kind。',
          ref.path,
        );
      }
    }

    _checkWarnings(json);

    // A circuit scene with no circuit element is almost certainly a
    // wrong kind (or a missing element): warn rather than fail, since
    // the scene may legitimately be only wires-as-lines plus labels.
    if (kind == 'circuit' && !_hasCircuitElement) {
      _warning(
        'no_circuit_element',
        'circuit 场景里没有 circuit 图元，请确认 kind 是否写错。',
        'elements',
      );
    }

    final status = errors.isNotEmpty
        ? 'unverified'
        : (_schematic ||
              warnings.any(
                (w) =>
                    w.code == 'schematic_content' ||
                    w.code == 'constraint_unverifiable',
              ))
        ? 'schematic'
        : 'verified';
    return VisualValidation(
      ok: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      computed: const {},
      verificationStatus: status,
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  void _checkUnknownFields(
    Map<String, dynamic> json,
    Set<String> allowed,
    String what,
    String? path,
  ) {
    for (final key in json.keys) {
      if (!allowed.contains(key)) {
        _error(
          'unknown_field',
          '$what 包含未知字段：$key。',
          path == null ? key : '$path.$key',
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
      _error('invalid_type', '$what 必须是数字。', path);
      return null;
    }
    final d = value.toDouble();
    if (!d.isFinite) {
      _error('non_finite_number', '$what 必须是有有限数字。', path);
      return null;
    }
    return d;
  }

  /// Validates an expression string; reports parse failures and references
  /// to variables outside [allowedVars] (plus the built-ins x/t/pi/e).
  void _checkExpression(String source, String path) {
    Expression expr;
    try {
      expr = Expression.parse(source);
    } on FormatException catch (e) {
      _error('expression_error', '表达式无效：${e.message}', path);
      return;
    }
    const allowed = {'x', 't', 'pi', 'e'};
    for (final name in expr.variables) {
      if (!allowed.contains(name) && !_parameters.contains(name)) {
        _error('unknown_variable', '表达式引用了未知变量：$name。', path);
      }
    }
  }

  /// Validates a coordinate component; returns its literal value, or null
  /// for a `$param` binding (after checking the parameter exists).
  double? _checkCoord(dynamic raw, String path) {
    if (raw is num) {
      return _finiteNumber(raw, path, '坐标');
    }
    if (raw is Map<String, dynamic>) {
      _checkUnknownFields(raw, const {r'$param'}, '坐标绑定', path);
      final name = raw[r'$param'];
      if (name == null) {
        _error('missing_field', r'坐标绑定缺少字段：$param。', path);
        return null;
      }
      if (name is! String || name.isEmpty) {
        _error('invalid_type', r'坐标绑定的 $param 必须是非空文字。', path);
        return null;
      }
      if (!_parameters.contains(name)) {
        _error('unknown_parameter', '坐标绑定了未知参数：$name。', path);
      }
      return null;
    }
    _error('invalid_type', '坐标必须是数字或参数绑定。', path);
    return null;
  }

  /// Validates a `[x, y]` point; returns the literal pair, or null when
  /// any component is a binding or invalid.
  (double, double)? _checkPoint(dynamic raw, String path) {
    if (raw is! List || raw.length != 2) {
      _error('invalid_type', '坐标点必须是 [x, y] 形式的数组。', path);
      return null;
    }
    final x = _checkCoord(raw[0], '$path[0]');
    final y = _checkCoord(raw[1], '$path[1]');
    if (x == null || y == null) return null;
    return (x, y);
  }

  /// Validates a `[min, max]` range; returns it, or null when invalid.
  (double, double)? _checkRange(dynamic raw, String path, String what) {
    if (raw is! List || raw.length != 2) {
      _error('invalid_type', '$what 必须是 [min, max] 形式的数组。', path);
      return null;
    }
    if (raw[0] == null || raw[1] == null) {
      _error('invalid_type', '$what 的端点必须是数字。', path);
      return null;
    }
    final min = _finiteNumber(raw[0], '$path[0]', '$what 的下限');
    final max = _finiteNumber(raw[1], '$path[1]', '$what 的上限');
    if (min == null || max == null) return null;
    if (min >= max) {
      _error('invalid_range', '$what 的下限必须小于上限。', path);
      return null;
    }
    if (max - min > visualMaxRangeSpan) {
      _error('invalid_range', '$what 的跨度超过 $visualMaxRangeSpan。', path);
      return null;
    }
    return (min, max);
  }

  // -------------------------------------------------------------------------
  // Sections
  // -------------------------------------------------------------------------

  void _checkModel(dynamic raw) {
    if (raw == null) return;
    if (!_isMap(raw)) {
      _error('invalid_type', 'model 必须是对象。', 'model');
      return;
    }
    final model = raw as Map<String, dynamic>;
    _checkUnknownFields(
      model,
      const {'expression', 'parameters', 'showAxes'},
      'model',
      'model',
    );
    if (model['parameters'] != null) {
      final params = model['parameters'];
      if (!_isMap(params)) {
        _error('invalid_type', 'model 的 parameters 必须是对象。', 'model.parameters');
      } else {
        for (final entry in (params as Map<String, dynamic>).entries) {
          final value = entry.value;
          if (value is! num || !value.toDouble().isFinite) {
            _error(
              'invalid_type',
              '参数 ${entry.key} 必须是有限数字。',
              'model.parameters.${entry.key}',
            );
            continue;
          }
          _parameters.add(entry.key);
        }
      }
    }
    if (model['showAxes'] != null && model['showAxes'] is! bool) {
      _error('invalid_type', 'model 的 showAxes 必须是布尔值。', 'model.showAxes');
    }
    final expression = model['expression'];
    if (expression != null) {
      if (expression is! String) {
        _error('invalid_type', 'model 的 expression 必须是文字。', 'model.expression');
      } else if (expression.trim().isEmpty) {
        _error('invalid_value', 'model 的 expression 不能为空。', 'model.expression');
      } else {
        _checkExpression(expression, 'model.expression');
      }
    }
  }

  void _checkView(dynamic raw) {
    if (raw == null) return;
    if (!_isMap(raw)) {
      _error('invalid_type', 'view 必须是对象。', 'view');
      return;
    }
    final view = raw as Map<String, dynamic>;
    _checkUnknownFields(view, const {'x', 'y'}, 'view', 'view');
    if (view['x'] != null) _checkRange(view['x'], 'view.x', 'view.x');
    if (view['y'] != null) _checkRange(view['y'], 'view.y', 'view.y');
  }

  void _checkElements(dynamic raw) {
    if (raw == null) return;
    if (raw is! List) {
      _error('invalid_type', 'elements 必须是数组。', 'elements');
      return;
    }
    var count = 0;
    void countAll(dynamic element) {
      if (element is Map<String, dynamic>) {
        count++;
        final children = element['children'];
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
        'limit_exceeded',
        '图元数量超过 $visualMaxElements 个（共 $count 个）。',
        'elements',
      );
    }
    for (var i = 0; i < raw.length; i++) {
      _checkElement(raw[i], 'elements[$i]', 0);
    }
  }

  void _checkElement(dynamic raw, String path, int groupDepth) {
    if (!_isMap(raw)) {
      _error('invalid_type', '图元必须是对象。', path);
      return;
    }
    final element = raw as Map<String, dynamic>;
    final type = element['type'];
    const common = {'id', 'type', 'style', 'layer', 'visible', 'visibleWhen'};
    const perType = {
      'point': {'at', 'label', 'draggable'},
      'line': {'p1', 'p2', 'dashed'},
      'polyline': {'points'},
      'polygon': {'points', 'fill'},
      'circle': {'center', 'r'},
      'arc': {'center', 'r', 'startDeg', 'sweepDeg'},
      'arrow': {'from', 'to'},
      'text': {'at', 'text'},
      'math_label': {'at', 'tex'},
      'group': {'children'},
      'plot': {'expression', 'domain', 'samples'},
      'circuit': {'component', 'from', 'to', 'at', 'closed', 'meter', 'label'},
    };
    if (type is! String) {
      _error('missing_field', '图元缺少字段：type。', '$path.type');
      _checkUnknownFields(element, common, '图元', path);
      return;
    }
    if (!_elementTypes.contains(type)) {
      _error('unknown_element_type', '未知的图元类型：$type。', '$path.type');
      _checkUnknownFields(element, common, '图元', path);
      return;
    }
    if (type == 'circuit') _hasCircuitElement = true;
    _checkUnknownFields(
      element,
      {...common, ...perType[type]!},
      '$type 图元',
      path,
    );

    // id
    final id = element['id'];
    if (id == null) {
      _error('missing_field', '图元缺少字段：id。', '$path.id');
    } else if (id is! String || id.isEmpty) {
      _error('invalid_type', '图元的 id 必须是非空文字。', '$path.id');
    } else if (!_elementIds.add(id)) {
      _error('duplicate_id', '图元 id 重复：$id。', '$path.id');
    }
    if (id is String && id.isNotEmpty) _elementTypesById[id] = type;

    // style / layer / visible / visibleWhen
    if (element['style'] != null) {
      final style = element['style'];
      if (style is! String || !_styles.contains(style)) {
        _error('invalid_value', '图元的 style 无效：$style。', '$path.style');
      }
    }
    if (element['layer'] != null && element['layer'] is! int) {
      _error('invalid_type', '图元的 layer 必须是整数。', '$path.layer');
    }
    if (element['visible'] != null && element['visible'] is! bool) {
      _error('invalid_type', '图元的 visible 必须是布尔值。', '$path.visible');
    }
    if (element['visibleWhen'] != null) {
      final gate = element['visibleWhen'];
      if (!_isMap(gate)) {
        _error('invalid_type', '图元的 visibleWhen 必须是对象。', '$path.visibleWhen');
      } else {
        final gateMap = gate as Map<String, dynamic>;
        _checkUnknownFields(
          gateMap,
          const {'control', 'equals'},
          'visibleWhen',
          '$path.visibleWhen',
        );
        final control = gateMap['control'];
        if (control == null) {
          _error(
            'missing_field',
            'visibleWhen 缺少字段：control。',
            '$path.visibleWhen.control',
          );
        } else if (control is! String || control.isEmpty) {
          _error(
            'invalid_type',
            'visibleWhen 的 control 必须是非空文字。',
            '$path.visibleWhen.control',
          );
        } else {
          _visibleWhenRefs.add((
            control: control,
            path: '$path.visibleWhen.control',
          ));
        }
        if (gateMap['equals'] != null && gateMap['equals'] is! bool) {
          _error(
            'invalid_type',
            'visibleWhen 的 equals 必须是布尔值。',
            '$path.visibleWhen.equals',
          );
        }
      }
    }

    // Per-type fields.
    switch (type) {
      case 'point':
        final at = _checkPoint(element['at'], '$path.at');
        if (at != null) {
          _literalBounds.add((at.$1, at.$2, at.$1, at.$2));
          if (id is String) _pointPositions[id] = at;
        } else if (id is String && _isBoundPoint(element['at'])) {
          _boundPointIds.add(id);
        } else if (element['at'] == null) {
          _error('missing_field', 'point 图元缺少字段：at。', '$path.at');
        }
        if (element['label'] != null && element['label'] is! String) {
          _error('invalid_type', 'point 图元的 label 必须是文字。', '$path.label');
        }
        if (element['draggable'] != null && element['draggable'] is! bool) {
          _error(
            'invalid_type',
            'point 图元的 draggable 必须是布尔值。',
            '$path.draggable',
          );
        } else if (element['draggable'] == true) {
          // A dragged point is positioned by the user's finger, so its
          // coordinates must be literals; a `$param`-bound point has no
          // fixed position to drag from.
          final rawAt = element['at'];
          final bound =
              rawAt is List &&
              rawAt.length == 2 &&
              (rawAt[0] is Map || rawAt[1] is Map);
          if (bound) {
            _error(
              'invalid_value',
              'draggable 的 point 图元的 at 必须是字面坐标，不能绑定参数。',
              '$path.draggable',
            );
          }
        }
      case 'line':
        final linePoints = _checkLinePoints(element, path);
        if (linePoints.length == 2 && id is String) {
          _lineSegments[id] = (linePoints[0], linePoints[1]);
        } else if (id is String &&
            (_isBoundPoint(element['p1']) || _isBoundPoint(element['p2']))) {
          _boundSegmentIds.add(id);
        }
        if (element['dashed'] != null && element['dashed'] is! bool) {
          _error('invalid_type', 'line 图元的 dashed 必须是布尔值。', '$path.dashed');
        }
      case 'polyline':
        final points = _checkPointList(
          element['points'],
          '$path.points',
          2,
          'polyline',
        );
        _addBounds(points);
      case 'polygon':
        final points = _checkPointList(
          element['points'],
          '$path.points',
          3,
          'polygon',
        );
        _addBounds(points);
        if (element['fill'] != null && element['fill'] is! bool) {
          _error('invalid_type', 'polygon 图元的 fill 必须是布尔值。', '$path.fill');
        }
      case 'circle':
        final center = _checkPoint(element['center'], '$path.center');
        final r = _finiteNumber(element['r'], '$path.r', 'circle 的 r');
        if (element['center'] == null) {
          _error('missing_field', 'circle 图元缺少字段：center。', '$path.center');
        }
        if (element['r'] == null) {
          _error('missing_field', 'circle 图元缺少字段：r。', '$path.r');
        } else if (r != null && r <= 0) {
          _error('invalid_range', 'circle 的 r 必须大于 0。', '$path.r');
        }
        if (center != null && r != null && r > 0) {
          _literalBounds.add((
            center.$1 - r,
            center.$2 - r,
            center.$1 + r,
            center.$2 + r,
          ));
          if (id is String) _circles[id] = (center, r);
        } else if (id is String && _isBoundPoint(element['center'])) {
          _boundCircleIds.add(id);
        }
      case 'arc':
        final center = _checkPoint(element['center'], '$path.center');
        final r = _finiteNumber(element['r'], '$path.r', 'arc 的 r');
        // startDeg only needs the finiteness check; any angle is valid.
        _finiteNumber(element['startDeg'], '$path.startDeg', 'arc 的 startDeg');
        final sweepDeg = _finiteNumber(
          element['sweepDeg'],
          '$path.sweepDeg',
          'arc 的 sweepDeg',
        );
        if (element['center'] == null) {
          _error('missing_field', 'arc 图元缺少字段：center。', '$path.center');
        }
        if (element['r'] == null) {
          _error('missing_field', 'arc 图元缺少字段：r。', '$path.r');
        } else if (r != null && r <= 0) {
          _error('invalid_range', 'arc 的 r 必须大于 0。', '$path.r');
        }
        if (element['startDeg'] == null) {
          _error('missing_field', 'arc 图元缺少字段：startDeg。', '$path.startDeg');
        }
        if (element['sweepDeg'] == null) {
          _error('missing_field', 'arc 图元缺少字段：sweepDeg。', '$path.sweepDeg');
        } else if (sweepDeg != null && sweepDeg == 0) {
          _error('invalid_range', 'arc 的 sweepDeg 不能为 0。', '$path.sweepDeg');
        }
        if (center != null && r != null && r > 0) {
          _literalBounds.add((
            center.$1 - r,
            center.$2 - r,
            center.$1 + r,
            center.$2 + r,
          ));
        }
      case 'arrow':
        final arrowPoints = _checkLinePoints(element, path);
        if (arrowPoints.length == 2 && id is String) {
          _lineSegments[id] = (arrowPoints[0], arrowPoints[1]);
        } else if (id is String &&
            (_isBoundPoint(element['from']) || _isBoundPoint(element['to']))) {
          _boundSegmentIds.add(id);
        }
      case 'text':
        _checkLabeledPoint(element, path, 'text', 'text');
      case 'math_label':
        _checkLabeledPoint(element, path, 'math_label', 'tex');
      case 'group':
        if (groupDepth >= visualMaxGroupDepth) {
          _error(
            'invalid_value',
            'group 嵌套过深（最多 $visualMaxGroupDepth 层）。',
            path,
          );
          return;
        }
        final children = element['children'];
        if (children == null) {
          _error('missing_field', 'group 图元缺少字段：children。', '$path.children');
        } else if (children is! List) {
          _error('invalid_type', 'group 图元的 children 必须是数组。', '$path.children');
        } else {
          if (children.isEmpty) {
            _error('invalid_value', 'group 图元至少需要一个子图元。', '$path.children');
          }
          for (var i = 0; i < children.length; i++) {
            _checkElement(children[i], '$path.children[$i]', groupDepth + 1);
          }
        }
      case 'plot':
        final expression = element['expression'];
        if (expression == null) {
          _error(
            'missing_field',
            'plot 图元缺少字段：expression。',
            '$path.expression',
          );
        } else if (expression is! String) {
          _error(
            'invalid_type',
            'plot 图元的 expression 必须是文字。',
            '$path.expression',
          );
        } else if (expression.trim().isEmpty) {
          _error(
            'invalid_value',
            'plot 图元的 expression 不能为空。',
            '$path.expression',
          );
        } else {
          _checkExpression(expression, '$path.expression');
        }
        if (element['domain'] != null) {
          // Domain validity is checked; its x-range is not used for the
          // view-vs-content warnings (the curve's y-range needs sampling,
          // which this validator deliberately does not do).
          _checkRange(element['domain'], '$path.domain', 'plot 的 domain');
        }
        if (element['samples'] != null) {
          final samples = element['samples'];
          if (samples is! int) {
            _error('invalid_type', 'plot 图元的 samples 必须是整数。', '$path.samples');
          } else if (samples <= 0 || samples > visualMaxPlotSamples) {
            _error(
              'invalid_range',
              'plot 图元的 samples 必须在 1~$visualMaxPlotSamples 之间。',
              '$path.samples',
            );
          }
        }
      case 'circuit':
        const components = {'battery', 'resistor', 'switch', 'wire', 'meter'};
        final component = element['component'];
        if (component == null) {
          _error(
            'missing_field',
            'circuit 图元缺少字段：component。',
            '$path.component',
          );
        } else if (component is! String || !components.contains(component)) {
          _error(
            'invalid_value',
            'circuit 图元的 component 必须是 battery/resistor/switch/wire/meter 之一。',
            '$path.component',
          );
        } else if (component == 'meter') {
          final at = _checkPoint(element['at'], '$path.at');
          if (at != null) {
            _literalBounds.add((at.$1, at.$2, at.$1, at.$2));
          } else if (element['at'] == null) {
            _error('missing_field', 'meter 图元缺少字段：at。', '$path.at');
          }
          final meter = element['meter'];
          if (meter == null) {
            _error('missing_field', 'meter 图元缺少字段：meter。', '$path.meter');
          } else if (meter is! String ||
              (meter != 'ammeter' && meter != 'voltmeter')) {
            _error(
              'invalid_value',
              'meter 图元的 meter 必须是 ammeter 或 voltmeter。',
              '$path.meter',
            );
          }
          if (element['from'] != null || element['to'] != null) {
            _error('invalid_value', 'meter 图元不需要 from/to 字段。', '$path.from');
          }
        } else {
          // Two-point components (battery/resistor/switch/wire) use the
          // same from/to shape as `arrow`, so the shared checker applies.
          _checkLinePoints(element, path);
          if (element['at'] != null) {
            _error('invalid_value', 'circuit 图元不需要 at 字段。', '$path.at');
          }
          if (element['meter'] != null) {
            _error('invalid_value', '只有 meter 图元能带 meter 字段。', '$path.meter');
          }
        }
        if (element['closed'] != null && element['closed'] is! bool) {
          _error('invalid_type', 'circuit 图元的 closed 必须是布尔值。', '$path.closed');
        } else if (element['closed'] == true && component != 'switch') {
          _error('invalid_value', '只有 switch 图元能带 closed 字段。', '$path.closed');
        }
        if (element['label'] != null && element['label'] is! String) {
          _error('invalid_type', 'circuit 图元的 label 必须是文字。', '$path.label');
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
    final type = element['type'] as String;
    final firstKey = type == 'line' ? 'p1' : 'from';
    final secondKey = type == 'line' ? 'p2' : 'to';
    final points = <(double, double)>[];
    for (final key in [firstKey, secondKey]) {
      if (element[key] == null) {
        _error('missing_field', '$type 图元缺少字段：$key。', '$path.$key');
        continue;
      }
      final point = _checkPoint(element[key], '$path.$key');
      if (point != null) points.add(point);
    }
    _addBounds(points);
    return points;
  }

  /// True when [raw] is a well-formed `[x, y]` point with at least one
  /// `$param`-bound component (as opposed to malformed, which already
  /// errors elsewhere).
  bool _isBoundPoint(dynamic raw) =>
      raw is List && raw.length == 2 && (raw[0] is Map || raw[1] is Map);

  /// Validates `constraints` (Phase 4): shape, references, then the
  /// geometric fact against literal coordinates.
  void _checkConstraints(dynamic raw) {
    if (raw == null) return;
    if (raw is! List) {
      _error('invalid_type', 'constraints 必须是数组。', 'constraints');
      return;
    }
    if (raw.length > visualMaxConstraints) {
      _error(
        'limit_exceeded',
        '约束数量超过 $visualMaxConstraints 个（共 ${raw.length} 个）。',
        'constraints',
      );
    }
    for (var i = 0; i < raw.length; i++) {
      _checkConstraint(raw[i], 'constraints[$i]');
    }
  }

  void _checkConstraint(dynamic raw, String path) {
    if (!_isMap(raw)) {
      _error('invalid_type', '约束必须是对象。', path);
      return;
    }
    final constraint = raw as Map<String, dynamic>;
    _checkUnknownFields(
      constraint,
      const {'type', 'a', 'b', 'point', 'circle', 'value'},
      '约束',
      path,
    );
    final typeRaw = constraint['type'];
    if (typeRaw == null) {
      _error('missing_field', '约束缺少字段：type。', '$path.type');
      return;
    }
    final type = typeRaw is String
        ? VisualConstraintType.fromDslName(typeRaw)
        : null;
    if (type == null) {
      _error('invalid_value', '未知的约束类型：$typeRaw。', '$path.type');
      return;
    }
    var shapeOk = true;
    String? idField(String key) {
      final value = constraint[key];
      if (value == null) return null;
      if (value is! String || value.isEmpty) {
        _error('invalid_type', '约束的 $key 必须是非空文字。', '$path.$key');
        // A present-but-malformed id must not reach the `a!` / `value!`
        // dereferences below: mark the shape invalid so the early return
        // after the `need(...)` checks skips evaluation.
        shapeOk = false;
        return null;
      }
      return value;
    }

    double? value;
    final rawValue = constraint['value'];
    if (rawValue != null) {
      if (rawValue is! num || !rawValue.toDouble().isFinite) {
        _error('invalid_type', '约束的 value 必须是有限数字。', '$path.value');
        shapeOk = false;
      } else {
        value = rawValue.toDouble();
      }
    }
    final a = idField('a');
    final b = idField('b');
    final point = idField('point');
    final circle = idField('circle');
    void need(String key, bool present) {
      if (!present) {
        _error('missing_field', '约束缺少字段：$key。', '$path.$key');
        shapeOk = false;
      }
    }

    switch (type) {
      case VisualConstraintType.distance:
        need('a', constraint['a'] != null);
        need('b', constraint['b'] != null);
        need('value', constraint['value'] != null);
        if (value != null && value < 0) {
          _error('invalid_range', 'distance 约束的 value 不能小于 0。', '$path.value');
          shapeOk = false;
        }
      case VisualConstraintType.parallel:
      case VisualConstraintType.perpendicular:
      case VisualConstraintType.intersect:
        need('a', constraint['a'] != null);
        need('b', constraint['b'] != null);
      case VisualConstraintType.onCircle:
        need('point', constraint['point'] != null);
        need('circle', constraint['circle'] != null);
      case VisualConstraintType.angle:
        need('a', constraint['a'] != null);
        need('b', constraint['b'] != null);
        need('value', constraint['value'] != null);
        if (value != null && (value < 0 || value > 180)) {
          _error(
            'invalid_range',
            'angle 约束的 value 必须在 0~180 度之间。',
            '$path.value',
          );
          shapeOk = false;
        }
      case VisualConstraintType.midpoint:
        need('point', constraint['point'] != null);
        need('a', constraint['a'] != null);
        need('b', constraint['b'] != null);
    }
    if (!shapeOk) return;

    // Resolve references and evaluate against literal coordinates.
    switch (type) {
      case VisualConstraintType.distance:
        final pa = _pointOf(a!, path);
        final pb = _pointOf(b!, path);
        if (pa == null || pb == null) return;
        final actual = _dist(pa, pb);
        if ((actual - value!).abs() > 1e-6 * math.max(1, value.abs())) {
          _violation('点 $a 与 $b 的距离是 ${_fmt(actual)}，不是 ${_fmt(value)}。', path);
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
        final len1 = math.sqrt(d1.$1 * d1.$1 + d1.$2 * d1.$2);
        final len2 = math.sqrt(d2.$1 * d2.$1 + d2.$2 * d2.$2);
        if (len1 == 0 || len2 == 0) {
          _error('invalid_value', '约束引用的线段退化为点，无法比较方向。', path);
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
              _violation('线段 $a 与 $b 不平行。', path);
            }
          case VisualConstraintType.perpendicular:
            if (dot.abs() > angleTolSin * len1 * len2) {
              _violation('线段 $a 与 $b 不垂直。', path);
            }
          case VisualConstraintType.angle:
            final cosA = (dot / (len1 * len2)).clamp(-1.0, 1.0);
            final degrees = math.acos(cosA) * 180 / math.pi;
            if ((degrees - value!).abs() > angleTolDeg) {
              _violation(
                '线段 $a 与 $b 的夹角是 ${_fmt(degrees)}°，不是 ${_fmt(value)}°。',
                path,
              );
            }
          case VisualConstraintType.intersect:
            if (!_segmentsIntersect(sa, sb)) {
              _violation('线段 $a 与 $b 不相交。', path);
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
        if ((actual - c.$2).abs() > 1e-6 * math.max(1, c.$2)) {
          _violation(
            '点 $point 不在圆 $circle 上（到圆心距离 ${_fmt(actual)}，半径 ${_fmt(c.$2)}）。',
            path,
          );
        }
      case VisualConstraintType.midpoint:
        final p = _pointOf(point!, path);
        final pa = _pointOf(a!, path);
        final pb = _pointOf(b!, path);
        if (p == null || pa == null || pb == null) return;
        final mid = ((pa.$1 + pb.$1) / 2, (pa.$2 + pb.$2) / 2);
        if ((p.$1 - mid.$1).abs() > 1e-6 || (p.$2 - mid.$2).abs() > 1e-6) {
          _violation('点 $point 不是 $a 与 $b 的中点。', path);
        }
    }
  }

  /// A violated constraint is an error for an exact construction, and a
  /// warning when the scene declares itself a schematic.
  void _violation(String message, String path) {
    if (_schematic) {
      _warning('schematic_constraint', '示意图未按比例：$message', path);
    } else {
      _error('constraint_violated', message, path);
    }
  }

  /// Literal position of a `point` element, or null (with an issue
  /// recorded) when the id is unknown, not a point, or `$param`-bound.
  (double, double)? _pointOf(String id, String path) {
    final type = _elementTypesById[id];
    if (type == null) {
      _error('unknown_element', '约束引用了不存在的图元：$id。', path);
      return null;
    }
    if (type != 'point') {
      _error('invalid_value', '约束引用了非 point 图元：$id 是 $type。', path);
      return null;
    }
    if (_boundPointIds.contains(id)) {
      _warning('constraint_unverifiable', '约束引用的点 $id 绑定了参数，无法静态检查。', path);
      return null;
    }
    return _pointPositions[id];
  }

  /// Literal endpoints of a `line`/`arrow` element, or null (with an
  /// issue recorded) when the id is unknown, not a segment, or bound.
  ((double, double), (double, double))? _segmentOf(String id, String path) {
    final type = _elementTypesById[id];
    if (type == null) {
      _error('unknown_element', '约束引用了不存在的图元：$id。', path);
      return null;
    }
    if (type != 'line' && type != 'arrow') {
      _error('invalid_value', '约束引用了非线段图元：$id 是 $type。', path);
      return null;
    }
    if (_boundSegmentIds.contains(id)) {
      _warning('constraint_unverifiable', '约束引用的线段 $id 绑定了参数，无法静态检查。', path);
      return null;
    }
    return _lineSegments[id];
  }

  /// Literal center and radius of a `circle` element, or null (with an
  /// issue recorded) when the id is unknown, not a circle, or bound.
  ((double, double), double)? _circleOf(String id, String path) {
    final type = _elementTypesById[id];
    if (type == null) {
      _error('unknown_element', '约束引用了不存在的图元：$id。', path);
      return null;
    }
    if (type != 'circle') {
      _error('invalid_value', '约束引用了非 circle 图元：$id 是 $type。', path);
      return null;
    }
    if (_boundCircleIds.contains(id)) {
      _warning('constraint_unverifiable', '约束引用的圆 $id 绑定了参数，无法静态检查。', path);
      return null;
    }
    return _circles[id];
  }

  static double _dist((double, double) a, (double, double) b) =>
      math.sqrt((a.$1 - b.$1) * (a.$1 - b.$1) + (a.$2 - b.$2) * (a.$2 - b.$2));

  static String _fmt(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(4);

  /// Validates a `text`/`math_label` element: anchor point + non-empty
  /// text of at most 500 characters.
  void _checkLabeledPoint(
    Map<String, dynamic> element,
    String path,
    String type,
    String textKey,
  ) {
    final at = _checkPoint(element['at'], '$path.at');
    if (at != null) {
      _literalBounds.add((at.$1, at.$2, at.$1, at.$2));
    } else if (element['at'] == null) {
      _error('missing_field', '$type 图元缺少字段：at。', '$path.at');
    }
    final text = element[textKey];
    if (text == null) {
      _error('missing_field', '$type 图元缺少字段：$textKey。', '$path.$textKey');
    } else if (text is! String) {
      _error('invalid_type', '$type 图元的 $textKey 必须是文字。', '$path.$textKey');
    } else if (text.isEmpty) {
      _error('invalid_value', '$type 图元的 $textKey 不能为空。', '$path.$textKey');
    } else if (text.length > 500) {
      _error(
        'invalid_value',
        '$type 图元的 $textKey 不能超过 500 个字符。',
        '$path.$textKey',
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
      _error('missing_field', '$type 图元缺少字段：points。', path);
      return const [];
    }
    if (raw is! List) {
      _error('invalid_type', '$type 图元的 points 必须是数组。', path);
      return const [];
    }
    if (raw.length < minLength) {
      _error('invalid_value', '$type 图元至少需要 $minLength 个点。', path);
    }
    final points = <(double, double)>[];
    for (var i = 0; i < raw.length; i++) {
      final point = _checkPoint(raw[i], '$path[$i]');
      if (point != null) points.add(point);
    }
    return points;
  }

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

  void _checkControls(dynamic raw) {
    if (raw == null) return;
    if (raw is! List) {
      _error('invalid_type', 'controls 必须是数组。', 'controls');
      return;
    }
    if (raw.length > visualMaxControls) {
      _error(
        'limit_exceeded',
        '控件数量超过 $visualMaxControls 个（共 ${raw.length} 个）。',
        'controls',
      );
    }
    for (var i = 0; i < raw.length; i++) {
      _checkControl(raw[i], 'controls[$i]');
    }
  }

  void _checkControl(dynamic raw, String path) {
    if (!_isMap(raw)) {
      _error('invalid_type', '控件必须是对象。', path);
      return;
    }
    final control = raw as Map<String, dynamic>;
    final kind = control['kind'];
    const perKind = {
      'slider': {'min', 'max', 'step', 'value'},
      'toggle': {'value'},
      'choice': {'options', 'value'},
    };
    if (kind is! String) {
      _error('missing_field', '控件缺少字段：kind。', '$path.kind');
      _checkUnknownFields(control, const {'id', 'kind', 'label'}, '控件', path);
      return;
    }
    if (!perKind.containsKey(kind)) {
      _error('invalid_value', '未知的控件类型：$kind。', '$path.kind');
      _checkUnknownFields(control, const {'id', 'kind', 'label'}, '控件', path);
      return;
    }
    _checkUnknownFields(
      control,
      {'id', 'kind', 'label', ...perKind[kind]!},
      '$kind 控件',
      path,
    );
    final id = control['id'];
    if (id == null) {
      _error('missing_field', '控件缺少字段：id。', '$path.id');
    } else if (id is! String || id.isEmpty) {
      _error('invalid_type', '控件的 id 必须是非空文字。', '$path.id');
    } else if (_controlKinds.containsKey(id)) {
      _error('duplicate_id', '控件 id 重复：$id。', '$path.id');
    } else {
      _controlKinds[id] = kind;
    }
    final label = control['label'];
    if (label == null) {
      _error('missing_field', '控件缺少字段：label。', '$path.label');
    } else if (label is! String || label.isEmpty) {
      _error('invalid_type', '控件的 label 必须是非空文字。', '$path.label');
    }
    switch (kind) {
      case 'slider':
        final min = _finiteNumber(control['min'], '$path.min', 'slider 的 min');
        final max = _finiteNumber(control['max'], '$path.max', 'slider 的 max');
        final step = _finiteNumber(
          control['step'],
          '$path.step',
          'slider 的 step',
        );
        final value = _finiteNumber(
          control['value'],
          '$path.value',
          'slider 的 value',
        );
        if (control['min'] == null) {
          _error('missing_field', 'slider 控件缺少字段：min。', '$path.min');
        }
        if (control['max'] == null) {
          _error('missing_field', 'slider 控件缺少字段：max。', '$path.max');
        }
        if (control['step'] == null) {
          _error('missing_field', 'slider 控件缺少字段：step。', '$path.step');
        }
        if (control['value'] == null) {
          _error('missing_field', 'slider 控件缺少字段：value。', '$path.value');
        }
        if (min != null && max != null && min >= max) {
          _error('invalid_range', 'slider 的 min 必须小于 max。', path);
        }
        if (step != null && step <= 0) {
          _error('invalid_range', 'slider 的 step 必须大于 0。', '$path.step');
        }
        if (min != null &&
            max != null &&
            value != null &&
            (value < min || value > max)) {
          _error(
            'invalid_range',
            'slider 的 value 必须在 [min, max] 之间。',
            '$path.value',
          );
        }
        // A slider id must match a model.parameters key.
        if (id is String && id.isNotEmpty && !_parameters.contains(id)) {
          _error(
            'unknown_parameter',
            'slider 控件 $id 没有对应的 model.parameters 参数。',
            '$path.id',
          );
        }
      case 'toggle':
        if (control['value'] == null) {
          _error('missing_field', 'toggle 控件缺少字段：value。', '$path.value');
        } else if (control['value'] is! bool) {
          _error('invalid_type', 'toggle 控件的 value 必须是布尔值。', '$path.value');
        }
      case 'choice':
        final options = control['options'];
        if (options == null) {
          _error('missing_field', 'choice 控件缺少字段：options。', '$path.options');
        } else if (options is! List ||
            options.isEmpty ||
            options.any((o) => o is! String)) {
          _error(
            'invalid_type',
            'choice 控件的 options 必须是非空文字数组。',
            '$path.options',
          );
        }
        final value = control['value'];
        if (value == null) {
          _error('missing_field', 'choice 控件缺少字段：value。', '$path.value');
        } else if (value is! String) {
          _error('invalid_type', 'choice 控件的 value 必须是文字。', '$path.value');
        } else if (options is List &&
            options.every((o) => o is String) &&
            !options.contains(value)) {
          _error(
            'invalid_value',
            'choice 控件的 value 必须是 options 中的一项。',
            '$path.value',
          );
        }
    }
  }

  void _checkTimeline(dynamic raw) {
    if (raw == null) return;
    if (!_isMap(raw)) {
      _error('invalid_type', 'timeline 必须是对象。', 'timeline');
      return;
    }
    final timeline = raw as Map<String, dynamic>;
    _checkUnknownFields(
      timeline,
      const {'durationMs', 'tracks', 'steps'},
      'timeline',
      'timeline',
    );
    final durationMs = timeline['durationMs'];
    if (durationMs == null) {
      _error(
        'missing_field',
        'timeline 缺少字段：durationMs。',
        'timeline.durationMs',
      );
      return;
    }
    if (durationMs is! int || durationMs <= 0) {
      _error(
        'invalid_range',
        'timeline 的 durationMs 必须是正整数。',
        'timeline.durationMs',
      );
      return;
    }
    if (timeline['tracks'] != null) {
      final tracks = timeline['tracks'];
      if (tracks is! List) {
        _error('invalid_type', 'timeline 的 tracks 必须是数组。', 'timeline.tracks');
      } else {
        if (tracks.length > visualMaxTracks) {
          _error(
            'limit_exceeded',
            '动画轨道数量超过 $visualMaxTracks 条（共 ${tracks.length} 条）。',
            'timeline.tracks',
          );
        }
        final trackIds = <String>{};
        for (var i = 0; i < tracks.length; i++) {
          _checkTrack(tracks[i], 'timeline.tracks[$i]', durationMs, trackIds);
        }
      }
    }
    if (timeline['steps'] != null) {
      final steps = timeline['steps'];
      if (steps is! List) {
        _error('invalid_type', 'timeline 的 steps 必须是数组。', 'timeline.steps');
      } else {
        if (steps.length > visualMaxSteps) {
          _error(
            'limit_exceeded',
            '教学步骤数量超过 $visualMaxSteps 步（共 ${steps.length} 步）。',
            'timeline.steps',
          );
        }
        int? previousAtMs;
        for (var i = 0; i < steps.length; i++) {
          final atMs = _checkStep(steps[i], 'timeline.steps[$i]', durationMs);
          if (atMs != null) {
            if (previousAtMs != null && atMs < previousAtMs) {
              _warning(
                'steps_out_of_order',
                '教学步骤没有按 atMs 排序。',
                'timeline.steps[$i].atMs',
              );
            }
            previousAtMs = atMs;
          }
        }
      }
    }
  }

  void _checkTrack(
    dynamic raw,
    String path,
    int durationMs,
    Set<String> trackIds,
  ) {
    if (!_isMap(raw)) {
      _error('invalid_type', 'track 必须是对象。', path);
      return;
    }
    final track = raw as Map<String, dynamic>;
    _checkUnknownFields(
      track,
      const {'id', 'target', 'from', 'to', 'startMs', 'endMs'},
      'track',
      path,
    );
    final id = track['id'];
    if (id == null) {
      _error('missing_field', 'track 缺少字段：id。', '$path.id');
    } else if (id is! String || id.isEmpty) {
      _error('invalid_type', 'track 的 id 必须是非空文字。', '$path.id');
    } else if (!trackIds.add(id)) {
      _error('duplicate_id', 'track id 重复：$id。', '$path.id');
    }
    final target = track['target'];
    if (target == null) {
      _error('missing_field', 'track 缺少字段：target。', '$path.target');
    } else if (target is! String || target.isEmpty) {
      _error('invalid_type', 'track 的 target 必须是非空文字。', '$path.target');
    } else if (_controlKinds[target] != 'slider') {
      _error(
        'invalid_track_target',
        'track 的 target 必须是 slider 控件：$target。',
        '$path.target',
      );
    }
    _finiteNumber(track['from'], '$path.from', 'track 的 from');
    _finiteNumber(track['to'], '$path.to', 'track 的 to');
    if (track['from'] == null) {
      _error('missing_field', 'track 缺少字段：from。', '$path.from');
    }
    if (track['to'] == null) {
      _error('missing_field', 'track 缺少字段：to。', '$path.to');
    }
    final startMs = track['startMs'];
    final endMs = track['endMs'];
    if (startMs == null) {
      _error('missing_field', 'track 缺少字段：startMs。', '$path.startMs');
    } else if (startMs is! int || startMs < 0 || startMs > durationMs) {
      _error(
        'invalid_range',
        'track 的 startMs 必须在 [0, durationMs] 之间。',
        '$path.startMs',
      );
    }
    if (endMs == null) {
      _error('missing_field', 'track 缺少字段：endMs。', '$path.endMs');
    } else if (endMs is! int || endMs < 0 || endMs > durationMs) {
      _error(
        'invalid_range',
        'track 的 endMs 必须在 [0, durationMs] 之间。',
        '$path.endMs',
      );
    }
    if (startMs is int && endMs is int && startMs >= endMs) {
      _error('invalid_range', 'track 的 startMs 必须小于 endMs。', path);
    }
  }

  /// Validates one teaching step; returns its `atMs` when valid.
  int? _checkStep(dynamic raw, String path, int durationMs) {
    if (!_isMap(raw)) {
      _error('invalid_type', 'step 必须是对象。', path);
      return null;
    }
    final step = raw as Map<String, dynamic>;
    _checkUnknownFields(
      step,
      const {'atMs', 'show', 'hide', 'note'},
      'step',
      path,
    );
    final atMsRaw = step['atMs'];
    int? atMs;
    if (atMsRaw == null) {
      _error('missing_field', 'step 缺少字段：atMs。', '$path.atMs');
    } else if (atMsRaw is! int || atMsRaw < 0 || atMsRaw > durationMs) {
      _error(
        'invalid_range',
        'step 的 atMs 必须在 [0, durationMs] 之间。',
        '$path.atMs',
      );
    } else {
      atMs = atMsRaw;
    }
    for (final key in ['show', 'hide']) {
      final list = step[key];
      if (list == null) continue;
      if (list is! List || list.any((v) => v is! String)) {
        _error('invalid_type', 'step 的 $key 必须是文字数组。', '$path.$key');
        continue;
      }
      for (final id in list.cast<String>()) {
        if (!_elementIds.contains(id)) {
          _error(
            'unknown_element_reference',
            'step 的 $key 引用了不存在的图元：$id。',
            '$path.$key',
          );
        }
      }
    }
    if (step['note'] != null && step['note'] is! String) {
      _error('invalid_type', 'step 的 note 必须是文字。', '$path.note');
    }
    return atMs;
  }

  void _checkAnnotations(dynamic raw) {
    if (raw == null) return;
    if (raw is! List) {
      _error('invalid_type', 'annotations 必须是数组。', 'annotations');
      return;
    }
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      final path = 'annotations[$i]';
      if (!_isMap(item)) {
        _error('invalid_type', '标注必须是对象。', path);
        continue;
      }
      final annotation = item as Map<String, dynamic>;
      _checkUnknownFields(annotation, const {'at', 'text'}, '标注', path);
      if (annotation['at'] == null) {
        _error('missing_field', '标注缺少字段：at。', '$path.at');
      } else {
        _checkPoint(annotation['at'], '$path.at');
      }
      final text = annotation['text'];
      if (text == null) {
        _error('missing_field', '标注缺少字段：text。', '$path.text');
      } else if (text is! String || text.isEmpty) {
        _error('invalid_type', '标注的 text 必须是非空文字。', '$path.text');
      }
    }
  }

  void _checkMeta(dynamic raw) {
    if (raw == null) return;
    if (!_isMap(raw)) {
      _error('invalid_type', 'meta 必须是对象。', 'meta');
      return;
    }
    final meta = raw as Map<String, dynamic>;
    _checkUnknownFields(meta, const {'alt', 'schematic'}, 'meta', 'meta');
    if (meta['alt'] != null && meta['alt'] is! String) {
      _error('invalid_type', 'meta 的 alt 必须是文字。', 'meta.alt');
    }
    if (meta['schematic'] != null && meta['schematic'] is! bool) {
      _error('invalid_type', 'meta 的 schematic 必须是布尔值。', 'meta.schematic');
    }
  }

  // -------------------------------------------------------------------------
  // Warnings
  // -------------------------------------------------------------------------

  void _checkWarnings(Map<String, dynamic> json) {
    // Accessibility text.
    final title = json['title'];
    final meta = json['meta'];
    final alt = _isMap(meta) ? (meta as Map<String, dynamic>)['alt'] : null;
    final hasTitle = title is String && title.trim().isNotEmpty;
    final hasAlt = alt is String && alt.trim().isNotEmpty;
    if (!hasTitle && !hasAlt) {
      _warning('missing_accessibility_text', '场景没有标题也没有替代说明（meta.alt）。');
    }

    // Declared schematic content.
    if (_isMap(meta) && (meta as Map<String, dynamic>)['schematic'] == true) {
      _warning(
        'schematic_content',
        '场景声明为示意图（meta.schematic），内容不按严格比例验证。',
        'meta.schematic',
      );
    }

    // View vs content bounds.
    final view = json['view'];
    if (_isMap(view) && _literalBounds.isNotEmpty) {
      final viewMap = view as Map<String, dynamic>;
      var minX = _literalBounds.first.$1;
      var minY = _literalBounds.first.$2;
      var maxX = _literalBounds.first.$3;
      var maxY = _literalBounds.first.$4;
      for (final b in _literalBounds) {
        if (b.$1 < minX) minX = b.$1;
        if (b.$2 < minY) minY = b.$2;
        if (b.$3 > maxX) maxX = b.$3;
        if (b.$4 > maxY) maxY = b.$4;
      }
      // A view range more than 5x the content span on either axis usually
      // means the author picked a range far larger than the drawing.
      const factor = 5.0;
      final viewX = _readRange(viewMap['x']);
      final viewY = _readRange(viewMap['y']);
      final contentSpanX = maxX - minX;
      final contentSpanY = maxY - minY;
      if (viewX != null &&
          contentSpanX > 0 &&
          viewX.$2 - viewX.$1 > contentSpanX * factor) {
        _warning(
          'view_much_larger_than_content',
          'view.x 的范围远大于图形内容。',
          'view.x',
        );
      }
      if (viewY != null &&
          contentSpanY > 0 &&
          viewY.$2 - viewY.$1 > contentSpanY * factor) {
        _warning(
          'view_much_larger_than_content',
          'view.y 的范围远大于图形内容。',
          'view.y',
        );
      }
      // Elements entirely outside the view.
      if (viewX != null && viewY != null) {
        for (final b in _literalBounds) {
          if (b.$3 < viewX.$1 ||
              b.$1 > viewX.$2 ||
              b.$4 < viewY.$1 ||
              b.$2 > viewY.$2) {
            _warning('element_outside_view', '有图元完全位于 view 范围之外。');
            break;
          }
        }
      }
    }
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
