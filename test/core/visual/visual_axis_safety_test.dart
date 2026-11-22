import "dart:ui" as ui;

import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/visual/model/visual_scene.dart";
import "package:tixun/core/visual/render/visual_painter.dart";
import "package:tixun/core/visual/render/visual_theme.dart";
import "package:tixun/core/visual/validation/visual_validator.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final axis in ["x", "y"]) {
    for (final min in [1e16, -1e16]) {
      test(
        "$axis range at $min rejects insufficient precision and paints defensively",
        () {
          final range = [min, min + 2];
          final json = <String, dynamic>{
            "v": 1,
            "kind": "geometry",
            "view": {
              "x": axis == "x" ? range : [-5, 5],
              "y": axis == "y" ? range : [-5, 5],
            },
            "meta": {"alt": "Large offset"},
          };
          expect(validateVisualScene(json).ok, isFalse);
          // Directly constructed/legacy scenes still cannot hang the painter.
          final scene = VisualScene(
            kind: VisualSceneKind.geometry,
            view: VisualView(
              x: axis == "x"
                  ? VisualRange(min, min + 2)
                  : const VisualRange(-5, 5),
              y: axis == "y"
                  ? VisualRange(min, min + 2)
                  : const VisualRange(-5, 5),
            ),
          );
          final recorder = ui.PictureRecorder();
          final palette = VisualPalette.fromColorScheme(
            ColorScheme.fromSeed(seedColor: const Color(0xff008800)),
          );
          expect(
            () => VisualPainter(
              scene: scene,
              palette: palette,
              parameters: {},
            ).paint(ui.Canvas(recorder), const ui.Size(400, 300)),
            returnsNormally,
          );
          recorder.endRecording().dispose();
        },
      );
    }
  }
  test("large offsets with sufficient precision remain valid", () {
    expect(
      validateVisualScene({
        "v": 1,
        "kind": "geometry",
        "view": {
          "x": [1e16, 1e16 + 128],
          "y": [-5, 5],
        },
        "meta": {"alt": "Large range"},
      }).ok,
      isTrue,
    );
  });
}
