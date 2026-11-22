import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/visual/validation/visual_validator.dart";

part "visual_validation_expression_cases.dart";
part "visual_validation_diagnostic_cases.dart";

Map<String, dynamic> validPlotScene() => {
  "v": 1,
  "kind": "plot2d",
  "title": "二次函数",
  "model": {"expression": "x^2-4"},
  "view": {
    "x": [-3, 3],
    "y": [-5, 6],
  },
  "elements": [
    {
      "id": "p",
      "type": "point",
      "at": [0, -4],
    },
  ],
};

bool hasError(VisualValidation v, String code) =>
    v.errors.any((e) => e.code == code);

bool hasWarning(VisualValidation v, String code) =>
    v.warnings.any((w) => w.code == code);

void main() {
  group("validateVisualScene: valid scenes", () {
    test("valid plot2d scene is ok and verified", () {
      final v = validateVisualScene(validPlotScene());
      expect(v.ok, isTrue);
      expect(v.errors, isEmpty);
      expect(v.verificationStatus, "verified");
      expect(v.computed, isEmpty);
    });

    test("parameterized expression is ok when the parameter exists", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "plot2d",
        "title": "t",
        "model": {
          "expression": "a*x^2",
          "parameters": {"a": 2},
        },
      });
      expect(v.ok, isTrue);
      expect(v.verificationStatus, "verified");
    });

    test("schematic meta yields schematic status", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "physics",
        "title": "斜面受力",
        "meta": {"alt": "斜面示意图", "schematic": true},
        "elements": [
          {
            "id": "b",
            "type": "polygon",
            "points": [
              [0, 0],
              [4, 0],
              [0, 2],
            ],
          },
        ],
      });
      expect(v.ok, isTrue);
      expect(hasWarning(v, "schematic_content"), isTrue);
      expect(v.verificationStatus, "schematic");
    });

    test("missing title and alt is a warning, not an error", () {
      final v = validateVisualScene({"v": 1, "kind": "geometry"});
      expect(v.ok, isTrue);
      expect(hasWarning(v, "missing_accessibility_text"), isTrue);
      expect(v.verificationStatus, "verified");
    });
  });

  group("validateVisualScene: structural errors", () {
    test("empty scene reports missing v and kind", () {
      final v = validateVisualScene({});
      expect(v.ok, isFalse);
      expect(v.verificationStatus, "unverified");
      expect(hasError(v, "missing_field"), isTrue);
    });

    test("unknown top-level field", () {
      final v = validateVisualScene({"v": 1, "kind": "plot2d", "surprise": 1});
      expect(hasError(v, "unknown_field"), isTrue);
      expect(
        v.errors.firstWhere((e) => e.code == "unknown_field").path,
        "surprise",
      );
    });

    test("unsupported version", () {
      expect(
        hasError(
          validateVisualScene({"v": 2, "kind": "plot2d"}),
          "unsupported_version",
        ),
        isTrue,
      );
      expect(
        hasError(
          validateVisualScene({"v": "1", "kind": "plot2d"}),
          "unsupported_version",
        ),
        isTrue,
      );
    });

    test("unknown kind and element type", () {
      expect(
        hasError(
          validateVisualScene({"v": 1, "kind": "hologram"}),
          "unknown_kind",
        ),
        isTrue,
      );
      expect(
        hasError(
          validateVisualScene({
            "v": 1,
            "kind": "geometry",
            "elements": [
              {"id": "x", "type": "star"},
            ],
          }),
          "unknown_element_type",
        ),
        isTrue,
      );
    });

    test("duplicate element and control ids", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {
            "id": "p",
            "type": "point",
            "at": [0, 0],
          },
          {
            "id": "g",
            "type": "group",
            "children": [
              {
                "id": "p",
                "type": "point",
                "at": [1, 1],
              },
            ],
          },
        ],
        "controls": [
          {"id": "t", "kind": "toggle", "label": "x", "value": true},
          {"id": "t", "kind": "toggle", "label": "y", "value": false},
        ],
      });
      expect(v.errors.where((e) => e.code == "duplicate_id"), hasLength(2));
    });

    test("bad view ranges", () {
      final cases = <(Map<String, dynamic>, String)>[
        (
          {
            "x": [3, -3],
          },
          "invalid_range",
        ),
        (
          {
            "x": [0, 0],
          },
          "invalid_range",
        ),
        (
          {
            "x": [-1e10, 1e10],
          },
          "invalid_range",
        ),
        (
          {
            "x": [0],
          },
          "invalid_type",
        ),
        (
          {
            "y": ["a", 1],
          },
          "invalid_type",
        ),
      ];
      for (final (view, code) in cases) {
        expect(
          hasError(
            validateVisualScene({"v": 1, "kind": "plot2d", "view": view}),
            code,
          ),
          isTrue,
          reason: "expected $view to fail with $code",
        );
      }
    });

    test("bad element ranges", () {
      final cases = <Map<String, dynamic>>[
        {
          "id": "c",
          "type": "circle",
          "center": [0, 0],
          "r": 0,
        },
        {
          "id": "c",
          "type": "circle",
          "center": [0, 0],
          "r": -1,
        },
        {
          "id": "a",
          "type": "arc",
          "center": [0, 0],
          "r": 1,
          "startDeg": 0,
          "sweepDeg": 0,
        },
        {
          "id": "l",
          "type": "polyline",
          "points": [
            [0, 0],
          ],
        },
        {
          "id": "p",
          "type": "polygon",
          "points": [
            [0, 0],
            [1, 1],
          ],
        },
        {"id": "g", "type": "group", "children": []},
        {
          "id": "t",
          "type": "text",
          "at": [0, 0],
          "text": "",
        },
        {
          "id": "m",
          "type": "math_label",
          "at": [0, 0],
          "tex": "x" * 501,
        },
      ];
      for (final element in cases) {
        final v = validateVisualScene({
          "v": 1,
          "kind": "geometry",
          "elements": [element],
        });
        expect(v.ok, isFalse, reason: "expected $element to fail");
      }
    });

    test("missing required fields", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {
            "type": "point",
            "at": [0, 0],
          },
          {
            "id": "c",
            "type": "circle",
            "center": [0, 0],
          },
          {
            "id": "l",
            "type": "line",
            "p1": [0, 0],
          },
        ],
      });
      expect(v.errors.where((e) => e.code == "missing_field").length, 3);
    });
  });

  _visualExpressionCases();

  _visualDiagnosticCases();

  group("validateVisualScene: malformed input never throws", () {
    test("wrong types everywhere produce issues, not exceptions", () {
      final v = validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "model": "x",
        "view": [1, 2],
        "elements": [
          {"id": 1, "type": 2},
          "not-a-map",
          {"id": "c", "type": "circle", "center": "o", "r": "big"},
          {"id": "g", "type": "group", "children": "nope"},
        ],
        "controls": "nope",
        "timeline": 42,
        "annotations": [
          {"at": "x"},
        ],
        "meta": ["alt"],
      });
      expect(v.ok, isFalse);
      expect(v.errors, isNotEmpty);
      expect(v.verificationStatus, "unverified");
    });

    test(
      "deeply nested groups report an error instead of recursing forever",
      () {
        Map<String, dynamic> nestedGroup(int depth) {
          if (depth == 0) {
            return {
              "id": "leaf",
              "type": "point",
              "at": [0, 0],
            };
          }
          return {
            "id": "g$depth",
            "type": "group",
            "children": [nestedGroup(depth - 1)],
          };
        }

        final v = validateVisualScene({
          "v": 1,
          "kind": "geometry",
          "elements": [nestedGroup(50)],
        });
        expect(v.ok, isFalse);
        expect(v.errors.any((e) => e.message.contains("嵌套过深")), isTrue);
      },
    );
  });
}
