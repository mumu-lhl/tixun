import 'dart:math' as math;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/visual/model/visual_scene.dart';
import '../../core/visual/validation/visual_quality.dart';
import '../visual/visual_card.dart';

const diagramTypes = {
  'FunctionPlot',
  'NumberLine',
  'GeometryScene',
  'VectorDiagram',
};
const diagramExtension = 'tixunVisuals';

final _pair = Schema.list(items: Schema.number(), minItems: 2, maxItems: 2);
final _name = Schema.string(minLength: 1, maxLength: 120);

final a2uiDiagramComponents = [
  _component(
    'FunctionPlot',
    {
      'title': _name,
      'expressions': Schema.list(
        items: Schema.string(maxLength: 160),
        minItems: 1,
        maxItems: 3,
      ),
      'domain': _pair,
      'a': CommonSchemasV1.dynamicNumber,
    },
    ['title', 'expressions'],
  ),
  _component(
    'NumberLine',
    {
      'title': _name,
      'marks': Schema.list(items: Schema.number(), maxItems: 12),
      'interval': _pair,
      'openLeft': Schema.boolean(),
      'openRight': Schema.boolean(),
    },
    ['title', 'marks'],
  ),
  _component(
    'GeometryScene',
    {
      'title': _name,
      'points': Schema.list(items: _pair, minItems: 2, maxItems: 12),
      'labels': Schema.list(items: Schema.string(maxLength: 16), maxItems: 12),
      'closed': Schema.boolean(),
    },
    ['title', 'points'],
  ),
  _component(
    'VectorDiagram',
    {
      'title': _name,
      'vectors': Schema.list(items: _pair, minItems: 1, maxItems: 6),
    },
    ['title', 'vectors'],
  ),
];

ComponentImplementation _component(
  String name,
  Map<String, Schema> properties,
  List<String> required,
) => ComponentImplementation(
  name: name,
  schema: Schema.object(properties: properties, required: required),
  builder: (context, node, props, _) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<A2uiDiagramScope>();
    final scene = scope?.scenes[node.componentId];
    if (scene == null) return Text(context.l10n.inlineVisualUnavailable);
    final parameter = name == 'FunctionPlot' ? props.number('a') : null;
    final visible = _withA(scene, parameter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VisualCard(scene: visible, fullscreenAllowDrag: false),
        if (scope?.promote != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: () => scope!.promote!(node.componentId, scene),
              label: Text(context.l10n.a2uiSaveDiagram),
            ),
          ),
      ],
    );
  },
);

class A2uiDiagramScope extends InheritedWidget {
  const A2uiDiagramScope({
    required this.scenes,
    this.promote,
    required super.child,
    super.key,
  });
  final Map<String, VisualScene> scenes;
  final void Function(String id, VisualScene scene)? promote;

  @override
  bool updateShouldNotify(A2uiDiagramScope oldWidget) =>
      scenes != oldWidget.scenes || promote != oldWidget.promote;
}

VisualScene _withA(VisualScene scene, double? value) {
  final model = scene.model;
  if (model == null ||
      !model.parameters.containsKey('a') ||
      value == null ||
      !value.isFinite ||
      value.abs() > 100 ||
      model.parameters['a'] == value) {
    return scene;
  }
  // Only the numeric parameter changes. The saved scene and its element
  // expressions remain immutable. The A2UI Data Model owns the value.
  return VisualScene(
    kind: scene.kind,
    title: scene.title,
    view: scene.view,
    elements: scene.elements,
    model: VisualModel(parameters: {...model.parameters, 'a': value}),
  );
}

Map<String, Object?> compileDiagramSnapshots(CreateSurfaceMessage message) {
  final diagrams = (message.components ?? const [])
      .where((node) => diagramTypes.contains(node['component']))
      .toList();
  if (diagrams.length > 3) {
    throw const FormatException('At most three diagrams per block.');
  }
  final data = DataModel(message.dataModel);
  try {
    return {
      for (final node in diagrams)
        node['id'] as String: _semanticScene(node, data).toJson(),
    };
  } finally {
    data.dispose();
  }
}

