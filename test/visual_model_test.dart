import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/l10n/app_error.dart";
import "package:tixun/core/visual/model/visual_scene.dart";

part "visual_model_parsing_cases.dart";

Map<String, dynamic> fullSceneJson() => {
  "v": 1,
  "kind": "plot2d",
  "title": "二次函数",
  "model": {
    "expression": "x^2-4",
    "parameters": {"a": 1},
  },
  "view": {
    "x": [-3, 3],
    "y": [-5, 6],
  },
  "elements": [
    {
      "id": "e1",
      "type": "point",
      "at": [0, -4],
      "label": "顶点",
    },
    {
      "id": "e2",
      "type": "line",
      "p1": [-3, 5],
      "p2": [3, 5],
      "dashed": true,
    },
    {
      "id": "e3",
      "type": "polyline",
      "points": [
        [0, 0],
        [1, 1],
        [2, 0],
      ],
    },
    {
      "id": "e4",
      "type": "polygon",
      "points": [
        [0, 0],
        [1, 0],
        [0, 1],
      ],
      "fill": true,
    },
    {
      "id": "e5",
      "type": "circle",
      "center": [0, 0],
      "r": 2,
    },
    {
      "id": "e6",
      "type": "arc",
      "center": [0, 0],
      "r": 1,
      "startDeg": 0,
      "sweepDeg": 90,
    },
    {
      "id": "e7",
      "type": "arrow",
      "from": [0, 0],
      "to": [1, 2],
    },
    {
      "id": "e8",
      "type": "text",
      "at": [1, 1],
      "text": "交点",
    },
    {
      "id": "e9",
      "type": "math_label",
      "at": [2, 0],
      "tex": r"x^2-4",
    },
    {
      "id": "e10",
      "type": "group",
      "children": [
        {
          "id": "e11",
          "type": "point",
          "at": [1, 1],
        },
      ],
    },
    {
      "id": "e12",
      "type": "plot",
      "expression": "a*x^2-4",
      "domain": [-3, 3],
      "samples": 512,
    },
  ],
  "controls": [
    {
      "id": "a",
      "kind": "slider",
      "label": "a",
      "min": -3,
      "max": 3,
      "step": 0.1,
      "value": 1,
    },
    {"id": "showAux", "kind": "toggle", "label": "显示辅助线", "value": true},
    {
      "id": "mode",
      "kind": "choice",
      "label": "情形",
      "options": ["A", "B"],
      "value": "A",
    },
  ],
  "timeline": {
    "durationMs": 4000,
    "tracks": [
      {
        "id": "t1",
        "target": "a",
        "from": 1,
        "to": 3,
        "startMs": 0,
        "endMs": 4000,
      },
    ],
    "steps": [
      {
        "atMs": 0,
        "show": ["e1"],
        "hide": [],
        "note": "画坐标轴",
      },
    ],
  },
  "annotations": [
    {
      "at": [0, 0],
      "text": "顶点",
    },
  ],
  "meta": {"alt": "抛物线 y=x^2-4 的图像"},
};

