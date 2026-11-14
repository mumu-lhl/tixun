/// Visual DSL v1 scene model (`VisualScene` + controls, timeline,
/// annotations, meta).
///
/// JSON shape follows `~/workspace/push-tmp/tixun-visual-dsl-v1.md`.
/// `VisualScene.fromJson` rejects unknown fields at every level and runs
/// the full validator first (see `visual_validator.dart`), mirroring
/// `QuestionSpec.fromJson`: malformed input throws [AppFormatException],
/// never a raw [TypeError].
library;

import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/core/visual/model/visual_constraints.dart';
import 'package:tixun/core/visual/model/visual_elements.dart';
import 'package:tixun/core/visual/validation/visual_validator.dart';

export 'package:tixun/core/visual/model/visual_elements.dart';

/// Scene categories. Phase 1 renders `plot2d`/`geometry`/`physics`/`vector`
/// with the same element engine; `chart` is only expressed via elements +
/// `plot` (no dedicated chart model yet). Phase 4 adds `circuit` (with the
/// `circuit` element), `chemistry` and `geography` — the latter two are
/// rendered by the generic engine, like `geometry`.
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
        '范围必须是 [min, max] 形式的数组。',
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
        '范围端点必须是有限数字。',
      );
    }
    return VisualRange(min.toDouble(), max.toDouble());
  }

  List<double> toJson() => [min, max];

  @override
  bool operator ==(Object other) =>
      other is VisualRange && min == other.min && max == other.max;

  @override
  int get hashCode => Object.hash(min, max);
}

/// The math/physics model: one expression plus named parameters.
/// `parameters` also declares the names usable in `$param` coordinate
/// bindings and in expressions. `showAxes` (from the rendering contract)
/// defaults to true when absent.
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
      'expression',
      'parameters',
      'showAxes',
    }, 'model');
    Map<String, double> parameters = const {};
    if (json['parameters'] != null) {
      final raw = json['parameters'];
      if (raw is! Map<String, dynamic>) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          'model 的 parameters 必须是对象。',
        );
      }
      parameters = raw.map((key, value) {
        if (value is! num || !value.toDouble().isFinite) {
          throw AppFormatException(
            AppErrorCode.errorParameterMustBeNumber,
            '参数 $key 必须是有限数字。',
            [key],
          );
        }
        return MapEntry(key, value.toDouble());
      });
    }
    final expression = json['expression'];
    if (expression != null && expression is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        'model 的 expression 必须是文字。',
      );
    }
    final showAxes = json['showAxes'];
    if (showAxes != null && showAxes is! bool) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        'model 的 showAxes 必须是布尔值。',
      );
    }
    return VisualModel(
      expression: expression as String?,
      parameters: parameters,
      showAxes: showAxes as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (expression != null) 'expression': expression,
    if (parameters.isNotEmpty) 'parameters': parameters,
    if (showAxes != null) 'showAxes': showAxes,
  };
}

/// Visible coordinate ranges. Absent ranges are auto-fit by the renderer.
class VisualView {
  const VisualView({this.x, this.y});

  final VisualRange? x;
  final VisualRange? y;

  factory VisualView.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {'x', 'y'}, 'view');
    return VisualView(
      x: json['x'] == null ? null : VisualRange.fromJson(json['x']),
      y: json['y'] == null ? null : VisualRange.fromJson(json['y']),
    );
  }

  Map<String, dynamic> toJson() => {
    if (x != null) 'x': x!.toJson(),
    if (y != null) 'y': y!.toJson(),
  };
}

/// A text annotation anchored at a model coordinate.
class VisualAnnotation {
  const VisualAnnotation({required this.at, required this.text});

  final VisualPoint at;
  final String text;

  factory VisualAnnotation.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {'at', 'text'}, 'annotation');
    final at = json['at'];
    if (at == null) {
      throw const AppFormatException(
        AppErrorCode.errorMissingParameter,
        '标注缺少字段：at。',
      );
    }
    final text = json['text'];
    if (text is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        '标注的 text 必须是文字。',
      );
    }
    return VisualAnnotation(at: VisualPoint.fromJson(at), text: text);
  }

  Map<String, dynamic> toJson() => {'at': at.toJson(), 'text': text};
}

