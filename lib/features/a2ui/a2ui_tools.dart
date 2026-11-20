import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' show A2uiError;
import 'package:dio/dio.dart';

import '../../core/ai/ai_types.dart';
import 'a2ui_catalog.dart';
import 'a2ui_store.dart';

const aiA2uiEnabledKey = 'ai_a2ui_enabled';
String chatA2uiPreference(String id) => '$aiA2uiEnabledKey:$id';
bool? readA2uiOverride(String? value) => switch (value) {
  'true' => true,
  'false' => false,
  _ => null,
};

const enableA2uiName = 'enable_a2ui';
const createA2uiName = 'create_a2ui';

const enableA2uiTool = AiTool(
  name: enableA2uiName,
  description: 'Load A2UI Express for an interactive native chat interface, such as a form, flashcard or slider. Use only when an interactive interface helps. Call with {}.',
  parameters: {
    'type': 'object',
    'properties': <String, dynamic>{},
    'additionalProperties': false,
  },
);

const createA2uiTool = AiTool(
  name: createA2uiName,
  description: 'Compile one complete Express surface and return its ID. Each call creates a new layout snapshot with independent local state.',
  parameters: {
    'type': 'object',
    'properties': {
      'express': {
        'type': 'string',
        'minLength': 1,
        'maxLength': chatA2uiMaxSource,
      },
      'placement': {
        'type': 'string',
        'enum': ['reference', 'here'],
        'default': 'reference',
      },
    },
    'required': ['express'],
    'additionalProperties': false,
  },
);

final a2uiFollowUp = RegExp(
  r'刚才.{0,8}(界面|卡片|表单|滑杆|控件|选择器)|(?:这个|那个|上个|之前的|上面的).{0,8}(界面|卡片|表单|滑杆|控件|选择器)|\[TiXun A2UI [0-9a-f-]+\]|\b(?:previous|last|earlier|that|this|above)\s+(?:interactive\s+)?(?:surface|interface|card|form|slider|widget)\b',
  caseSensitive: false,
);

String get a2uiInstructions =>
    '''
$chatA2uiSkill
TiXun integration: Send the raw Express to create_a2ui (one rooted surface per call), never include Express or A2UI JSON in your written answer. This is a supplemental interface, never an authoritative quiz, grade, review or learning record. For reference placement (default), insert a standalone Markdown image ![short accessible description](a2ui:SURFACE_ID) anywhere in the same reply, using the returned ID. For here placement the app inserts the surface immediately at the current reply boundary. End any active Markdown block before the call. Do not write another reference for it. Continue with prose if needed.
Use writable data paths for local form controls and FlipCard. For buttons use only Event("copy_text", {text: ...}) or Event("ask_chat", {text: ...}). These copy text or let the user review and send a follow-up in this chat. Event("open_practice") only opens the official exercise already linked to this same reply. It takes no arguments and cannot create or grade a question. The application controls all permissions and confirmations. Use concise captions and no more than 24 options in each choice picker. Never request secrets or simulate trusted settings or security dialogs. If the user wants revision, create a fresh surface. A prior surface remains intact.
''';

AiRequest enableA2ui(AiRequest request, ToolCall call) {
  final result = _enableResult(call);
  final expanded =
      result['ok'] == true &&
      request.tools.any((tool) => tool.name == enableA2uiName);
  return request.copyWith(
    tools: expanded
        ? [
            for (final tool in request.tools)
              if (tool.name == enableA2uiName) createA2uiTool else tool,
          ]
        : request.tools,
    instructions: expanded
        ? '${request.instructions}\n$a2uiInstructions'
        : request.instructions,
    messages: [
      ...request.messages,
      AiMessage.tool(call.id, jsonEncode(result)),
    ],
  );
}

Map<String, dynamic> _enableResult(ToolCall call) {
  try {
    final args = jsonDecode(call.arguments);
    if (args is! Map || args.isNotEmpty) throw const FormatException();
    return {'ok': true, 'available_tool': createA2uiName, 'saved': false};
  } on FormatException {
    return {'ok': false, 'error': 'enable_a2ui requires {}.'};
  }
}

Future<Map<String, dynamic>> createA2ui(
  ChatA2uiStore store,
  ToolCall call, {
  required String sessionId,
  required String messageId,
  required String body,
  required CancelToken cancel,
}) async {
  try {
    if (call.arguments.length > 80000) {
      throw const FormatException('Arguments are too large.');
    }
    final args = jsonDecode(call.arguments);
    if (args is! Map ||
        args.keys.any((key) => key != 'express' && key != 'placement')) {
      throw const FormatException('Expected express and optional placement.');
    }
    final express = args['express'];
    final placement = args.containsKey('placement')
        ? args['placement']
        : 'reference';
    if (express is! String ||
        (placement != 'reference' && placement != 'here')) {
      throw const FormatException(
        'Provide Express and placement reference or here.',
      );
    }
    final inserted = placement == 'here';
    final surface = await store.create(
      sessionId: sessionId,
      messageId: messageId,
      callId: call.id,
      express: express,
      bodyAtInsertion: inserted ? body : null,
      cancel: cancel,
    );
    return {
      'ok': true,
      'surface_id': surface.id,
      'placement': placement,
      'inserted': inserted,
      if (inserted)
        'instruction':
            'Inserted in the current reply. Do not reference this ID again.'
      else
        'reference': '![description](a2ui:${surface.id})',
    };
  } on A2uiError catch (error) {
    return {'ok': false, 'error': _shortError(error.message)};
  } on FormatException catch (error) {
    return {'ok': false, 'error': _shortError(error.message)};
  }
}

String _shortError(String error) =>
    error.length <= 400 ? error : error.substring(0, 400);

// The layout is retained once, in the owning Surface row. A2UI calls from
// finished runs fall back to visible prose and are never replayed as tools.
List<ToolCall> compactA2uiTranscript(List<ToolCall> calls) => [
  for (final call in calls)
    if (call.name == createA2uiName)
      ToolCall(call.id, call.name, '{}')
    else
      call,
];
