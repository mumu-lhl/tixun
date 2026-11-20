part of "visual_constraints_test.dart";

void _constraintToleranceCases() {
  group("validateVisualScene: constraint tolerances and resolution", () {
    test("small-scale geometry is checked relatively, not against 1e-6", () {
      // At this scale a fixed absolute tolerance could hide a twofold error.
      Map<String, dynamic> tinyScene(double value) => {
        "v": 1,
        "kind": "geometry",
        "elements": [
          {
            "id": "A",
            "type": "point",
            "at": [0, 0],
          },
          {
            "id": "B",
            "type": "point",
            "at": [1e-9, 0],
          },
        ],
        "constraints": [
          {"type": "distance", "a": "A", "b": "B", "value": value},
        ],
      };
      expect(
        validateVisualScene(tinyScene(2e-9)).errors
            .any((e) => e.code == "constraint_violated"),
        isTrue,
      );
      expect(validateVisualScene(tinyScene(1e-9)).ok, isTrue);

      final circleOff = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {
            "id": "P",
            "type": "point",
            "at": [2e-9, 0],
          },
          {
            "id": "C",
            "type": "circle",
            "center": [0, 0],
            "r": 1e-9,
          },
        ],
        "constraints": [
          {"type": "on_circle", "point": "P", "circle": "C"},
        ],
      });
      expect(
        circleOff.errors.any((e) => e.code == "constraint_violated"),
        isTrue,
      );

      final midpointOff = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {
            "id": "A",
            "type": "point",
            "at": [0, 0],
          },
          {
            "id": "B",
            "type": "point",
            "at": [2e-9, 0],
          },
          {
            "id": "M",
            "type": "point",
            "at": [1e-9 + 5e-7, 0],
          },
        ],
        "constraints": [
          {"type": "midpoint", "point": "M", "a": "A", "b": "B"},
        ],
      });
      expect(
        midpointOff.errors.any((e) => e.code == "constraint_violated"),
        isTrue,
      );
    });

    test("extreme coordinate magnitudes do not overflow the distance", () {
      Map<String, dynamic> extremeScene(double coord, double value) => {
        "v": 1,
        "kind": "geometry",
        "elements": [
          {
            "id": "A",
            "type": "point",
            "at": [coord, 0],
          },
          {
            "id": "B",
            "type": "point",
            "at": [-coord, 0],
          },
        ],
        "constraints": [
          {"type": "distance", "a": "A", "b": "B", "value": value},
        ],
      };
      // dx*dx overflows at |dx| ~ 1e200; underflows to 0 at ~ 1e-200.
      expect(validateVisualScene(extremeScene(1e200, 2e200)).ok, isTrue);
      expect(validateVisualScene(extremeScene(1e-200, 2e-200)).ok, isTrue);
    });

    test("a point with missing geometry is recorded, not skipped", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {"id": "A", "type": "point"},
          {
            "id": "B",
            "type": "point",
            "at": [3, 0],
          },
        ],
        "constraints": [
          {"type": "distance", "a": "A", "b": "B", "value": 3},
        ],
      });
      expect(v.errors.any((e) => e.code == "unresolved_geometry"), isTrue);
    });

    test("only a real \$param binding counts as bound", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {
            "id": "P",
            "type": "point",
            "at": [
              {"foo": 1},
              0,
            ],
          },
          {
            "id": "Q",
            "type": "point",
            "at": [3, 0],
          },
        ],
        "constraints": [
          {"type": "distance", "a": "P", "b": "Q", "value": 3},
        ],
      });
      expect(v.errors.any((e) => e.code == "unresolved_geometry"), isTrue);
      expect(
        v.warnings.any((w) => w.code == "constraint_unverifiable"),
        isFalse,
      );
    });

    test("a duplicated id resolves to the first element", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {
            "id": "A",
            "type": "point",
            "at": [0, 0],
          },
          {
            "id": "A",
            "type": "point",
            "at": [10, 10],
          },
          {
            "id": "B",
            "type": "point",
            "at": [3, 0],
          },
        ],
        "constraints": [
          {"type": "distance", "a": "A", "b": "B", "value": 3},
        ],
      });
      expect(v.errors.any((e) => e.code == "duplicate_id"), isTrue);
      expect(v.errors.any((e) => e.code == "constraint_violated"), isFalse);
    });

    test("a malformed elements section skips constraint evaluation", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": "not-an-array",
        "constraints": [
          {"type": "distance", "a": "A", "b": "B", "value": 3},
        ],
      });
      expect(v.errors.any((e) => e.code == "invalid_type"), isTrue);
      expect(v.errors.any((e) => e.code == "unknown_element"), isFalse);
    });

    test("type-irrelevant constraint fields are rejected", () {
      final withValue = validateVisualScene(
        triangleJson(
          constraints: [
            {"type": "parallel", "a": "AB", "b": "DE", "value": 90},
          ],
        ),
      );
      expect(withValue.errors.any((e) => e.code == "unknown_field"), isTrue);

      final withId = validateVisualScene(
        triangleJson(
          constraints: [
            {"type": "on_circle", "point": "C", "circle": "circ", "a": "AB"},
          ],
        ),
      );
      expect(withId.errors.any((e) => e.code == "unknown_field"), isTrue);
    });
  });
}
