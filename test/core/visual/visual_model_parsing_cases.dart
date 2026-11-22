part of "visual_model_test.dart";

void _visualParsingCases() {
  group("VisualScene.fromJson rejects malformed input", () {
    test("unknown top-level field", () {
      expect(
        () =>
            VisualScene.fromJson({"v": 1, "kind": "plot2d", "surprise": true}),
        throwsA(isA<AppFormatException>()),
      );
    });

    test("unknown fields at every nested level", () {
      final cases = <Map<String, dynamic>>[
        {
          "v": 1,
          "kind": "plot2d",
          "model": {"expression": "x", "nope": 1},
        },
        {
          "v": 1,
          "kind": "plot2d",
          "view": {
            "x": [-1, 1],
            "nope": 1,
          },
        },
        {
          "v": 1,
          "kind": "plot2d",
          "meta": {"alt": "x", "nope": 1},
        },
        {
          "v": 1,
          "kind": "plot2d",
          "annotations": [
            {
              "at": [0, 0],
              "text": "t",
              "nope": 1,
            },
          ],
        },
        {
          "v": 1,
          "kind": "plot2d",
          "elements": [
            {
              "id": "p",
              "type": "point",
              "at": [0, 0],
              "nope": 1,
            },
          ],
        },
        {
          "v": 1,
          "kind": "plot2d",
          "elements": [
            {
              "id": "l",
              "type": "line",
              "p1": [0, 0],
              "p2": [1, 1],
              "visibleWhen": {"control": "c", "equals": true, "nope": 1},
            },
          ],
        },
        {
          "v": 1,
          "kind": "plot2d",
          "controls": [
            {
              "id": "a",
              "kind": "toggle",
              "label": "x",
              "value": true,
              "nope": 1,
            },
          ],
        },
        {
          "v": 1,
          "kind": "plot2d",
          "timeline": {"durationMs": 100, "nope": 1},
        },
        {
          "v": 1,
          "kind": "plot2d",
          "timeline": {
            "durationMs": 100,
            "tracks": [
              {
                "id": "t",
                "target": "a",
                "from": 0,
                "to": 1,
                "startMs": 0,
                "endMs": 10,
                "nope": 1,
              },
            ],
          },
        },
        {
          "v": 1,
          "kind": "plot2d",
          "timeline": {
            "durationMs": 100,
            "steps": [
              {"atMs": 0, "nope": 1},
            ],
          },
        },
        {
          "v": 1,
          "kind": "geometry",
          "elements": [
            {
              "id": "p",
              "type": "point",
              "at": [
                {r"$param": "a", "nope": 1},
                0,
              ],
            },
          ],
        },
      ];
      for (final json in cases) {
        expect(
          () => VisualScene.fromJson(json),
          throwsA(isA<AppFormatException>()),
          reason: "expected $json to fail",
        );
      }
    });

    test("missing required fields", () {
      expect(
        () => VisualScene.fromJson({}),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualScene.fromJson({"kind": "plot2d"}),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualScene.fromJson({"v": 1}),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualScene.fromJson({
          "v": 1,
          "kind": "geometry",
          "elements": [
            {
              "type": "point",
              "at": [0, 0],
            },
          ],
        }),
        throwsA(isA<AppFormatException>()),
      );
    });

    test("wrong JSON types throw AppFormatException, not TypeError", () {
      final cases = <Map<String, dynamic>>[
        {"v": 1, "kind": 123},
        {
          "v": 1,
          "kind": "plot2d",
          "elements": {"id": "x"},
        },
        {"v": 1, "kind": "plot2d", "model": "x"},
        {
          "v": 1,
          "kind": "geometry",
          "elements": [
            {"id": "p", "type": "point", "at": "origin"},
          ],
        },
        {
          "v": 1,
          "kind": "geometry",
          "elements": [
            {
              "id": "p",
              "type": "point",
              "at": [0, 0],
              "dashed": "yes",
            },
          ],
        },
        {
          "v": 1,
          "kind": "geometry",
          "elements": [
            {
              "id": "c",
              "type": "circle",
              "center": [0, 0],
              "r": "big",
            },
          ],
        },
      ];
      for (final json in cases) {
        expect(
          () => VisualScene.fromJson(json),
          throwsA(isA<AppFormatException>()),
          reason: "expected $json to fail with AppFormatException",
        );
      }
    });

    test("duplicate element ids (including inside groups)", () {
      expect(
        () => VisualScene.fromJson({
          "v": 1,
          "kind": "geometry",
          "elements": [
            {
              "id": "p",
              "type": "point",
              "at": [0, 0],
            },
            {
              "id": "p",
              "type": "point",
              "at": [1, 1],
            },
          ],
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualScene.fromJson({
          "v": 1,
          "kind": "geometry",
          "elements": [
            {
              "id": "g",
              "type": "group",
              "children": [
                {
                  "id": "p",
                  "type": "point",
                  "at": [0, 0],
                },
                {
                  "id": "p",
                  "type": "point",
                  "at": [1, 1],
                },
              ],
            },
          ],
        }),
        throwsA(isA<AppFormatException>()),
      );
    });

    test("bad ranges and counts", () {
      final cases = <Map<String, dynamic>>[
        {
          "v": 1,
          "kind": "geometry",
          "elements": [
            {
              "id": "c",
              "type": "circle",
              "center": [0, 0],
              "r": 0,
            },
          ],
        },
        {
          "v": 1,
          "kind": "geometry",
          "elements": [
            {
              "id": "a",
              "type": "arc",
              "center": [0, 0],
              "r": 1,
              "startDeg": 0,
              "sweepDeg": 0,
            },
          ],
        },
        {
          "v": 1,
          "kind": "geometry",
          "elements": [
            {
              "id": "l",
              "type": "polyline",
              "points": [
                [0, 0],
              ],
            },
          ],
        },
        {
          "v": 1,
          "kind": "geometry",
          "elements": [
            {
              "id": "p",
              "type": "polygon",
              "points": [
                [0, 0],
                [1, 1],
              ],
            },
          ],
        },
        {
          "v": 1,
          "kind": "geometry",
          "elements": [
            {"id": "g", "type": "group", "children": []},
          ],
        },
      ];
      for (final json in cases) {
        expect(
          () => VisualScene.fromJson(json),
          throwsA(isA<AppFormatException>()),
          reason: "expected $json to fail",
        );
      }
    });

    test("group nesting deeper than 4 is rejected; depth 4 is allowed", () {
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

      expect(
        () => VisualScene.fromJson({
          "v": 1,
          "kind": "geometry",
          "elements": [nestedGroup(4)],
        }),
        returnsNormally,
      );
      expect(
        () => VisualScene.fromJson({
          "v": 1,
          "kind": "geometry",
          "elements": [nestedGroup(5)],
        }),
        throwsA(isA<AppFormatException>()),
      );
    });

    test("unknown element type and kind", () {
      expect(
        () => VisualScene.fromJson({
          "v": 1,
          "kind": "geometry",
          "elements": [
            {
              "id": "x",
              "type": "star",
              "at": [0, 0],
            },
          ],
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualScene.fromJson({"v": 1, "kind": "hologram"}),
        throwsA(isA<AppFormatException>()),
      );
    });
  });

  group("VisualScene.fromJson maps the first error to a specific code", () {
    AppErrorCode codeOf(Map<String, dynamic> json) {
      try {
        VisualScene.fromJson(json);
      } on AppFormatException catch (e) {
        return e.code;
      }
      fail("expected AppFormatException for $json");
    }

    List<String> argumentsOf(Map<String, dynamic> json) {
      try {
        VisualScene.fromJson(json);
      } on AppFormatException catch (e) {
        return e.arguments;
      }
      fail("expected AppFormatException for $json");
    }

    test("text-expected and number-expected types split", () {
      expect(
        codeOf({"v": 1, "kind": "geometry", "title": 123}),
        AppErrorCode.errorParameterMustBeText,
      );
      expect(argumentsOf({"v": 1, "kind": "geometry", "title": 123}), [
        "title",
      ]);
      expect(
        codeOf({
          "v": 1,
          "kind": "plot2d",
          "timeline": {"durationMs": 4000.0},
        }),
        AppErrorCode.errorParameterMustBeNumber,
      );
    });

    test("unknown and missing fields keep their codes", () {
      expect(
        codeOf({"v": 1, "kind": "plot2d", "surprise": true}),
        AppErrorCode.errorUnknownParameter,
      );
      expect(codeOf({"v": 1}), AppErrorCode.errorMissingParameter);
    });

    test("range, expression and kind failures stay generic", () {
      expect(
        codeOf({
          "v": 1,
          "kind": "plot2d",
          "model": {"expression": "2+"},
        }),
        AppErrorCode.errorInvalidParameterType,
      );
      expect(
        codeOf({"v": 1, "kind": "hologram"}),
        AppErrorCode.errorInvalidParameterType,
      );
    });
  });

  group("VisualScene.fromJson / toJson minimal normalization", () {
    test("integer literals normalize to doubles in toJson", () {
      final scene = VisualScene.fromJson({
        "v": 1,
        "kind": "plot2d",
        "model": {
          "expression": "x^2",
          "parameters": {"a": 1},
        },
        "view": {
          "x": [-3, 6],
        },
      });
      final json = scene.toJson();
      expect((json["model"] as Map)["parameters"], {"a": 1.0});
      expect((json["view"] as Map)["x"], [-3.0, 6.0]);
      expect(VisualScene.fromJson(json).toJson(), json);
    });

    test("absent showAxes stays null and is omitted from toJson", () {
      final scene = VisualScene.fromJson({
        "v": 1,
        "kind": "plot2d",
        "model": {"expression": "x"},
      });
      expect(scene.model?.showAxes, isNull);
      expect((scene.toJson()["model"] as Map).containsKey("showAxes"), isFalse);
      expect(VisualScene.fromJson(scene.toJson()).model?.showAxes, isNull);

      final withAxes = VisualScene.fromJson({
        "v": 1,
        "kind": "plot2d",
        "model": {"expression": "x", "showAxes": true},
      });
      expect(withAxes.model?.showAxes, isTrue);
      expect((withAxes.toJson()["model"] as Map)["showAxes"], isTrue);
    });

    test("a step without show/hide normalizes to empty lists", () {
      final scene = VisualScene.fromJson({
        "v": 1,
        "kind": "plot2d",
        "timeline": {
          "durationMs": 1000,
          "steps": [
            {"atMs": 100},
          ],
        },
      });
      final stepJson =
          ((scene.toJson()["timeline"] as Map)["steps"] as List).single
              as Map<String, dynamic>;
      expect(stepJson["show"], isEmpty);
      expect(stepJson["hide"], isEmpty);
      expect(VisualScene.fromJson(scene.toJson()).toJson(), scene.toJson());
    });
  });
}
