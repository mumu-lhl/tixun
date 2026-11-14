/// Element types for TiXun Visual DSL v1.
///
/// Every element carries the common fields `id`, `type`, `style`, `layer`,
/// `visible` and the optional `visibleWhen` gate. Coordinates are either
/// plain numbers or `{"$param": "<name>"}` bindings (see [VisualCoord]).
/// `fromJson` rejects unknown fields at every level, mirroring
/// `QuestionSpec.fromJson`.
library;

import 'package:tixun/core/l10n/app_error.dart';

/// Maximum nesting depth of `group` elements (a lone group is depth 1).
const visualMaxGroupDepth = 4;

/// Semantic style names; the renderer maps them to theme colors.
enum VisualStyle { primary, highlight, muted, success, danger }

VisualStyle _styleFromName(String name, String path) {
  for (final style in VisualStyle.values) {
    if (style.name == name) return style;
  }
  throw AppFormatException(
    AppErrorCode.errorInvalidParameterType,
    '未知的样式：$name。',
    [path],
  );
}

/// Throws [AppFormatException] if [json] contains a key outside [allowed].
void checkNoUnknownFields(
  Map<String, dynamic> json,
  Set<String> allowed,
  String what,
) {
  for (final key in json.keys) {
    if (!allowed.contains(key)) {
      throw AppFormatException(
        AppErrorCode.errorUnknownParameter,
        '$what 包含未知字段：$key。',
        [key],
      );
    }
  }
}

String _reqString(Map<String, dynamic> json, String key, String what) {
  final value = json[key];
  if (value == null) {
    throw AppFormatException(
      AppErrorCode.errorMissingParameter,
      '$what 缺少字段：$key。',
      [key],
    );
  }
  if (value is! String) {
    throw AppFormatException(
      AppErrorCode.errorParameterMustBeText,
      '$what 的 $key 必须是文字。',
      [key],
    );
  }
  return value;
}

double _reqNumber(Map<String, dynamic> json, String key, String what) {
  final value = json[key];
  if (value == null) {
    throw AppFormatException(
      AppErrorCode.errorMissingParameter,
      '$what 缺少字段：$key。',
      [key],
    );
  }
  if (value is! num || !value.toDouble().isFinite) {
    throw AppFormatException(
      AppErrorCode.errorParameterMustBeNumber,
      '$what 的 $key 必须是有限数字。',
      [key],
    );
  }
  return value.toDouble();
}

/// A single coordinate component: a literal number or a
/// `{"$param": "<name>"}` binding to a model parameter / slider control.
class VisualCoord {
  const VisualCoord.literal(this.value) : param = null;

  const VisualCoord.param(this.param) : value = null;

  /// Literal numeric value, or null when this coordinate is a binding.
  final double? value;

  /// Bound parameter name, or null for a literal coordinate.
  final String? param;

  bool get isParam => param != null;

  /// The literal value, or null for a bound coordinate.
  double? get literalValue => value;

  factory VisualCoord.fromJson(dynamic json) {
    if (json is num) {
      final value = json.toDouble();
      if (!value.isFinite) {
        throw const AppFormatException(
          AppErrorCode.errorParameterMustBeNumber,
          '坐标必须是有限数字。',
        );
      }
      return VisualCoord.literal(value);
    }
    if (json is Map<String, dynamic>) {
      checkNoUnknownFields(json, const {'\$param'}, '坐标绑定');
      final name = json[r'$param'];
      if (name == null) {
        throw const AppFormatException(
          AppErrorCode.errorMissingParameter,
          r'坐标绑定缺少字段：$param。',
        );
      }
      if (name is! String || name.isEmpty) {
        throw const AppFormatException(
          AppErrorCode.errorParameterMustBeText,
          r'坐标绑定的 $param 必须是非空文字。',
        );
      }
      return VisualCoord.param(name);
    }
    throw const AppFormatException(
      AppErrorCode.errorParameterMustBeNumber,
      '坐标必须是数字或参数绑定。',
    );
  }