void main() {
  group("VisualScene.fromJson / toJson", () {
    test("round-trip preserves the scene", () {
      final scene = VisualScene.fromJson(fullSceneJson());
      expect(scene.kind, VisualSceneKind.plot2d);
      expect(scene.title, "二次函数");
      expect(scene.model?.expression, "x^2-4");
      expect(scene.model?.parameters, {"a": 1.0});
      expect(scene.view?.x?.min, -3);
      expect(scene.view?.y?.max, 6);
      expect(scene.elements, hasLength(11));
      expect(scene.allElementIds, hasLength(12));
      expect(scene.controls, hasLength(3));
      expect(scene.controls.first, isA<SliderControl>());
      expect(scene.controls[1], isA<ToggleControl>());
      expect(scene.controls[2], isA<ChoiceControl>());
      expect(scene.timeline?.durationMs, 4000);
      expect(scene.timeline?.tracks, hasLength(1));
      expect(scene.timeline?.steps, hasLength(1));
      expect(scene.annotations, hasLength(1));
      expect(scene.meta?.alt, "抛物线 y=x^2-4 的图像");

      final again = VisualScene.fromJson(scene.toJson());
      expect(again.toJson(), scene.toJson());
    });

    test("minimal scene round-trips", () {
      final scene = VisualScene.fromJson({"v": 1, "kind": "geometry"});
      expect(scene.kind, VisualSceneKind.geometry);
      expect(scene.elements, isEmpty);
      expect(scene.controls, isEmpty);
      expect(scene.toJson(), {"v": 1, "kind": "geometry"});
      expect(
        VisualScene.fromJson(scene.toJson()).kind,
        VisualSceneKind.geometry,
      );
    });

    test("all element types parse with expected fields", () {
      final scene = VisualScene.fromJson(fullSceneJson());
      final byId = {for (final e in scene.elements) e.id: e};
      expect((byId["e1"] as PointElement).label, "顶点");
      expect((byId["e2"] as LineElement).dashed, isTrue);
      expect((byId["e3"] as PolylineElement).points, hasLength(3));
      expect((byId["e4"] as PolygonElement).fill, isTrue);
      expect((byId["e5"] as CircleElement).r, 2);
      expect((byId["e6"] as ArcElement).sweepDeg, 90);
      expect((byId["e7"] as ArrowElement).to.literal, (1.0, 2.0));
      expect((byId["e8"] as TextElement).text, "交点");
      expect((byId["e9"] as MathLabelElement).tex, r"x^2-4");
      expect((byId["e10"] as GroupElement).children, hasLength(1));
      expect((byId["e12"] as PlotElement).samples, 512);
      expect((byId["e12"] as PlotElement).domain, (-3.0, 3.0));
    });

    test(r"$param coordinate bindings parse and round-trip", () {
      final scene = VisualScene.fromJson({
        "v": 1,
        "kind": "geometry",
        "model": {
          "parameters": {"a": 2},
        },
        "elements": [
          {
            "id": "p1",
            "type": "point",
            "at": [
              {r"$param": "a"},
              3,
            ],
          },
        ],
      });
      final point = (scene.elements.single as PointElement).at;
      expect(point.x.isParam, isTrue);
      expect(point.x.param, "a");
      expect(point.y.literalValue, 3);
      expect(
        VisualScene.fromJson(scene.toJson()).elements.single,
        isA<PointElement>(),
      );
      final reparsed =
          (VisualScene.fromJson(scene.toJson()).elements.single as PointElement)
              .at;
      expect(reparsed.x.param, "a");
    });

    test("element defaults: primary style, layer 0, visible", () {
      final scene = VisualScene.fromJson({
        "v": 1,
        "kind": "geometry",
        "elements": [
          {
            "id": "p",
            "type": "point",
            "at": [0, 0],
          },
        ],
      });
      final element = scene.elements.single;
      expect(element.style, VisualStyle.primary);
      expect(element.layer, 0);
      expect(element.visible, isTrue);
      expect(element.visibleWhen, isNull);
    });

    test("visibleWhen gate parses", () {
      final scene = VisualScene.fromJson({
        "v": 1,
        "kind": "geometry",
        "controls": [
          {"id": "showAux", "kind": "toggle", "label": "辅助线", "value": true},
        ],
        "elements": [
          {
            "id": "l",
            "type": "line",
            "p1": [0, 0],
            "p2": [1, 1],
            "visibleWhen": {"control": "showAux", "equals": true},
          },
        ],
      });
      final element = scene.elements.single;
      expect(element.visibleWhen?.control, "showAux");
      expect(element.visibleWhen?.equals, isTrue);
    });
  });

  _visualParsingCases();

  group("model fromJson semantic guards (direct calls, no validator)", () {
    test("circle and arc radii, sweep, point counts", () {
      for (final element in <Map<String, dynamic>>[
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
          "id": "a",
          "type": "arc",
          "center": [0, 0],
          "r": 0,
          "startDeg": 0,
          "sweepDeg": 90,
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
          "id": "t",
          "type": "text",
          "at": [0, 0],
          "text": "x" * 501,
        },
        {
          "id": "m",
          "type": "math_label",
          "at": [0, 0],
          "tex": "",
        },
      ]) {
        expect(
          () => VisualElement.fromJson(element),
          throwsA(isA<AppFormatException>()),
          reason: "expected $element to fail",
        );
      }
    });

    test("plot domain and samples", () {
      for (final element in <Map<String, dynamic>>[
        {
          "id": "p",
          "type": "plot",
          "expression": "x",
          "domain": [5, 5],
        },
        {
          "id": "p",
          "type": "plot",
          "expression": "x",
          "domain": [5, 1],
        },
        {"id": "p", "type": "plot", "expression": "x", "samples": 0},
        {"id": "p", "type": "plot", "expression": "x", "samples": 4097},
      ]) {
        expect(
          () => VisualElement.fromJson(element),
          throwsA(isA<AppFormatException>()),
          reason: "expected $element to fail",
        );
      }
      expect(
        VisualElement.fromJson({
          "id": "p",
          "type": "plot",
          "expression": "x",
          "domain": [-1, 1],
          "samples": 4096,
        }),
        isA<PlotElement>(),
      );
    });

    test("circuit field mutual-exclusion", () {
      for (final element in <Map<String, dynamic>>[
        {
          "id": "m",
          "type": "circuit",
          "component": "meter",
          "at": [0, 0],
          "meter": "ammeter",
          "from": [0, 0],
        },
        {
          "id": "b",
          "type": "circuit",
          "component": "battery",
          "from": [0, 0],
          "to": [1, 0],
          "at": [0, 0],
        },
        {
          "id": "b",
          "type": "circuit",
          "component": "battery",
          "from": [0, 0],
          "to": [1, 0],
          "meter": "ammeter",
        },
        {
          "id": "b",
          "type": "circuit",
          "component": "battery",
          "from": [0, 0],
          "to": [1, 0],
          "closed": true,
        },
        {
          "id": "m",
          "type": "circuit",
          "component": "meter",
          "at": [0, 0],
          "meter": "ammeter",
          "closed": true,
        },
      ]) {
        expect(
          () => VisualElement.fromJson(element),
          throwsA(isA<AppFormatException>()),
          reason: "expected $element to fail",
        );
      }
      expect(
        VisualElement.fromJson({
          "id": "s",
          "type": "circuit",
          "component": "switch",
          "from": [0, 0],
          "to": [1, 0],
          "closed": true,
        }),
        isA<CircuitElement>(),
      );
    });

    test("ranges, sliders, tracks, steps and timelines", () {
      expect(
        () => VisualRange.fromJson([5, 5]),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualRange.fromJson([5, 1]),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualRange.fromJson([0, 2e9]),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualControl.fromJson({
          "id": "s",
          "kind": "slider",
          "label": "S",
          "min": 2,
          "max": 1,
          "step": 0.1,
          "value": 1.5,
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualControl.fromJson({
          "id": "s",
          "kind": "slider",
          "label": "S",
          "min": 0,
          "max": 1,
          "step": 0,
          "value": 0.5,
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualControl.fromJson({
          "id": "s",
          "kind": "slider",
          "label": "S",
          "min": 0,
          "max": 1,
          "step": 0.1,
          "value": 2,
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualControl.fromJson({
          "id": "c",
          "kind": "choice",
          "label": "C",
          "options": [],
          "value": "A",
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualControl.fromJson({
          "id": "c",
          "kind": "choice",
          "label": "C",
          "options": ["A"],
          "value": "B",
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualTrack.fromJson({
          "id": "t",
          "target": "s",
          "from": 0,
          "to": 1,
          "startMs": 500,
          "endMs": 500,
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualTrack.fromJson({
          "id": "t",
          "target": "s",
          "from": 0,
          "to": 1,
          "startMs": -1,
          "endMs": 500,
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualStep.fromJson({"atMs": -1}),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualTimeline.fromJson({"durationMs": 0}),
        throwsA(isA<AppFormatException>()),
      );
    });
  });
}
