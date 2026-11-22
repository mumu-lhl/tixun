part of "visual_validation_test.dart";

void _visualDiagnosticCases() {
  group("validateVisualScene: resource limits", () {
    test("too many elements", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          for (var i = 0; i < 257; i++)
            {
              "id": "p$i",
              "type": "point",
              "at": [0, 0],
            },
        ],
      });
      expect(hasError(v, "limit_exceeded"), isTrue);
    });

    test("too many controls, tracks and steps", () {
      final controls = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "controls": [
          for (var i = 0; i < 13; i++)
            {"id": "t$i", "kind": "toggle", "label": "x", "value": true},
        ],
      });
      expect(hasError(controls, "limit_exceeded"), isTrue);

      final tracks = validateVisualScene({
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
            for (var i = 0; i < 33; i++)
              {
                "id": "t$i",
                "target": "a",
                "from": 0,
                "to": 1,
                "startMs": 0,
                "endMs": 10,
              },
          ],
        },
      });
      expect(hasError(tracks, "limit_exceeded"), isTrue);

      final steps = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "timeline": {
          "durationMs": 1000,
          "steps": [
            for (var i = 0; i < 31; i++) {"atMs": i},
          ],
        },
      });
      expect(hasError(steps, "limit_exceeded"), isTrue);
    });

    test("plot samples over the cap", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "elements": [
          {"id": "p", "type": "plot", "expression": "x", "samples": 4097},
        ],
      });
      expect(hasError(v, "invalid_range"), isTrue);
    });

    test("scene JSON over 64 KiB", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "title": "x" * 70000,
      });
      expect(hasError(v, "scene_too_large"), isTrue);
    });
  });

  group("validateVisualScene: warnings", () {
    test("view much larger than content", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "title": "t",
        "view": {
          "x": [-100, 100],
          "y": [-100, 100],
        },
        "elements": [
          {
            "id": "l",
            "type": "line",
            "p1": [0, 0],
            "p2": [1, 1],
          },
        ],
      });
      expect(v.ok, isTrue);
      expect(hasWarning(v, "view_much_larger_than_content"), isTrue);
    });

    test("element outside the view", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "title": "t",
        "view": {
          "x": [-1, 1],
          "y": [-1, 1],
        },
        "elements": [
          {
            "id": "p",
            "type": "point",
            "at": [5, 5],
          },
        ],
      });
      expect(v.ok, isTrue);
      expect(hasWarning(v, "element_outside_view"), isTrue);
    });

    test("steps out of order warn", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "title": "t",
        "timeline": {
          "durationMs": 1000,
          "steps": [
            {"atMs": 500},
            {"atMs": 100},
          ],
        },
      });
      expect(v.ok, isTrue);
      expect(hasWarning(v, "steps_out_of_order"), isTrue);
    });
  });

  group("validateVisualScene: limits are measured in UTF-8 bytes", () {
    test("a CJK-heavy scene counts bytes, not characters", () {
      final over = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "title": "汉" * 40000,
      });
      expect(hasError(over, "scene_too_large"), isTrue);

      final under = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "title": "汉" * 20000,
      });
      expect(hasError(under, "scene_too_large"), isFalse);
    });

    test("a missing samples count still renders at the default", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "elements": [
          {"id": "p", "type": "plot", "expression": "x"},
        ],
      });
      expect(v.ok, isTrue);
    });
  });

  group("validateVisualScene: a missing field reports once", () {
    test("point without at", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {"id": "p", "type": "point"},
        ],
      });
      final atErrors = v.errors.where((e) => e.path == "elements[0].at");
      expect(atErrors, hasLength(1));
      expect(atErrors.single.code, "missing_field");
    });

    test("circle without center, text without at", () {
      final circle = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {"id": "c", "type": "circle", "r": 1},
        ],
      });
      expect(
        circle.errors.where((e) => e.path == "elements[0].center"),
        hasLength(1),
      );
      final text = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {"id": "t", "type": "text", "text": "hi"},
        ],
      });
      expect(
        text.errors.where((e) => e.path == "elements[0].at"),
        hasLength(1),
      );
    });

    test("a malformed (non-null) point reports invalid_type once", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {"id": "p", "type": "point", "at": "o"},
        ],
      });
      expect(v.errors.where((e) => e.path == "elements[0].at"), hasLength(1));
      expect(v.errors.single.code, "invalid_type");
    });
  });

  group("validateVisualScene: curve finite-sample warnings", () {
    test("sqrt(x) on a negative domain has no finite samples", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "elements": [
          {
            "id": "p",
            "type": "plot",
            "expression": "sqrt(x)",
            "domain": [-3, -1],
          },
        ],
      });
      expect(v.ok, isTrue);
      expect(hasWarning(v, "curve_few_finite_samples"), isTrue);
    });

    test("x^2 on [-1, 1] has plenty of finite samples", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "elements": [
          {
            "id": "p",
            "type": "plot",
            "expression": "x^2",
            "domain": [-1, 1],
          },
        ],
      });
      expect(hasWarning(v, "curve_few_finite_samples"), isFalse);
    });

    test("a curve outside the view y-range warns", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "view": {
          "x": [-1, 1],
          "y": [5, 6],
        },
        "elements": [
          {
            "id": "p",
            "type": "plot",
            "expression": "x",
            "domain": [-1, 1],
          },
        ],
      });
      expect(hasWarning(v, "curve_few_finite_samples"), isTrue);
    });

    test("the model expression is probed too", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "model": {"expression": "sqrt(x)"},
        "view": {
          "x": [-3, -1],
        },
      });
      expect(hasWarning(v, "curve_few_finite_samples"), isTrue);
    });

    test("an unparseable expression warns about the error, not samples", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "elements": [
          {"id": "p", "type": "plot", "expression": "y"},
        ],
      });
      expect(hasError(v, "unknown_variable"), isTrue);
      expect(hasWarning(v, "curve_few_finite_samples"), isFalse);
    });
  });

  group("validateVisualScene: view warnings", () {
    test("element outside the view needs only one view axis", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "title": "t",
        "view": {
          "x": [-1, 1],
        },
        "elements": [
          {
            "id": "p",
            "type": "point",
            "at": [5, 0],
          },
        ],
      });
      expect(hasWarning(v, "element_outside_view"), isTrue);
    });

    test("a bound straddling the view edge warns", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "title": "t",
        "view": {
          "x": [-1, 1],
          "y": [-1, 1],
        },
        "elements": [
          {
            "id": "l",
            "type": "line",
            "p1": [0, 0],
            "p2": [5, 5],
          },
        ],
      });
      expect(hasWarning(v, "element_outside_view"), isTrue);
    });

    test("a single point still triggers much-larger", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "title": "t",
        "view": {
          "x": [-100, 100],
          "y": [-100, 100],
        },
        "elements": [
          {
            "id": "p",
            "type": "point",
            "at": [0, 0],
          },
        ],
      });
      expect(hasWarning(v, "view_much_larger_than_content"), isTrue);
    });

    test("a plot domain counts as content", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "title": "t",
        "view": {
          "x": [-100, 100],
        },
        "elements": [
          {
            "id": "p",
            "type": "plot",
            "expression": "x",
            "domain": [-10, 10],
          },
        ],
      });
      expect(hasWarning(v, "view_much_larger_than_content"), isTrue);
    });

    test("an annotation counts as content", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "title": "t",
        "view": {
          "x": [-100, 100],
          "y": [-100, 100],
        },
        "annotations": [
          {
            "at": [0, 0],
            "text": "here",
          },
        ],
      });
      expect(hasWarning(v, "view_much_larger_than_content"), isTrue);

      final outside = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "title": "t",
        "view": {
          "x": [-1, 1],
          "y": [-1, 1],
        },
        "annotations": [
          {
            "at": [5, 5],
            "text": "far",
          },
        ],
      });
      expect(hasWarning(outside, "element_outside_view"), isTrue);
    });
  });

  group("validateVisualScene: error codes distinguish the failure", () {
    test("annotation empty text is a value error", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "annotations": [
          {
            "at": [0, 0],
            "text": "",
          },
        ],
      });
      expect(hasError(v, "invalid_value"), isTrue);
      expect(hasError(v, "invalid_type"), isFalse);
    });

    test("a non-integer duration is a type error; zero is a range error", () {
      final wrongType = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "timeline": {"durationMs": 4000.0},
      });
      expect(hasError(wrongType, "invalid_type"), isTrue);
      expect(hasError(wrongType, "invalid_range"), isFalse);

      final zero = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "timeline": {"durationMs": 0},
      });
      expect(hasError(zero, "invalid_range"), isTrue);
    });

    test("track and step times split type from range", () {
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
              "startMs": 1.5,
              "endMs": -5,
            },
          ],
          "steps": [
            {"atMs": 2.5},
          ],
        },
      });
      expect(hasError(v, "invalid_type"), isTrue);
      expect(hasError(v, "invalid_range"), isTrue);
    });

    test("a track target that exists but is not a slider", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "controls": [
          {"id": "t", "kind": "toggle", "label": "T", "value": true},
        ],
        "timeline": {
          "durationMs": 1000,
          "tracks": [
            {
              "id": "t1",
              "target": "t",
              "from": 0,
              "to": 1,
              "startMs": 0,
              "endMs": 500,
            },
          ],
        },
      });
      expect(hasError(v, "invalid_track_target"), isTrue);
      expect(hasError(v, "unknown_control"), isFalse);
    });

    test("empty choice options is a value error", () {
      final empty = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "controls": [
          {
            "id": "c",
            "kind": "choice",
            "label": "C",
            "options": [],
            "value": "A",
          },
        ],
      });
      expect(hasError(empty, "invalid_value"), isTrue);

      final notAList = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "controls": [
          {
            "id": "c",
            "kind": "choice",
            "label": "C",
            "options": "A",
            "value": "A",
          },
        ],
      });
      expect(hasError(notAList, "invalid_type"), isTrue);
    });
  });

  group("validateVisualScene: computed stays empty by design", () {
    test("derived values are the tool layer’s job, not the validator’s", () {
      final v = validateVisualScene({"v": 1, "kind": "geometry"});
      expect(v.computed, isEmpty);
    });
  });
}