  dynamic toJson() => isParam ? {'\$param': param} : value;

  @override
  bool operator ==(Object other) =>
      other is VisualCoord && value == other.value && param == other.param;

  @override
  int get hashCode => Object.hash(value, param);
}

/// A 2D point in model coordinates.
class VisualPoint {
  const VisualPoint(this.x, this.y);

  final VisualCoord x;
  final VisualCoord y;

  /// True when both components are literals.
  bool get isLiteral => !x.isParam && !y.isParam;

  /// Literal (x, y), or null when either component is a binding.
  (double, double)? get literal => isLiteral ? (x.value!, y.value!) : null;

  factory VisualPoint.fromJson(dynamic json) {
    if (json is! List || json.length != 2) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '坐标点必须是 [x, y] 形式的数组。',
        ['point'],
      );
    }
    return VisualPoint(
      VisualCoord.fromJson(json[0]),
      VisualCoord.fromJson(json[1]),
    );
  }

  List<dynamic> toJson() => [x.toJson(), y.toJson()];

  @override
  bool operator ==(Object other) =>
      other is VisualPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Gates an element on a toggle control: the element is shown only when the
/// control's value equals [equals].
class VisualVisibilityGate {
  const VisualVisibilityGate({required this.control, required this.equals});

  final String control;
  final bool equals;

  factory VisualVisibilityGate.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {'control', 'equals'}, 'visibleWhen');
    return VisualVisibilityGate(
      control: _reqString(json, 'control', 'visibleWhen'),
      equals: json['equals'] is bool
          ? json['equals'] as bool
          : throw const AppFormatException(
              AppErrorCode.errorInvalidParameterType,
              'visibleWhen 的 equals 必须是布尔值。',
              ['equals'],
            ),
    );
  }

  Map<String, dynamic> toJson() => {'control': control, 'equals': equals};

  @override
  bool operator ==(Object other) =>
      other is VisualVisibilityGate &&
      control == other.control &&
      equals == other.equals;

  @override
  int get hashCode => Object.hash(control, equals);
}

const _commonFields = {
  'id',
  'type',
  'style',
  'layer',
  'visible',
  'visibleWhen',
};

/// Parsed common fields shared by all element types.
({
  String id,
  VisualStyle style,
  int layer,
  bool visible,
  VisualVisibilityGate? visibleWhen,
})
_parseCommonFields(Map<String, dynamic> json) {
  final id = _reqString(json, 'id', '图元');
  if (id.isEmpty) {
    throw const AppFormatException(
      AppErrorCode.errorInvalidParameterType,
      '图元 id 不能为空。',
      ['id'],
    );
  }
  var style = VisualStyle.primary;
  if (json['style'] != null) {
    final raw = json['style'];
    if (raw is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        '图元的 style 必须是文字。',
      );
    }
    style = _styleFromName(raw, 'style');
  }
  var layer = 0;
  if (json['layer'] != null) {
    final raw = json['layer'];
    if (raw is! int) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeNumber,
        '图元的 layer 必须是整数。',
      );
    }
    layer = raw;
  }
  var visible = true;
  if (json['visible'] != null) {
    final raw = json['visible'];
    if (raw is! bool) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '图元的 visible 必须是布尔值。',
        ['visible'],
      );
    }
    visible = raw;
  }
  VisualVisibilityGate? visibleWhen;
  if (json['visibleWhen'] != null) {
    final raw = json['visibleWhen'];
    if (raw is! Map<String, dynamic>) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '图元的 visibleWhen 必须是对象。',
        ['visibleWhen'],
      );
    }
    visibleWhen = VisualVisibilityGate.fromJson(raw);
  }
  return (
    id: id,
    style: style,
    layer: layer,
    visible: visible,
    visibleWhen: visibleWhen,
  );
}

