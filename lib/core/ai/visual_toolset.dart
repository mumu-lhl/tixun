import 'dart:convert';

import 'chat_provider.dart';
import 'quiz_tool.dart';
import 'visual_schema.dart';
import 'visual_tool.dart';

const aiDrawingEnabledKey = 'ai_drawing_enabled';
const enableVisualToolsName = 'enable_visual_tools';

const enableVisualToolsSchema = AiTool(
  name: enableVisualToolsName,
  description: 'Load the complete figure schemas before drawing, editing, reading or creating a visual question. Use for any task needing a diagram, plot, animation or visual interaction, not just explicit drawing requests. In exam mode this enables only private question/solution diagrams in create_quiz, never exploration tools. This only loads schemas; it does not save data or grant write permissions. Call once with {} and use the tools in the next response.',
  parameters: {
    'type': 'object',
    'properties': <String, dynamic>{},
    'additionalProperties': false,
  },
);

/// A per-run, model-selected capability. Ordinary text requests carry no
/// scene DSL; loading preserves the complete field contracts, not loose objects.
class VisualToolset {
  VisualToolset({required this.exam, this.includeQuiz = true});

  final bool exam;
  final bool includeQuiz;
  bool _enabled = false;
  bool get enabled => _enabled;

  List<AiTool> get tools => _enabled
      ? [
          if (includeQuiz)
            if (exam) examQuizToolSchema else chatQuizToolSchema,
          if (!exam) ...[
            visualToolSchema,
            updateVisualToolSchema,
            getVisualToolSchema,
          ],
        ]
      : [
          if (includeQuiz) textQuizToolSchema(exam: exam),
          enableVisualToolsSchema,
        ];

  String get instructions => !_enabled
      ? ''
      : '$visualDslInstructions${!exam ? '\nPlace figures within explanations or knowledge content using a standalone Markdown image ![caption](visual:VISUAL_ID), with the real ID returned by create_visual. Create the scene first, then reference its ID in create_knowledge/update_knowledge content or the chat explanation. Never repeat scene JSON in prose. Reuse relevant existing public figures; never reference private quiz figures.' : ''}${exam ? '\nExam: create_quiz may include question_scene and solution_scene. Do not call create_visual/get_visual/update_visual. The question_scene is static with no timeline, controls, hidden elements, answer markers or solution hints. Put all solution diagrams only in solution_scene. Both are frozen atomically and are not linked to the chat message. Passing validation does not prove that question content is answer-free or scientifically correct.' : ''}';

  Map<String, dynamic> enable(ToolCall call) {
    try {
      final args = jsonDecode(call.arguments);
      if (args is! Map || args.isNotEmpty) throw const FormatException();
      _enabled = true;
      return {
        'ok': true,
        'schemas_loaded': true,
        'saved': false,
        'available_tools': tools.map((tool) => tool.name).toList(),
      };
    } on FormatException {
      return {'ok': false, 'error': 'enable_visual_tools requires {}.'};
    }
  }
}