/// Non-executable metadata. `alt` is the accessibility text (required when
/// the scene has no `title`); `schematic` marks the scene as a
/// not-to-scale sketch whose content is not strictly verified.
class VisualMeta {
  const VisualMeta({this.alt, this.schematic = false});

  final String? alt;
  final bool schematic;

  factory VisualMeta.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {'alt', 'schematic'}, 'meta');
    final alt = json['alt'];
    if (alt != null && alt is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        'meta 的 alt 必须是文字。',
      );
    }
    final schematic = json['schematic'];
    if (schematic != null && schematic is! bool) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        'meta 的 schematic 必须是布尔值。',
      );
    }
    return VisualMeta(
      alt: alt as String?,
      schematic: schematic as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    if (alt != null) 'alt': alt,
    if (schematic) 'schematic': true,
  };
}

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

/// Base type for interactive controls (v1: parse + validate; interactive
/// binding is Phase 2).
sealed class VisualControl {
  const VisualControl({required this.id, required this.label});

  final String id;
  final String label;

  String get kind;

  Map<String, dynamic> toJson();

  factory VisualControl.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    if (kind is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        '控件的 kind 必须是文字。',
      );
    }
    switch (kind) {
      case 'slider':
        checkNoUnknownFields(json, const {
          'id',
          'kind',
          'label',
          'min',
          'max',
          'step',
          'value',
        }, 'slider 控件');
        return SliderControl(
          id: _controlId(json),
          label: _controlLabel(json),
          min: _controlNumber(json, 'min'),
          max: _controlNumber(json, 'max'),
          step: _controlNumber(json, 'step'),
          value: _controlNumber(json, 'value'),
        );
      case 'toggle':
        checkNoUnknownFields(json, const {
          'id',
          'kind',
          'label',
          'value',
        }, 'toggle 控件');
        final value = json['value'];
        if (value is! bool) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            'toggle 控件的 value 必须是布尔值。',
          );
        }
        return ToggleControl(
          id: _controlId(json),
          label: _controlLabel(json),
          value: value,
        );
      case 'choice':
        checkNoUnknownFields(json, const {
          'id',
          'kind',
          'label',
          'options',
          'value',
        }, 'choice 控件');
        final options = json['options'];
        if (options is! List || options.any((o) => o is! String)) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            'choice 控件的 options 必须是文字数组。',
          );
        }
        return ChoiceControl(
          id: _controlId(json),
          label: _controlLabel(json),
          options: options.cast<String>(),
          value: _controlString(json, 'value'),
        );
      default:
        throw AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          '未知的控件类型：$kind。',
          [kind],
        );
    }
  }
}

String _controlId(Map<String, dynamic> json) {
  final id = json['id'];
  if (id is! String || id.isEmpty) {
    throw const AppFormatException(
      AppErrorCode.errorInvalidParameterType,
      '控件的 id 必须是非空文字。',
    );
  }
  return id;
}

String _controlLabel(Map<String, dynamic> json) {
  final label = json['label'];
  if (label is! String || label.isEmpty) {
    throw const AppFormatException(
      AppErrorCode.errorInvalidParameterType,
      '控件的 label 必须是非空文字。',
    );
  }
  return label;
}

double _controlNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || !value.toDouble().isFinite) {
    throw AppFormatException(
      AppErrorCode.errorParameterMustBeNumber,
      '控件的 $key 必须是有限数字。',
      [key],
    );
  }
  return value.toDouble();
}

String _controlString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw AppFormatException(
      AppErrorCode.errorParameterMustBeText,
      '控件的 $key 必须是文字。',
      [key],
    );
  }
  return value;
}

/// Numeric slider bound to a model parameter (its `id` must match a
/// `model.parameters` key).
class SliderControl extends VisualControl {
  const SliderControl({
    required super.id,
    required super.label,
    required this.min,
    required this.max,
    required this.step,
    required this.value,
  });

  final double min;
  final double max;
  final double step;
  final double value;

  @override
  String get kind => 'slider';

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'label': label,
    'min': min,
    'max': max,
    'step': step,
    'value': value,
  };
}