Map<String, dynamic> _commonToJson(VisualElement element) => {
  'id': element.id,
  'type': element.type,
  'style': element.style.name,
  'layer': element.layer,
  'visible': element.visible,
  if (element.visibleWhen != null) 'visibleWhen': element.visibleWhen!.toJson(),
};

/// Base type for all DSL v1 elements.
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
    final type = _reqString(json, 'type', '图元');
    switch (type) {
      case 'point':
        checkNoUnknownFields(json, {
          ..._commonFields,
          'at',
          'label',
          'draggable',
        }, 'point 图元');
        final c = _parseCommonFields(json);
        final at = json['at'];
        if (at == null) {
          throw const AppFormatException(
            AppErrorCode.errorMissingParameter,
            'point 图元缺少字段：at。',
          );
        }
        return PointElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          at: VisualPoint.fromJson(at),
          draggable: _optBool(json, 'draggable', 'point 图元'),
          label: switch (json['label']) {
            null => null,
            final String s => s,
            _ => throw const AppFormatException(
              AppErrorCode.errorParameterMustBeText,
              'point 图元的 label 必须是文字。',
            ),
          },
        );
      case 'line':
        checkNoUnknownFields(json, {
          ..._commonFields,
          'p1',
          'p2',
          'dashed',
        }, 'line 图元');
        final c = _parseCommonFields(json);
        return LineElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          p1: VisualPoint.fromJson(json['p1']),
          p2: VisualPoint.fromJson(json['p2']),
          dashed: _optBool(json, 'dashed', 'line 图元'),
        );
      case 'polyline':
        checkNoUnknownFields(json, {..._commonFields, 'points'}, 'polyline 图元');
        final c = _parseCommonFields(json);
        return PolylineElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          points: _parsePoints(json['points'], 'polyline'),
        );
      case 'polygon':
        checkNoUnknownFields(json, {
          ..._commonFields,
          'points',
          'fill',
        }, 'polygon 图元');
        final c = _parseCommonFields(json);
        return PolygonElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          points: _parsePoints(json['points'], 'polygon'),
          fill: _optBool(json, 'fill', 'polygon 图元'),
        );
      case 'circle':
        checkNoUnknownFields(json, {
          ..._commonFields,
          'center',
          'r',
        }, 'circle 图元');
        final c = _parseCommonFields(json);
        return CircleElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          center: VisualPoint.fromJson(json['center']),
          r: _reqNumber(json, 'r', 'circle 图元'),
        );
      case 'arc':
        checkNoUnknownFields(json, {
          ..._commonFields,
          'center',
          'r',
          'startDeg',
          'sweepDeg',
        }, 'arc 图元');
        final c = _parseCommonFields(json);
        return ArcElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          center: VisualPoint.fromJson(json['center']),
          r: _reqNumber(json, 'r', 'arc 图元'),
          startDeg: _reqNumber(json, 'startDeg', 'arc 图元'),
          sweepDeg: _reqNumber(json, 'sweepDeg', 'arc 图元'),
        );
      case 'arrow':
        checkNoUnknownFields(json, {
          ..._commonFields,
          'from',
          'to',
        }, 'arrow 图元');
        final c = _parseCommonFields(json);
        return ArrowElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          from: VisualPoint.fromJson(json['from']),
          to: VisualPoint.fromJson(json['to']),
        );
      case 'text':
        checkNoUnknownFields(json, {..._commonFields, 'at', 'text'}, 'text 图元');
        final c = _parseCommonFields(json);
        return TextElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          at: VisualPoint.fromJson(json['at']),
          text: _reqString(json, 'text', 'text 图元'),
        );
      case 'math_label':
        checkNoUnknownFields(json, {
          ..._commonFields,
          'at',
          'tex',
        }, 'math_label 图元');
        final c = _parseCommonFields(json);
        return MathLabelElement(
          id: c.id,
          style: c.style,
          layer: c.layer,
          visible: c.visible,
          visibleWhen: c.visibleWhen,
          at: VisualPoint.fromJson(json['at']),
          tex: _reqString(json, 'tex', 'math_label 图元'),
        );
      case 'group':
        checkNoUnknownFields(json, {..._commonFields, 'children'}, 'group 图元');
        if (groupDepth >= visualMaxGroupDepth) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            'group 嵌套过深（最多 $visualMaxGroupDepth 层）。',
            ['children'],
          );
        }
        final c = _parseCommonFields(json);
        final rawChildren = json['children'];
        if (rawChildren is! List) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            'group 图元的 children 必须是数组。',
            ['children'],
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
                'group 的子图元必须是对象。',
                ['children'],
              );
            }
            return VisualElement.fromJson(child, groupDepth: groupDepth + 1);
          }).toList(),
        );
      case 'plot':
        checkNoUnknownFields(json, {
          ..._commonFields,
          'expression',
          'domain',
          'samples',
        }, 'plot 图元');
        final c = _parseCommonFields(json);
        (double, double)? domain;
        if (json['domain'] != null) {
          final raw = json['domain'];
          if (raw is! List || raw.length != 2) {
            throw const AppFormatException(
              AppErrorCode.errorInvalidParameterType,
              'plot 图元的 domain 必须是 [min, max] 形式的数组。',
              ['domain'],
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
              'plot 图元的 domain 必须是有限数字。',
            );
          }
          domain = (min.toDouble(), max.toDouble());
        }
        int? samples;
        if (json['samples'] != null) {
          final raw = json['samples'];
          if (raw is! int) {
            throw const AppFormatException(
              AppErrorCode.errorParameterMustBeNumber,
              'plot 图元的 samples 必须是整数。',
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
          expression: _reqString(json, 'expression', 'plot 图元'),
          domain: domain,
          samples: samples,
        );
      case 'circuit':
        checkNoUnknownFields(json, {
          ..._commonFields,
          'component',
          'from',
          'to',
          'at',
          'closed',
          'meter',
          'label',
        }, 'circuit 图元');
        final c = _parseCommonFields(json);
        final componentRaw = json['component'];
        if (componentRaw == null) {
          throw const AppFormatException(
            AppErrorCode.errorMissingParameter,
            'circuit 图元缺少字段：component。',
          );
        }
        final component = CircuitComponent.values.where(
          (v) => v.dslName == componentRaw,
        );
        if (component.isEmpty) {
          throw AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            'circuit 图元的 component 未知：$componentRaw。',
            [componentRaw.toString()],
          );
        }
        final comp = component.first;
        VisualPoint? from;
        VisualPoint? to;
        VisualPoint? at;
        CircuitMeterKind? meter;
        if (comp == CircuitComponent.meter) {
          at = VisualPoint.fromJson(json['at']);
          final meterRaw = json['meter'];
          if (meterRaw == null) {
            throw const AppFormatException(
              AppErrorCode.errorMissingParameter,
              'meter 图元缺少字段：meter。',
            );
          }
          final kinds = CircuitMeterKind.values.where(
            (v) => v.name == meterRaw,
          );
          if (kinds.isEmpty) {
            throw AppFormatException(
              AppErrorCode.errorInvalidParameterType,
              'meter 图元的 meter 未知：$meterRaw。',
              [meterRaw.toString()],
            );
          }
          meter = kinds.first;
        } else {
          from = VisualPoint.fromJson(json['from']);
          to = VisualPoint.fromJson(json['to']);
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
          closed: _optBool(json, 'closed', 'circuit 图元'),
          meter: meter,
          label: switch (json['label']) {
            null => null,
            final String s => s,
            _ => throw const AppFormatException(
              AppErrorCode.errorParameterMustBeText,
              'circuit 图元的 label 必须是文字。',
            ),
          },
        );
      default:
        throw AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          '未知的图元类型：$type。',
          [type],
        );
    }
  }
}

