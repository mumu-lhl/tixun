import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/model_tokenizer.dart';
import 'package:tixun/core/ai/visual_toolset.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/validation/visual_quality.dart';
import 'package:tixun/features/a2ui/a2ui_catalog.dart';
import 'package:tixun/features/a2ui/a2ui_compile_worker.dart';
import 'package:tixun/features/a2ui/a2ui_diagrams.dart';
import 'package:tixun/features/a2ui/a2ui_tools.dart';

String _schema(AiTool tool) => jsonEncode({
  'type': 'function',
  'function': {
    'name': tool.name,
    'description': tool.description,
    'parameters': tool.parameters,
  },
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Comparable plot fixture tracks schema, payload and client compile cost', () async {
    const legacy = {
      'v': 1,
      'kind': 'plot2d',
      'title': 'Parabola',
      'view': {
        'x': [-3, 3],
        'y': [-1, 9],
      },
      'elements': [
        {
          'id': 'p',
          'type': 'plot',
          'expression': 'x^2',
          'domain': [-3, 3],
          'samples': 384,
        },
      ],
    };
    const express =
        'root = FunctionPlot(title="Parabola", expressions=["x^2"], domain=[-3,3])';
    const id = 'eca9b19a-2396-4023-a0dd-ffd5bef8d052';
    final tools = VisualToolset(exam: false);
    final opening = _schema(tools.tools.last);
    tools.enable(const ToolCall('fixture', enableVisualToolsName, '{}'));
    final expanded = tools.instructions + tools.tools.map(_schema).join();
    final inline =
        '$inlineA2uiPrelude\n$inlineDrawingInstructions'
        '${_schema(VisualToolset(exam: false, inlineDrawing: true).tools.last)}';
    for (final encoding in ['deepseek_v4', 'o200k_base']) {
      final tokenizer = await ModelTokenizer.load(encoding);
      final oldOpening = tokenizer.count(opening);
      final oldExpanded = tokenizer.count(expanded);
      final newOpening = tokenizer.count(inline);
      final oldPayload = tokenizer.count(jsonEncode({'scene': legacy}));
      final newPayload = tokenizer.count('<a2ui>\n$express\n</a2ui>');
      debugPrint(
        '$encoding oldOpen=$oldOpening oldExpanded=$oldExpanded '
        'newOpen=$newOpening oldPayload=$oldPayload newPayload=$newPayload',
      );
      expect(newOpening, lessThan(oldOpening + oldExpanded));
      expect(newPayload, lessThan(oldPayload));
    }

    final legacyCold = Stopwatch()..start();
    final legacyScene = VisualScene.fromJson(legacy);
    expect(checkVisualQuality(legacyScene), isEmpty);
    legacyCold.stop();
    final legacyTimes = <int>[];
    for (var i = 0; i < 40; i++) {
      final clock = Stopwatch()..start();
      final scene = VisualScene.fromJson(legacy);
      checkVisualQuality(scene);
      clock.stop();
      legacyTimes.add(clock.elapsedMicroseconds);
    }
    legacyTimes.sort();
    debugPrint(
      'Visual DSL coldUs=${legacyCold.elapsedMicroseconds} '
      'warmP50Us=${legacyTimes[19]} warmP95Us=${legacyTimes[37]}',
    );
    final cold = Stopwatch()..start();
    final stored = await compileInlineSurface(
      express,
      id,
      drawingEnabled: true,
      cancel: CancelToken(),
    );
    cold.stop();
    final scene = readDiagramSnapshots(readChatA2ui(stored, id)).values.single;
    final original = legacyScene.elements.whereType<PlotElement>().single;
    final plot = scene.elements.whereType<PlotElement>().single;
    expect(plot.expression, original.expression);
    expect(plot.domain, original.domain);
    expect(checkVisualQuality(scene), isEmpty);

    final times = <int>[];
    for (var i = 0; i < 40; i++) {
      final clock = Stopwatch()..start();
      await compileInlineSurface(
        express,
        id,
        drawingEnabled: true,
        cancel: CancelToken(),
      );
      clock.stop();
      times.add(clock.elapsedMicroseconds);
    }
    times.sort();
    debugPrint(
      'Express worker coldUs=${cold.elapsedMicroseconds} '
      'warmP50Us=${times[19]} warmP95Us=${times[37]}',
    );
  });
}