/// On/off switch. A toggle may gate an element via its `visibleWhen`.
class ToggleControl extends VisualControl {
  const ToggleControl({
    required super.id,
    required super.label,
    required this.value,
  });

  final bool value;

  @override
  String get kind => 'toggle';

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'label': label,
    'value': value,
  };
}

/// Single-choice selector; `value` must be one of [options].
class ChoiceControl extends VisualControl {
  const ChoiceControl({
    required super.id,
    required super.label,
    required this.options,
    required this.value,
  });

  final List<String> options;
  final String value;

  @override
  String get kind => 'choice';

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'label': label,
    'options': options,
    'value': value,
  };
}

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

/// A numeric parameter varying linearly over a time window.
class VisualTrack {
  const VisualTrack({
    required this.id,
    required this.target,
    required this.from,
    required this.to,
    required this.startMs,
    required this.endMs,
  });

  /// Track id (unique within the timeline).
  final String id;

  /// A slider control id.
  final String target;
  final double from;
  final double to;
  final int startMs;
  final int endMs;

  factory VisualTrack.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {
      'id',
      'target',
      'from',
      'to',
      'startMs',
      'endMs',
    }, 'track');
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        'track 的 id 必须是非空文字。',
      );
    }
    final target = json['target'];
    if (target is! String || target.isEmpty) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        'track 的 target 必须是非空文字。',
      );
    }
    return VisualTrack(
      id: id,
      target: target,
      from: _trackNumber(json, 'from'),
      to: _trackNumber(json, 'to'),
      startMs: _trackInt(json, 'startMs'),
      endMs: _trackInt(json, 'endMs'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'target': target,
    'from': from,
    'to': to,
    'startMs': startMs,
    'endMs': endMs,
  };
}

double _trackNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || !value.toDouble().isFinite) {
    throw AppFormatException(
      AppErrorCode.errorParameterMustBeNumber,
      'track 的 $key 必须是有限数字。',
      [key],
    );
  }
  return value.toDouble();
}

int _trackInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw AppFormatException(
      AppErrorCode.errorParameterMustBeNumber,
      'track 的 $key 必须是整数。',
      [key],
    );
  }
  return value;
}

/// One teaching step: show/hide elements at [atMs], with an optional note.
class VisualStep {
  const VisualStep({
    required this.atMs,
    this.show = const [],
    this.hide = const [],
    this.note,
  });

  final int atMs;
  final List<String> show;
  final List<String> hide;
  final String? note;

  factory VisualStep.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {'atMs', 'show', 'hide', 'note'}, 'step');
    final atMs = json['atMs'];
    if (atMs is! int) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeNumber,
        'step 的 atMs 必须是整数。',
      );
    }
    List<String> idList(String key) {
      final value = json[key];
      if (value == null) return const [];
      if (value is! List || value.any((v) => v is! String)) {
        throw AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          'step 的 $key 必须是文字数组。',
          [key],
        );
      }
      return value.cast<String>();
    }

    final note = json['note'];
    if (note != null && note is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        'step 的 note 必须是文字。',
      );
    }
    return VisualStep(
      atMs: atMs,
      show: idList('show'),
      hide: idList('hide'),
      note: note as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'atMs': atMs,
    'show': show,
    'hide': hide,
    if (note != null) 'note': note,
  };
}

/// Animation / teaching-step timeline (v1: parse + validate; playback is
/// Phase 2).
class VisualTimeline {
  const VisualTimeline({
    required this.durationMs,
    this.tracks = const [],
    this.steps = const [],
  });

  final int durationMs;
  final List<VisualTrack> tracks;
  final List<VisualStep> steps;

