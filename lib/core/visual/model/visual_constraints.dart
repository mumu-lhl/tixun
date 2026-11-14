/// Geometric constraints declared on a scene (Phase 4, plan §4.5).
///
/// A constraint states a geometric fact the construction must satisfy:
/// a distance between two points, two segments parallel or
/// perpendicular, a point on a circle, a fixed angle between two
/// segments, two segments intersecting, or a point being the midpoint
/// of a segment. Element references are ids of `point`, `line`,
/// `arrow` or `circle` elements.
///
/// The validator checks declared constraints against the literal
/// coordinates: a violated constraint is an error for an exact
/// construction, and a warning when `meta.schematic` is true (the
/// drawing is intentionally not to scale). Constraints over
/// `$param`-bound coordinates cannot be checked statically and warn
/// instead of failing.
library;

import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/core/visual/model/visual_elements.dart';

/// Maximum number of constraints per scene (resource bound, same order
/// as the other DSL limits).
const visualMaxConstraints = 64;

/// One geometric constraint. [a]/[b] name the two elements for
/// `distance`/`parallel`/`perpendicular`/`angle`/`intersect`; [point]
/// + [circle] for `on_circle`; [point] + [a]/[b] for `midpoint`.
/// [value] is the required distance (model units) or angle (degrees).
enum VisualConstraintType {
  distance,
  parallel,
  perpendicular,
  onCircle,
  angle,
  intersect,
  midpoint;

  /// The DSL name: `onCircle` is written as `on_circle` in JSON.
  String get dslName =>
      this == VisualConstraintType.onCircle ? 'on_circle' : name;

  static VisualConstraintType? fromDslName(String name) {
    for (final value in VisualConstraintType.values) {
      if (value.dslName == name) return value;
    }
    return null;
  }
}

class VisualConstraint {
  const VisualConstraint({
    required this.type,
    this.a,
    this.b,
    this.point,
    this.circle,
    this.value,
  });

  final VisualConstraintType type;
  final String? a;
  final String? b;
  final String? point;
  final String? circle;
  final double? value;

  factory VisualConstraint.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {
      'type',
      'a',
      'b',
      'point',
      'circle',
      'value',
    }, '约束');
    final typeRaw = json['type'];
    if (typeRaw == null) {
      throw const AppFormatException(
        AppErrorCode.errorMissingParameter,
        '约束缺少字段：type。',
      );
    }
    final type = typeRaw is String
        ? VisualConstraintType.fromDslName(typeRaw)
        : null;
    if (type == null) {
      throw AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '未知的约束类型：$typeRaw。',
        [typeRaw.toString()],
      );
    }
    String? idField(String key) {
      final raw = json[key];
      if (raw == null) return null;
      if (raw is! String || raw.isEmpty) {
        throw AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          '约束的 $key 必须是非空文字。',
          [key],
        );
      }
      return raw;
    }

    final a = idField('a');
    final b = idField('b');
    final point = idField('point');
    final circle = idField('circle');
    double? value;
    final rawValue = json['value'];
    if (rawValue != null) {
      if (rawValue is! num || !rawValue.toDouble().isFinite) {
        throw const AppFormatException(
          AppErrorCode.errorParameterMustBeNumber,
          '约束的 value 必须是有限数字。',
        );
      }
      value = rawValue.toDouble();
    }
    switch (type) {
      case VisualConstraintType.distance:
        if (a == null || b == null || value == null) {
          throw const AppFormatException(
            AppErrorCode.errorMissingParameter,
            'distance 约束需要字段：a、b、value。',
          );
        }
        if (value < 0) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            'distance 约束的 value 不能小于 0。',
            ['value'],
          );
        }
      case VisualConstraintType.parallel:
      case VisualConstraintType.perpendicular:
      case VisualConstraintType.intersect:
        if (a == null || b == null) {
          throw const AppFormatException(
            AppErrorCode.errorMissingParameter,
            '约束需要字段：a、b。',
          );
        }
      case VisualConstraintType.onCircle:
        if (point == null || circle == null) {
          throw const AppFormatException(
            AppErrorCode.errorMissingParameter,
            'on_circle 约束需要字段：point、circle。',
          );
        }
      case VisualConstraintType.angle:
        if (a == null || b == null || value == null) {
          throw const AppFormatException(
            AppErrorCode.errorMissingParameter,
            'angle 约束需要字段：a、b、value。',
          );
        }
        if (value < 0 || value > 180) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            'angle 约束的 value 必须在 0~180 度之间。',
            ['value'],
          );
        }
      case VisualConstraintType.midpoint:
        if (point == null || a == null || b == null) {
          throw const AppFormatException(
            AppErrorCode.errorMissingParameter,
            'midpoint 约束需要字段：point、a、b。',
          );
        }
    }
    return VisualConstraint(
      type: type,
      a: a,
      b: b,
      point: point,
      circle: circle,
      value: value,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.dslName,
    if (a != null) 'a': a,
    if (b != null) 'b': b,
    if (point != null) 'point': point,
    if (circle != null) 'circle': circle,
    if (value != null) 'value': value,
  };
}