List<VisualPoint> _parsePoints(dynamic raw, String what) {
  if (raw is! List) {
    throw AppFormatException(
      AppErrorCode.errorInvalidParameterType,
      '$what 图元的 points 必须是数组。',
      ['points'],
    );
  }
  return raw.map((p) => VisualPoint.fromJson(p)).toList();
}

bool _optBool(Map<String, dynamic> json, String key, String what) {
  final value = json[key];
  if (value == null) return false;
  if (value is! bool) {
    throw AppFormatException(
      AppErrorCode.errorInvalidParameterType,
      '$what 的 $key 必须是布尔值。',
      [key],
    );
  }
  return value;
}

class PointElement extends VisualElement {
  const PointElement({
    required super.id,
    required super.style,
    required super.layer,
    required super.visible,
    super.visibleWhen,
    required this.at,
    this.draggable = false,
    this.label,
  });

  final VisualPoint at;

  /// True when the user may drag this point in the fullscreen view.
  /// Only literal-coordinate points are draggable; a `$param`-bound
  /// point with `draggable: true` is rejected by the validator.
  final bool draggable;

  final String? label;

  @override
  String get type => 'point';

  @override
  Map<String, dynamic> toJson() => {
    ..._commonToJson(this),
    'at': at.toJson(),
    if (draggable) 'draggable': true,
    if (label != null) 'label': label,
  };
}

