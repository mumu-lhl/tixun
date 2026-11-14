import 'dart:convert';

import '../visual/model/visual_elements.dart';
import '../visual/validation/visual_validator.dart';

// The model sees the private DSL's fields, not just its name. Keep this
// contract next to the tools; the scene validator remains authoritative
// for cross-field semantics, references and numeric/geometry constraints.
const _number = {'type': 'number'};
const _bool = {'type': 'boolean'};
const _text = {'type': 'string'};
const _id = {'type': 'string', 'minLength': 1};
const _ms = {'type': 'integer', 'minimum': 0};
Map<String, dynamic> _object(
  Map<String, dynamic> properties,
  List<String> required,
) => {
  'type': 'object',
  'additionalProperties': false,
  'properties': properties,
  'required': required,
};
Map<String, dynamic> _array(Object items, {int? min, int? max}) => {
  'type': 'array',
  'items': items,
  'minItems': ?min,
  'maxItems': ?max,
};
Map<String, dynamic> _enum(Iterable<String> values) => {
  'type': 'string',
  'enum': values.toList(),
};
final _coord = {
  'anyOf': [
    _number,
    _object({r'$param': _id}, [r'$param']),
  ],
};
final _point = _array(_coord, min: 2, max: 2);
final _range = {
  ..._array(_number, min: 2, max: 2),
  'description': 'Finite [min,max], min < max, span <= 1e9; use coordinates with adequate floating-point precision.',
};
final _expression = {
  'type': 'string',
  'description': 'Restricted expression, not code or LaTeX. Variables x,t and model parameter names; pi,e; + - * / ^; sin cos tan asin acos atan sinh cosh tanh exp ln log(base10) sqrt abs floor ceil sign; if(cond,a,b), < <= > >= == != && || !. AST depth <=32. Use explicit multiplication, e.g. a*x^2.',
};

Map<String, dynamic> _element(
  String type,
  Map<String, dynamic> fields,
  List<String> required,
) => _object(
  {
    'id': _id,
    'type': _enum([type]),
    'style': _enum(VisualStyle.values.map((s) => s.name)),
    'layer': {'type': 'integer'},
    'visible': _bool,
    'visibleWhen': _object(
      {'control': _id, 'equals': _bool},
      ['control', 'equals'],
    ),
    ...fields,
  },
  ['id', 'type', ...required],
);

/// Full leaf-element contract shared by create and patch operations.
/// Groups recurse by the same shape, bounded by the scene validator.
final visualElementSchema = <String, dynamic>{
  'anyOf': [
    _element(
      'point',
      {'at': _point, 'label': _text, 'draggable': _bool},
      ['at'],
    ),
    _element(
      'line',
      {'p1': _point, 'p2': _point, 'dashed': _bool},
      ['p1', 'p2'],
    ),
    _element('polyline', {'points': _array(_point, min: 2)}, ['points']),
    _element(
      'polygon',
      {'points': _array(_point, min: 3), 'fill': _bool},
      ['points'],
    ),
    _element(
      'circle',
      {
        'center': _point,
        'r': {'type': 'number', 'exclusiveMinimum': 0},
      },
      ['center', 'r'],
    ),
    _element(
      'arc',
      {
        'center': _point,
        'r': {'type': 'number', 'exclusiveMinimum': 0},
        'startDeg': _number,
        'sweepDeg': _number,
      },
      ['center', 'r', 'startDeg', 'sweepDeg'],
    ),
    _element('arrow', {'from': _point, 'to': _point}, ['from', 'to']),
    _element(
      'text',
      {
        'at': _point,
        'text': {'type': 'string', 'maxLength': 500},
      },
      ['at', 'text'],
    ),
    _element(
      'math_label',
      {
        'at': _point,
        'tex': {'type': 'string', 'maxLength': 500},
      },
      ['at', 'tex'],
    ),
    _element(
      'plot',
      {
        'expression': _expression,
        'domain': _range,
        'samples': {
          'type': 'integer',
          'minimum': 2,
          'maximum': visualMaxPlotSamples,
        },
      },
      ['expression'],
    ),
    _element(
      'group',
      {
        'children': {
          ..._array({'type': 'object'}, min: 1),
          'description': 'Children use this same element contract (including nested groups). Globally unique ids; max group depth 4. Group visibility hides all descendants.',
        },
      },
      ['children'],
    ),
    for (final component in ['battery', 'resistor', 'switch', 'wire'])
      _element(
        'circuit',
        {
          'component': _enum([component]),
          'from': _point,
          'to': _point,
          if (component == 'switch') 'closed': _bool,
          'label': _text,
        },
        ['component', 'from', 'to'],
      ),
    _element(
      'circuit',
      {
        'component': _enum(['meter']),
        'at': _point,
        'meter': _enum(['ammeter', 'voltmeter']),
        'label': _text,
      },
      ['component', 'at', 'meter'],
    ),
  ],
};

Map<String, dynamic> _control(
  String kind,
  Map<String, dynamic> fields,
  List<String> required,
) => _object(
  {
    'id': _id,
    'kind': _enum([kind]),
    'label': _id,
    ...fields,
  },
  ['id', 'kind', 'label', ...required],
);
Map<String, dynamic> _constraint(
  String type,
  List<String> references, {
  bool value = false,
}) => _object(
  {
    'type': _enum([type]),
    for (final name in references) name: _id,
    if (value) 'value': _number,
  },
  ['type', ...references, if (value) 'value'],
);

