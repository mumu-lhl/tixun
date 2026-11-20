part of "visual_validation_test.dart";

void _visualExpressionCases() {
  group("validateVisualScene: expressions and references", () {
    test("expression parse failure", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "model": {"expression": "x^^2"},
      });
      expect(hasError(v, "expression_error"), isTrue);
    });

    test("unknown variable in model and plot expressions", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "model": {"expression": "y+1"},
        "elements": [
          {"id": "p", "type": "plot", "expression": "z*x"},
        ],
      });
      expect(v.errors.where((e) => e.code == "unknown_variable"), hasLength(2));
    });

    test("AST depth over 32 is an expression error", () {
      // A 33-term flat sum builds a left-deep tree of depth 33, so it
      // exceeds the AST depth limit even though it has no nesting.
      // (Parentheses alone do not count: 40 parens around a literal is
      // only one AST level deep.)
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "model": {"expression": List.filled(33, "1").join("+")},
      });
      expect(hasError(v, "expression_error"), isTrue);
    });

    test("unknown \$param binding", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {
            "id": "p",
            "type": "point",
            "at": [
              {r"$param": "missing"},
              0,
            ],
          },
        ],
      });
      expect(hasError(v, "unknown_parameter"), isTrue);
    });

    test("slider id must match a model parameter", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "controls": [
          {
            "id": "a",
            "kind": "slider",
            "label": "a",
            "min": 0,
            "max": 1,
            "step": 0.1,
            "value": 0.5,
          },
        ],
      });
      expect(hasError(v, "unknown_parameter"), isTrue);
    });

    test("slider range rules", () {
      Map<String, dynamic> sliderScene(Map<String, dynamic> slider) => {
        "v": 1,
        "kind": "plot2d",
        "model": {
          "parameters": {"a": 1},
        },
        "controls": [slider],
      };
      const base = {
        "id": "a",
        "kind": "slider",
        "label": "a",
        "min": 0,
        "max": 1,
        "step": 0.1,
        "value": 0.5,
      };
      expect(validateVisualScene(sliderScene(base)).ok, isTrue);
      expect(
        hasError(
          validateVisualScene(sliderScene({...base, "min": 2})),
          "invalid_range",
        ),
        isTrue,
      );
      expect(
        hasError(
          validateVisualScene(sliderScene({...base, "step": 0})),
          "invalid_range",
        ),
        isTrue,
      );
      expect(
        hasError(
          validateVisualScene(sliderScene({...base, "value": 2})),
          "invalid_range",
        ),
        isTrue,
      );
    });

    test("choice value must be one of the options", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "controls": [
          {
            "id": "m",
            "kind": "choice",
            "label": "情形",
            "options": ["A", "B"],
            "value": "C",
          },
        ],
      });
      expect(hasError(v, "invalid_value"), isTrue);
    });

    test("visibleWhen must reference a toggle control", () {
      final missing = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {
            "id": "l",
            "type": "line",
            "p1": [0, 0],
            "p2": [1, 1],
            "visibleWhen": {"control": "nope", "equals": true},
          },
        ],
      });
      expect(hasError(missing, "unknown_control"), isTrue);

      final wrongKind = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "model": {
          "parameters": {"a": 1},
        },
        "controls": [
          {
            "id": "a",
            "kind": "slider",
            "label": "a",
            "min": 0,
            "max": 1,
            "step": 0.1,
            "value": 0.5,
          },
        ],
        "elements": [
          {
            "id": "l",
            "type": "line",
            "p1": [0, 0],
            "p2": [1, 1],
            "visibleWhen": {"control": "a", "equals": true},
          },
        ],
      });
      expect(hasError(wrongKind, "invalid_control_kind"), isTrue);
    });

    test("timeline references", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "timeline": {
          "durationMs": 1000,
          "tracks": [
            {
              "id": "t1",
              "target": "ghost",
              "from": 0,
              "to": 1,
              "startMs": 0,
              "endMs": 500,
            },
          ],
          "steps": [
            {
              "atMs": 2000,
              "show": ["ghost"],
            },
          ],
        },
      });
      expect(hasError(v, "unknown_control"), isTrue); // ghost target
      expect(hasError(v, "invalid_range"), isTrue); // atMs out of range
      expect(hasError(v, "unknown_element_reference"), isTrue);
    });

    test("track window must be inside the duration", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "model": {
          "parameters": {"a": 1},
        },
        "controls": [
          {
            "id": "a",
            "kind": "slider",
            "label": "a",
            "min": 0,
            "max": 1,
            "step": 0.1,
            "value": 0.5,
          },
        ],
        "timeline": {
          "durationMs": 1000,
          "tracks": [
            {
              "id": "t1",
              "target": "a",
              "from": 0,
              "to": 1,
              "startMs": 800,
              "endMs": 800,
            },
          ],
        },
      });
      expect(hasError(v, "invalid_range"), isTrue);
    });
  });

  group("validateVisualScene: lazy unknown-variable checks", () {
    test("a dead if branch is not reported", () {
      final dead = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "model": {
          "expression": "if(a==0, 0, y)",
          "parameters": {"a": 0},
        },
      });
      expect(dead.ok, isTrue);

      final live = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "model": {
          "expression": "if(a==0, 0, y)",
          "parameters": {"a": 1},
        },
      });
      expect(hasError(live, "unknown_variable"), isTrue);
    });

    test("a non-foldable condition keeps both branches live", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "model": {"expression": "if(x==0, 0, y)"},
      });
      expect(hasError(v, "unknown_variable"), isTrue);
    });

    test("a literal condition folds the dead branch away", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "model": {"expression": "if(1, 0, y)"},
      });
      expect(v.ok, isTrue);
    });
  });

  group("validateVisualScene: visibleWhen requires equals", () {
    test("missing equals is a missing-field error", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "controls": [
          {"id": "t", "kind": "toggle", "label": "T", "value": true},
        ],
        "elements": [
          {
            "id": "l",
            "type": "line",
            "p1": [0, 0],
            "p2": [1, 1],
            "visibleWhen": {"control": "t"},
          },
        ],
      });
      expect(hasError(v, "missing_field"), isTrue);
      expect(
        v.errors.any((e) => e.path == "elements[0].visibleWhen.equals"),
        isTrue,
      );
    });

    test("equals present is accepted", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "controls": [
          {"id": "t", "kind": "toggle", "label": "T", "value": true},
        ],
        "elements": [
          {
            "id": "l",
            "type": "line",
            "p1": [0, 0],
            "p2": [1, 1],
            "visibleWhen": {"control": "t", "equals": false},
          },
        ],
      });
      expect(v.ok, isTrue);
    });
  });
}