class LineElement extends VisualElement {
  const LineElement({
    required super.id,
    required super.style,
    required super.layer,
    required super.visible,
    super.visibleWhen,
    required this.p1,
    required this.p2,
    this.dashed = false,
  });

  final VisualPoint p1;
  final VisualPoint p2;
  final bool dashed;

  @override
  String get type => 'line';

  @override
  Map<String, dynamic> toJson() => {
    ..._commonToJson(this),
    'p1': p1.toJson(),
    'p2': p2.toJson(),
    if (dashed) 'dashed': true,
  };
}

class PolylineElement extends VisualElement {
  const PolylineElement({
    required super.id,
    required super.style,
    required super.layer,
    required super.visible,
    super.visibleWhen,
    required this.points,
  });

  final List<VisualPoint> points;

  @override
  String get type => 'polyline';

  @override
  Map<String, dynamic> toJson() => {
    ..._commonToJson(this),
    'points': points.map((p) => p.toJson()).toList(),
  };
}

class PolygonElement extends VisualElement {
  const PolygonElement({
    required super.id,
    required super.style,
    required super.layer,
    required super.visible,
    super.visibleWhen,
    required this.points,
    this.fill = false,
  });

  final List<VisualPoint> points;
  final bool fill;

  @override
  String get type => 'polygon';

  @override
  Map<String, dynamic> toJson() => {
    ..._commonToJson(this),
    'points': points.map((p) => p.toJson()).toList(),
    if (fill) 'fill': true,
  };
}

class CircleElement extends VisualElement {
  const CircleElement({
    required super.id,
    required super.style,
    required super.layer,
    required super.visible,
    super.visibleWhen,
    required this.center,
    required this.r,
  });

  final VisualPoint center;
  final double r;

  @override
  String get type => 'circle';

  @override
  Map<String, dynamic> toJson() => {
    ..._commonToJson(this),
    'center': center.toJson(),
    'r': r,
  };
}

class ArcElement extends VisualElement {
  const ArcElement({
    required super.id,
    required super.style,
    required super.layer,
    required super.visible,
    super.visibleWhen,
    required this.center,
    required this.r,
    required this.startDeg,
    required this.sweepDeg,
  });

  final VisualPoint center;
  final double r;
  final double startDeg;
  final double sweepDeg;

  @override
  String get type => 'arc';

  @override
  Map<String, dynamic> toJson() => {
    ..._commonToJson(this),
    'center': center.toJson(),
    'r': r,
    'startDeg': startDeg,
    'sweepDeg': sweepDeg,
  };
}

class ArrowElement extends VisualElement {
  const ArrowElement({
    required super.id,
    required super.style,
    required super.layer,
    required super.visible,
    super.visibleWhen,
    required this.from,
    required this.to,
  });