Map<String, VisualScene> readDiagramSnapshots(CreateSurfaceMessage message) {
  final ids = {
    for (final node in message.components ?? const [])
      if (diagramTypes.contains(node['component'])) node['id'],
  };
  final metadata = message.metadata;
  if (ids.isEmpty && metadata == null) return const {};
  final extensions = metadata?['extensions'];
  final scenes = extensions is Map && extensions.length == 1
      ? extensions[diagramExtension]
      : null;
  if (scenes is! Map<String, dynamic> ||
      scenes.length != ids.length ||
      scenes.length > 3 ||
      !scenes.keys.every(ids.contains)) {
    throw const FormatException('Invalid stored diagram metadata.');
  }
  return scenes.map((key, raw) {
    if (raw is! Map<String, dynamic> ||
        raw['elements'] is! List ||
        raw.keys.any(
          (key) => !{
            'v',
            'title',
            'kind',
            'view',
            'model',
            'elements',
            'annotations',
          }.contains(key),
        )) {
      throw const FormatException('Invalid stored semantic scene.');
    }
    final elements = raw['elements'] as List;
    if (elements.length > 40 ||
        elements.any(
          (element) =>
              element is! Map ||
              !{
                'point',
                'polyline',
                'polygon',
                'line',
                'arrow',
                'circle',
                'plot',
              }.contains(element['type']) ||
              (element['type'] == 'plot' &&
                  (element['samples'] is! int ||
                      (element['samples'] as int) > 384)),
        )) {
      throw const FormatException(
        'Stored semantic drawing exceeds its limits.',
      );
    }
    return MapEntry(key, VisualScene.fromJson(raw));
  });
}

VisualScene _semanticScene(Map<String, Object?> node, DataModel data) {
  final type = node['component'];
  final title = (node['title'] as String).trim();
  if (title.isEmpty) throw const FormatException('Each diagram needs a title.');
  final json = <String, dynamic>{'v': 1, 'title': title};
  switch (type) {
    case 'FunctionPlot':
      final domain = node['domain'] == null
          ? [-5.0, 5.0]
          : _range(node['domain']);
      final expressions = (node['expressions'] as List).cast<String>();
      final raw = node['a'];
      final value = raw is Map ? data.get(raw['@path'] as String) : raw;
      final a = raw == null ? null : _number(value, limit: 100);
      json.addAll({
        'kind': 'plot2d',
        'view': {'x': domain},
        if (a != null)
          'model': {
            'parameters': {'a': a},
          },
        'elements': [
          for (final (i, expression) in expressions.indexed)
            _element('plot', 'curve$i', {
              'expression': expression,
              'domain': domain,
              'samples': 384,
              'style': ['primary', 'highlight', 'success'][i],
            }),
        ],
      });
    case 'GeometryScene':
      final points = (node['points'] as List).map(_point).toList();
      final labels = (node['labels'] as List?)?.cast<String>();
      if (labels != null && labels.length != points.length) {
        throw const FormatException('Geometry labels must match the points.');
      }
      final closed = node['closed'] == true;
      if (closed && points.length < 3) {
        throw const FormatException('A polygon needs at least three points.');
      }
      if (points.map((p) => (p[0], p[1])).toSet().length != points.length) {
        throw const FormatException('Geometry vertices must be distinct.');
      }
      if (closed) {
        final origin = points.first;
        var doubledArea = 0.0;
        for (var i = 1; i + 1 < points.length; i++) {
          final a = points[i], b = points[i + 1];
          doubledArea +=
              (a[0] - origin[0]) * (b[1] - origin[1]) -
              (a[1] - origin[1]) * (b[0] - origin[0]);
        }
        if (doubledArea == 0) {
          throw const FormatException('The polygon has zero area.');
        }
      }
      json.addAll({
        'kind': 'geometry',
        'elements': [
          _element(closed ? 'polygon' : 'polyline', 'shape', {
            'points': points,
          }),
          for (final (i, point) in points.indexed)
            _element('point', 'point$i', {
              'at': point,
              if (labels != null) 'label': labels[i],
            }),
        ],
      });
    case 'VectorDiagram':
      final vectors = (node['vectors'] as List).map(_point).toList();
      if (vectors.any((p) => p[0] == 0 && p[1] == 0)) {
        throw const FormatException('A zero vector has no arrow direction.');
      }
      json.addAll({
        'kind': 'vector',
        'view': {
          'x': _axisExtent(vectors.map((p) => p[0])),
          'y': _axisExtent(vectors.map((p) => p[1])),
        },
        'elements': [
          for (final (i, point) in vectors.indexed)
            _element('arrow', 'vector$i', {
              'from': [0, 0],
              'to': point,
              'style': ['primary', 'highlight', 'success'][i % 3],
            }),
        ],
      });
    case 'NumberLine':
      json.addAll(_numberLine(node));
  }
  final scene = VisualScene.fromJson(json);
  if (checkVisualQuality(scene).isNotEmpty) {
    throw const FormatException(
      'The diagram did not pass visual quality checks.',
    );
  }
  return scene;
}