final visualSceneSchema = _object(
  {
    'v': {
      'type': 'integer',
      'enum': [1],
    },
    'kind': _enum([
      'plot2d',
      'geometry',
      'physics',
      'vector',
      'chart',
      'circuit',
      'chemistry',
      'geography',
    ]),
    'title': _text,
    'model': _object({
      'expression': _expression,
      'parameters': {'type': 'object', 'additionalProperties': _number},
      'showAxes': _bool,
    }, []),
    'view': _object({'x': _range, 'y': _range}, []),
    'elements': _array(visualElementSchema, max: visualMaxElements),
    'controls': _array({
      'anyOf': [
        _control(
          'slider',
          {
            'min': _number,
            'max': _number,
            'step': {'type': 'number', 'exclusiveMinimum': 0},
            'value': _number,
          },
          ['min', 'max', 'step', 'value'],
        ),
        _control('toggle', {'value': _bool}, ['value']),
      ],
    }, max: visualMaxControls),
    'timeline': _object(
      {
        'durationMs': {'type': 'integer', 'minimum': 1},
        'tracks': _array(
          _object(
            {
              'id': _id,
              'target': _id,
              'from': _number,
              'to': _number,
              'startMs': _ms,
              'endMs': _ms,
            },
            ['id', 'target', 'from', 'to', 'startMs', 'endMs'],
          ),
          max: visualMaxTracks,
        ),
        'steps': _array(
          _object(
            {
              'atMs': _ms,
              'show': _array(_id),
              'hide': _array(_id),
              'note': _text,
            },
            ['atMs'],
          ),
          max: visualMaxSteps,
        ),
      },
      ['durationMs'],
    ),
    'annotations': _array(
      _object({'at': _point, 'text': _text}, ['at', 'text']),
    ),
    'constraints': _array({
      'anyOf': [
        _constraint('distance', ['a', 'b'], value: true),
        for (final type in ['parallel', 'perpendicular', 'intersect'])
          _constraint(type, ['a', 'b']),
        _constraint('angle', ['a', 'b'], value: true),
        _constraint('on_circle', ['point', 'circle']),
        _constraint('midpoint', ['point', 'a', 'b']),
      ],
    }, max: 64),
    'meta': _object({
      'alt': {'type': 'string', 'maxLength': 500},
      'schematic': _bool,
    }, []),
  },
  ['v', 'kind'],
);

/// Valid examples shipped to the model and checked against the real validator.
final visualDslExamples = <Map<String, dynamic>>[
  {
    'v': 1,
    'kind': 'plot2d',
    'model': {
      'expression': 'a*x^2',
      'parameters': {'a': 1},
    },
    'view': {
      'x': [-3, 3],
      'y': [-1, 9],
    },
    'controls': [
      {
        'id': 'a',
        'kind': 'slider',
        'label': 'a',
        'min': 0,
        'max': 1,
        'step': 0.1,
        'value': 1,
      },
    ],
    'meta': {'alt': 'Parabola with parameter a'},
  },
  {
    'v': 1,
    'kind': 'geometry',
    'view': {
      'x': [-3, 3],
      'y': [-3, 3],
    },
    'elements': [
      {
        'id': 'P',
        'type': 'point',
        'at': [0, 0],
        'draggable': true,
      },
      {
        'id': 'region',
        'type': 'polygon',
        'points': [
          [-2, -2],
          [2, -2],
          [0, 2],
        ],
        'fill': true,
        'style': 'muted',
      },
    ],
    'meta': {'alt': 'A draggable point and a selectable triangle'},
  },
];

final visualDslInstructions =
    '''
[TiXun Visual DSL v1 contract]
Use the tool's scene/element schema. Coordinates are [x,y]; a component can be a literal number or {"\$param":"a"} bound to model.parameters. Draggable points require literal coordinates. Slider ids match model.parameters keys; min<max, min<=value<=max. Track targets are slider ids; 0<=startMs<endMs<=durationMs; from/to stay within slider bounds. Step show/hide values are element ids; atMs is within the timeline. Layer order determines region hit testing. Assessment cards and fullscreen answering use the same fixed frame at t=0 and the same attempt; exploration controls are never answer controls. For point/drag questions keep targets in view; region options/answers must use visible, nondegenerate polygon ids with reachable areas at t=0, not arbitrary labels. Do not hide the correct region or cover it with a higher-layer polygon. Do not use unsupported choice controls.
Constraints: distance uses point ids a,b and nonnegative value; parallel/perpendicular/angle/intersect use line or arrow ids a,b (angle value 0..180 degrees); on_circle uses point,circle ids; midpoint uses point,a,b point ids. Use meta.schematic=true for deliberately not-to-scale diagrams. Validation/verification only checks DSL and declared geometry, never scientific truth. Chemistry/geography/circuit diagrams are illustrations, not simulations.
After create_visual, use its returned visual_id to repair quality_issues, explain the figure, or call create_quiz in the next round if the user requested a question. For follow-up edits use the saved visual index and get_visual. Keep question figures free of answers/solutions; only submit the question after the figure is ready.
Valid examples (adapt them; do not reproduce irrelevant elements):
${visualDslExamples.map(jsonEncode).join('\n')}
''';