  factory VisualTimeline.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {
      'durationMs',
      'tracks',
      'steps',
    }, 'timeline');
    final durationMs = json['durationMs'];
    if (durationMs is! int) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeNumber,
        'timeline 的 durationMs 必须是整数。',
      );
    }
    List<VisualTrack> tracks = const [];
    if (json['tracks'] != null) {
      final raw = json['tracks'];
      if (raw is! List) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          'timeline 的 tracks 必须是数组。',
        );
      }
      tracks = raw.map((t) {
        if (t is! Map<String, dynamic>) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            'track 必须是对象。',
          );
        }
        return VisualTrack.fromJson(t);
      }).toList();
    }
    List<VisualStep> steps = const [];
    if (json['steps'] != null) {
      final raw = json['steps'];
      if (raw is! List) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          'timeline 的 steps 必须是数组。',
        );
      }
      steps = raw.map((s) {
        if (s is! Map<String, dynamic>) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            'step 必须是对象。',
          );
        }
        return VisualStep.fromJson(s);
      }).toList();
    }
    return VisualTimeline(durationMs: durationMs, tracks: tracks, steps: steps);
  }

  Map<String, dynamic> toJson() => {
    'durationMs': durationMs,
    'tracks': tracks.map((t) => t.toJson()).toList(),
    'steps': steps.map((s) => s.toJson()).toList(),
  };
}

// ---------------------------------------------------------------------------
// Scene
// ---------------------------------------------------------------------------

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

/// A Visual DSL v1 scene.
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

  /// Every element id in the scene, including group children.
  List<String> get allElementIds => [
    for (final element in elements) ...element.allIds,
  ];

  /// Total element count, counting group children (limit: 256).
  int get elementCount => allElementIds.length;

  /// Parameter names declared by `model.parameters`.
  Set<String> get parameterNames => model?.parameters.keys.toSet() ?? {};

  factory VisualScene.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, _topLevelFields, '场景');
    final validation = validateVisualScene(json);
    if (validation.errors.isNotEmpty) {
      final first = validation.errors.first;
      throw AppFormatException(
        first.code == 'unknown_field'
            ? AppErrorCode.errorUnknownParameter
            : first.code == 'missing_field'
            ? AppErrorCode.errorMissingParameter
            : AppErrorCode.errorInvalidParameterType,
        first.message,
        first.path == null ? const [] : [first.path!],
      );
    }
    final kindRaw = json['kind'] as String;
    final kind = VisualSceneKind.values.firstWhere((k) => k.name == kindRaw);
    VisualModel? model;
    if (json['model'] != null) {
      model = VisualModel.fromJson(json['model'] as Map<String, dynamic>);
    }
    VisualView? view;
    if (json['view'] != null) {
      view = VisualView.fromJson(json['view'] as Map<String, dynamic>);
    }
    List<VisualElement> elements = const [];
    if (json['elements'] != null) {
      elements = (json['elements'] as List)
          .map((e) => VisualElement.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    List<VisualControl> controls = const [];
    if (json['controls'] != null) {
      controls = (json['controls'] as List)
          .map((c) => VisualControl.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    VisualTimeline? timeline;
    if (json['timeline'] != null) {
      timeline = VisualTimeline.fromJson(
        json['timeline'] as Map<String, dynamic>,
      );
    }
    List<VisualAnnotation> annotations = const [];
    if (json['annotations'] != null) {
      annotations = (json['annotations'] as List)
          .map((a) => VisualAnnotation.fromJson(a as Map<String, dynamic>))
          .toList();
    }
    VisualMeta? meta;
    if (json['meta'] != null) {
      meta = VisualMeta.fromJson(json['meta'] as Map<String, dynamic>);
    }
    List<VisualConstraint> constraints = const [];
    if (json['constraints'] != null) {
      constraints = (json['constraints'] as List)
          .map((c) => VisualConstraint.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    final title = json['title'];
    return VisualScene(
      v: (json['v'] as num).toInt(),
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

  Map<String, dynamic> toJson() => {
    'v': v,
    'kind': kind.name,
    if (title != null) 'title': title,
    if (model != null) 'model': model!.toJson(),
    if (view != null) 'view': view!.toJson(),
    if (elements.isNotEmpty)
      'elements': elements.map((e) => e.toJson()).toList(),
    if (controls.isNotEmpty)
      'controls': controls.map((c) => c.toJson()).toList(),
    if (timeline != null) 'timeline': timeline!.toJson(),
    if (annotations.isNotEmpty)
      'annotations': annotations.map((a) => a.toJson()).toList(),
    if (meta != null) 'meta': meta!.toJson(),
    if (constraints.isNotEmpty)
      'constraints': constraints.map((c) => c.toJson()).toList(),
  };
}