  final VisualPoint from;
  final VisualPoint to;

  @override
  String get type => 'arrow';

  @override
  Map<String, dynamic> toJson() => {
    ..._commonToJson(this),
    'from': from.toJson(),
    'to': to.toJson(),
  };
}

class TextElement extends VisualElement {
  const TextElement({
    required super.id,
    required super.style,
    required super.layer,
    required super.visible,
    super.visibleWhen,
    required this.at,
    required this.text,
  });

  final VisualPoint at;
  final String text;

  @override
  String get type => 'text';

  @override
  Map<String, dynamic> toJson() => {
    ..._commonToJson(this),
    'at': at.toJson(),
    'text': text,
  };
}

class MathLabelElement extends VisualElement {
  const MathLabelElement({
    required super.id,
    required super.style,
    required super.layer,
    required super.visible,
    super.visibleWhen,
    required this.at,
    required this.tex,
  });

  final VisualPoint at;
  final String tex;

  @override
  String get type => 'math_label';

  @override
  Map<String, dynamic> toJson() => {
    ..._commonToJson(this),
    'at': at.toJson(),
    'tex': tex,
  };
}

class GroupElement extends VisualElement {
  const GroupElement({
    required super.id,
    required super.style,
    required super.layer,
    required super.visible,
    super.visibleWhen,
    required this.children,
  });

  final List<VisualElement> children;

  @override
  String get type => 'group';

  @override
  List<String> get allIds => [
    id,
    for (final child in children) ...child.allIds,
  ];

  @override
  Map<String, dynamic> toJson() => {
    ..._commonToJson(this),
    'children': children.map((c) => c.toJson()).toList(),
  };
}

class PlotElement extends VisualElement {
  const PlotElement({
    required super.id,
    required super.style,
    required super.layer,
    required super.visible,
    super.visibleWhen,
    required this.expression,
    this.domain,
    this.samples,
  });

  final String expression;
  final (double, double)? domain;
  final int? samples;

  @override
  String get type => 'plot';

  @override
  Map<String, dynamic> toJson() => {
    ..._commonToJson(this),
    'expression': expression,
    if (domain != null) 'domain': [domain!.$1, domain!.$2],
    if (samples != null) 'samples': samples,
  };
}

/// One component of a circuit diagram (`kind: circuit`).
///
/// `battery`, `resistor`, `switch` and `wire` are two-point components
/// spanning `from` → `to`; `meter` sits at a single point `at` with a
/// `meter` kind. `closed` only applies to `switch` (default open, the
/// more visible state); `label` is a short annotation such as `R1`.
enum CircuitComponent {
  battery,
  resistor,
  powerSwitch,
  wire,
  meter;

  /// The DSL name: `powerSwitch` is written as `switch` in JSON
  /// (`switch` is a Dart keyword and cannot be an enum value).
  String get dslName => this == CircuitComponent.powerSwitch ? 'switch' : name;
}

/// What a `meter` component measures.
enum CircuitMeterKind { ammeter, voltmeter }

class CircuitElement extends VisualElement {
  const CircuitElement({
    required super.id,
    required super.style,
    required super.layer,
    required super.visible,
    super.visibleWhen,
    required this.component,
    this.from,
    this.to,
    this.at,
    this.closed = false,
    this.meter,
    this.label,
  });

  final CircuitComponent component;
  final VisualPoint? from;
  final VisualPoint? to;
  final VisualPoint? at;
  final bool closed;
  final CircuitMeterKind? meter;
  final String? label;

  @override
  String get type => 'circuit';

  @override
  Map<String, dynamic> toJson() => {
    ..._commonToJson(this),
    'component': component.dslName,
    if (from != null) 'from': from!.toJson(),
    if (to != null) 'to': to!.toJson(),
    if (at != null) 'at': at!.toJson(),
    if (closed) 'closed': true,
    if (meter != null) 'meter': meter!.name,
    if (label != null) 'label': label,
  };
}