Map<String, dynamic> _numberLine(Map<String, Object?> node) {
  final marks = (node['marks'] as List).map(_number).toSet();
  final interval = node['interval'] == null ? null : _range(node['interval']);
  if (interval != null) marks.addAll(interval);
  if (marks.isEmpty) marks.addAll([-1, 0, 1]);
  final x = _axisExtent(marks);
  final span = x.last - x.first;
  final tick = span * .016;
  final values = marks.toList()..sort();
  final radius = interval == null
      ? 0.0
      : math.min(tick * .66, (interval.last - interval.first) * .24);
  final openLeft = node['openLeft'] == true;
  final openRight = node['openRight'] == true;
  final gaps = [
    if (interval != null && openLeft) interval.first,
    if (interval != null && openRight) interval.last,
  ];
  final offsets = [
    x.first,
    for (final n in gaps) ...[n - radius, n + radius],
    x.last,
  ];
  return {
    'kind': 'geometry',
    'model': {'showAxes': false},
    'view': {
      'x': x,
      'y': [-span * .12, span * .12],
    },
    'elements': [
      for (var i = 0; i + 1 < offsets.length; i += 2)
        _element(
          i + 2 == offsets.length ? 'arrow' : 'line',
          'axis$i',
          i + 2 == offsets.length
              ? {
                  'from': [offsets[i], 0],
                  'to': [offsets[i + 1], 0],
                }
              : {
                  'p1': [offsets[i], 0],
                  'p2': [offsets[i + 1], 0],
                },
        ),
      for (final (i, n) in values.indexed)
        if (interval == null || !interval.contains(n))
          _element('line', 'mark$i', {
            'p1': [n, -tick],
            'p2': [n, tick],
          }),
      if (interval != null) ...[
        _element('line', 'interval', {
          'p1': [interval.first + (openLeft ? radius : 0), 0],
          'p2': [interval.last - (openRight ? radius : 0), 0],
          'style': 'highlight',
        }),
        for (final (i, n) in interval.indexed)
          if (i == 0 ? openLeft : openRight)
            _element('circle', 'end$i', {
              'center': [n, 0],
              'r': radius,
              'style': 'highlight',
            })
          else
            _element('point', 'end$i', {
              'at': [n, 0],
              'style': 'highlight',
            }),
      ],
    ],
    'annotations': [
      for (final n in marks)
        {
          'at': [n, -tick * 1.6],
          'text': _label(n),
        },
    ],
  };
}

List<double> _axisExtent(Iterable<double> values) {
  final minimum = values.fold(0.0, math.min);
  final maximum = values.fold(0.0, math.max);
  final pad = math.max((maximum - minimum) * .16, .2);
  return [minimum - pad, maximum + pad];
}

String _label(double n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toString();

double _number(Object? value, {double limit = 1000000}) {
  if (value is! num || !value.isFinite || value.abs() > limit) {
    throw const FormatException(
      'A diagram coordinate or parameter is outside its limit.',
    );
  }
  return value.toDouble();
}

List<double> _point(Object? raw) => (raw as List).map(_number).toList();

List<double> _range(Object? raw) {
  final pair = _point(raw);
  if (pair.last - pair.first < 1e-8) {
    throw const FormatException(
      'A diagram range must be increasing and non-degenerate.',
    );
  }
  return pair;
}

Map<String, dynamic> _element(
  String type,
  String id,
  Map<String, Object?> props,
) => {'type': type, 'id': id, ...props};
