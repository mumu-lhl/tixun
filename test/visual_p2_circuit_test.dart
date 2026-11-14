import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/validation/visual_validator.dart';

/// P2 coverage for `circuit` elements: valid voltmeter/ammeter scenes
/// and the shape rules for resistor/wire/battery/switch/meter.

Map<String, dynamic> _circuitScene(List<Map<String, dynamic>> elements) => {
  'v': 1,
  'kind': 'circuit',
  'title': '电路',
  'elements': elements,
  'meta': {'alt': '电路图'},
};

Map<String, dynamic> _twoPoint(
  String id,
  String component, {
  Map<String, dynamic>? extra,
}) => {
  'id': id,
  'type': 'circuit',
  'component': component,
  'from': [0, 0],
  'to': [3, 0],
  ...?extra,
};

void main() {
  group('valid circuit scenes', () {
    test('a voltmeter scene validates', () {
      final v = validateVisualScene(
        _circuitScene([
          _twoPoint('bat', 'battery'),
          _twoPoint('r', 'resistor'),
          _twoPoint('w', 'wire'),
          {
            'id': 'vm',
            'type': 'circuit',
            'component': 'meter',
            'at': [1, 1],
            'meter': 'voltmeter',
          },
        ]),
      );
      expect(v.ok, isTrue);
      expect(v.errors, isEmpty);
    });

    test('an ammeter scene validates', () {
      final v = validateVisualScene(
        _circuitScene([
          _twoPoint('bat', 'battery'),
          {
            'id': 'am',
            'type': 'circuit',
            'component': 'meter',
            'at': [1, -1],
            'meter': 'ammeter',
          },
        ]),
      );
      expect(v.ok, isTrue);
    });

    test('a switch with closed true/false validates', () {
      for (final closed in [true, false]) {
        final v = validateVisualScene(
          _circuitScene([
            _twoPoint('sw', 'switch', extra: {'closed': closed}),
          ]),
        );
        expect(v.ok, isTrue, reason: 'closed=$closed');
      }
    });

    test('a resistor and a wire assert their endpoints', () {
      // The validator records literal bounds for two-point
      // components; a resistor/wire without from/to is a missing
      // field error, not a silent pass.
      final missing = validateVisualScene(
        _circuitScene([
          {'id': 'r', 'type': 'circuit', 'component': 'resistor'},
        ]),
      );
      expect(missing.ok, isFalse);
      expect(missing.errors.map((e) => e.code), contains('missing_field'));
    });
  });

  group('circuit shape errors', () {
    test('a meter without a meter field is a missing_field error', () {
      final v = validateVisualScene(
        _circuitScene([
          {
            'id': 'm',
            'type': 'circuit',
            'component': 'meter',
            'at': [1, 1],
          },
        ]),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('missing_field'));
    });

    test('a meter with an unknown meter kind is rejected', () {
      final v = validateVisualScene(
        _circuitScene([
          {
            'id': 'm',
            'type': 'circuit',
            'component': 'meter',
            'at': [1, 1],
            'meter': 'ohmmeter',
          },
        ]),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('invalid_value'));
    });

    test('a meter does not take from/to', () {
      final v = validateVisualScene(
        _circuitScene([
          {
            'id': 'm',
            'type': 'circuit',
            'component': 'meter',
            'at': [1, 1],
            'meter': 'voltmeter',
            'from': [0, 0],
            'to': [2, 0],
          },
        ]),
      );
      expect(v.ok, isFalse);
      expect(
        v.errors.map((e) => e.message),
        contains('meter 图元不需要 from/to 字段。'),
      );
    });

    test('a resistor does not take at', () {
      final v = validateVisualScene(
        _circuitScene([
          _twoPoint(
            'r',
            'resistor',
            extra: {
              'at': [1, 1],
            },
          ),
        ]),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.message), contains('circuit 图元不需要 at 字段。'));
    });

    test('only a switch may carry closed=true', () {
      final v = validateVisualScene(
        _circuitScene([
          _twoPoint('r', 'resistor', extra: {'closed': true}),
        ]),
      );
      expect(v.ok, isFalse);
      expect(
        v.errors.map((e) => e.message),
        contains('只有 switch 图元能带 closed 字段。'),
      );
    });

    test('only a meter may carry a meter field', () {
      final v = validateVisualScene(
        _circuitScene([
          _twoPoint('bat', 'battery', extra: {'meter': 'voltmeter'}),
        ]),
      );
      expect(v.ok, isFalse);
      expect(
        v.errors.map((e) => e.message),
        contains('只有 meter 图元能带 meter 字段。'),
      );
    });

    test('an unknown component is rejected', () {
      final v = validateVisualScene(
        _circuitScene([_twoPoint('x', 'capacitor')]),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('invalid_value'));
    });
  });
}
