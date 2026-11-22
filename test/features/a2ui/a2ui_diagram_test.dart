import "dart:math" as math;

import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/visual/math/sampling.dart";
import "package:tixun/core/visual/model/visual_scene.dart";
import "package:tixun/features/a2ui/a2ui_catalog.dart";
import "package:tixun/features/a2ui/a2ui_diagrams.dart";
import "package:tixun/features/a2ui/a2ui_stream.dart";

Map<String, VisualScene> compile(String express) => readDiagramSnapshots(
  readChatA2ui(compileChatA2ui(express, "fixture"), "fixture"),
);

void main() {
  test("Express diagrams become validated Visual DSL snapshots", () {
    final scenes = compile(r'''
$/amount = 1
root = Column(children=[plot, line, vector])
plot = FunctionPlot(title="Reciprocal and radical", expressions=["1/x", "sqrt(x)"], domain=[-2,2], a=$/amount)
line = NumberLine(title="Half-open interval", marks=[0], interval=[-2,3], openLeft=true)
vector = VectorDiagram(title="Vector components", vectors=[[2,1],[-1,3]])
''');
    final plot = scenes["plot"]!;
    final curves = plot.elements.cast<PlotElement>();
    expect(curves.map((curve) => curve.expression), ["1/x", "sqrt(x)"]);
    final reciprocal = sampleFunction(
      curves.first.expression,
      min: -2,
      max: 2,
      maxSamples: 384,
      variables: {},
    );
    expect(reciprocal, hasLength(greaterThan(1)));
    expect(
      reciprocal.every(
        (segment) => segment.points.every(
          (point) => point.dx.sign == segment.points.first.dx.sign,
        ),
      ),
      isTrue,
    );
    final sqrt = sampleFunction(
      curves.last.expression,
      variables: {},
      min: -2,
      max: 2,
    );
    expect(
      sqrt
          .expand((s) => s.points)
          .every((p) => p.dx >= 0 && p.dy == math.sqrt(p.dx)),
      isTrue,
    );
    final circles = scenes["line"]!.elements.whereType<CircleElement>();
    expect(circles.single.center.literal, (-2.0, 0.0));
    expect(
      scenes["line"]!.elements.whereType<PointElement>().single.at.literal,
      (3.0, 0.0),
    );
    expect(
      scenes["vector"]!.elements.whereType<ArrowElement>().map(
        (e) => e.to.literal,
      ),
      [(2.0, 1.0), (-1.0, 3.0)],
    );
    final polygon = compile(
      'root = GeometryScene("Triangle", [[0,0],[3,0],[0,4]], labels=["A","B","C"], closed=true)',
    ).values.single;
    expect(polygon.elements.whereType<PolygonElement>(), hasLength(1));
  });

  test("Invalid or disabled semantic scenes fail before storage", () {
    for (final express in [
      'root = FunctionPlot("Code", ["evil(x)"])',
      'root = FunctionPlot("Undefined", ["sqrt(x)"], domain=[-5,-1])',
      'root = FunctionPlot("Parameter missing", ["a*x"])',
      'root = NumberLine("Backwards", [], interval=[2,1])',
      'root = GeometryScene("Too few points", [[0,0],[1,1]], closed=true)',
      'root = VectorDiagram("Coordinate overflow", [[1e12,1]])',
    ]) {
      expect(() => compile(express), throwsException, reason: express);
    }
    expect(
      () => compileChatA2ui(
        'root = FunctionPlot("Line", ["x"])',
        "fixture",
        drawingEnabled: false,
      ),
      throwsFormatException,
    );
  });

  test("Oversize and interrupted blocks do not retain or expose source", () {
    final stream = InlineA2uiStream();
    final parts = stream
        .feed(
          '<a2ui>${'x' * 13000}</a2ui>'
          '<a2ui>root = Text("Safe")</a2ui><a2u',
          done: true,
        )
        .toList();
    expect(parts.map((part) => part.kind), [
      InlineA2uiKind.invalid,
      InlineA2uiKind.surface,
      InlineA2uiKind.invalid,
    ]);
    expect(parts.first.text, isEmpty);
  });

  test(
    "Framer is invariant across chunk boundaries and shields Markdown code",
    () {
      const source =
          'Lead <a2ui>root = Text("a")</a2ui>'
          '<a2ui>root = Text("b")</a2ui>\n\n'
          "```md\n<a2ui>literal</a2ui>\n```\n"
          "`<a2ui>also literal</a2ui>` <a2ui>unfinished";
      for (var split = 0; split <= source.length; split++) {
        final framer = InlineA2uiStream();
        final parts = [
          ...framer.feed(source.substring(0, split)),
          ...framer.feed(source.substring(split), done: true),
        ];
        expect(
          parts
              .where((part) => part.kind == InlineA2uiKind.surface)
              .map((p) => p.text),
          ['root = Text("a")', 'root = Text("b")'],
          reason: "split at $split",
        );
        expect(
          parts
              .where((part) => part.kind == InlineA2uiKind.prose)
              .map((p) => p.text)
              .join(),
          "Lead \n\n```md\n<a2ui>literal</a2ui>\n```\n`<a2ui>also literal</a2ui>` ",
        );
        expect(parts.last.kind, InlineA2uiKind.invalid);
      }
    },
  );
}
