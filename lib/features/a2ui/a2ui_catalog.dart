import 'dart:convert';

import 'package:a2ui_agent/a2ui_agent.dart'
    show
        A2uiRequestProcessor,
        ExpressCompiler,
        ExpressFormatFactory,
        validatePayload;
import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/ui/learning_markdown.dart';

const chatA2uiProtocol = '1.0';
const chatA2uiCatalogId = 'https://tixun.app/catalogs/chat/v1';
const chatA2uiMaxSource = 12000;
const chatA2uiMaxState = 16384;
const chatA2uiActions = {'copy_text', 'ask_chat', 'open_practice'};

final chatA2uiCatalog = CatalogImplementation(
  id: chatA2uiCatalogId,
  protocolVersion: A2uiProtocolVersion.v1_0,
  title: 'TiXun chat',
  components: [
    BasicComponents.text,
    BasicComponents.column,
    BasicComponents.row,
    BasicComponents.card,
    BasicComponents.divider,
    BasicComponents.button,
    BasicComponents.textField,
    BasicComponents.checkBox,
    BasicComponents.choicePicker,
    BasicComponents.slider,
    ComponentImplementation(
      name: 'Markdown',
      schema: Schema.object(
        properties: {'text': CommonSchemasV1.dynamicString},
        required: ['text'],
      ),
      builder: (context, node, props, buildChild) =>
          LearningMarkdown(props.string('text') ?? ''),
    ),
    ComponentImplementation(
      name: 'FlipCard',
      schema: Schema.object(
        properties: {
          'front': CommonSchemasV1.dynamicString,
          'back': CommonSchemasV1.dynamicString,
          'flipped': CommonSchemasV1.dynamicBoolean,
        },
        required: ['front', 'back', 'flipped'],
      ),
      builder: (context, node, props, buildChild) {
        final binding = props.writable('flipped');
        final flipped = props.boolean('flipped') ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LearningMarkdown(props.string(flipped ? 'back' : 'front') ?? ''),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: binding == null
                  ? null
                  : () {
                      try {
                        binding.set(!flipped);
                      } on A2uiDataError {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.chatA2uiActionFailed),
                          ),
                        );
                      }
                    },
              child: Text(context.l10n.chatA2uiFlip),
            ),
          ],
        );
      },
    ),
    ComponentImplementation(
      name: 'VisualSceneRef',
      schema: Schema.object(
        properties: {'id': Schema.string()},
        required: ['id'],
      ),
      builder: (context, node, props, buildChild) =>
          context
              .dependOnInheritedWidgetOfExactType<A2uiVisualScope>()
              ?.builder(props.string('id') ?? '') ??
          Text(context.l10n.inlineVisualUnavailable),
    ),
  ],
);

class A2uiVisualScope extends InheritedWidget {
  const A2uiVisualScope({
    required this.builder,
    required super.child,
    super.key,
  });

  final Widget? Function(String id) builder;

  @override
  bool updateShouldNotify(A2uiVisualScope oldWidget) =>
      builder != oldWidget.builder;
}

final _catalogs = <CatalogApi>[chatA2uiCatalog];

final chatA2uiSkill = A2uiRequestProcessor(
  activeCatalogs: _catalogs,
  formatFactory: const ExpressFormatFactory(allowedMessages: ['createSurface']),
  examples: [
    [
      ExpressCompiler(_catalogs)
          .compile('root = Text("A small native surface")')
          .single,
    ],
  ],
).promptSnippet;

String compileChatA2ui(String source, String id) {
  if (source.trim().isEmpty || source.length > chatA2uiMaxSource) {
    throw const FormatException(
      'Express is empty or exceeds 12000 characters.',
    );
  }
  _checkSourceDepth(source);
  final List<AgentToRendererMessage> messages;
  try {
    messages = ExpressCompiler(_catalogs).compile(source);
  } on StackOverflowError {
    throw const FormatException('Express exceeds the compiler nesting limit.');
  }
  final original = messages.singleOrNull;
  if (original is! CreateSurfaceMessage ||
      original.sendDataModel ||
      original.metadata != null) {
    throw const FormatException(
      'Provide exactly one complete surface and no protocol actions.',
    );
  }
  final message = CreateSurfaceMessage(
    version: chatA2uiProtocol,
    surfaceId: id,
    catalogId: chatA2uiCatalogId,
    components: original.components,
    dataModel: original.dataModel,
  );
  _checkSurface(message);
  validatePayload(_catalogs, [message]);
  final json = jsonEncode([message.toJson()]);
  if (utf8.encode(json).length > 32000) {
    throw const FormatException('Compiled surface exceeds 32 KB.');
  }
  return json;
}

/// Applies a resource bound before the upstream parser's recursive rules.
void _checkSourceDepth(String source) {
  var depth = 0;
  var quote = 0;
  var escaped = false;
  for (final char in source.codeUnits) {
    if (quote != 0) {
      if (!escaped && char == quote) quote = 0;
      escaped = !escaped && char == 92;
      continue;
    }
    if (char == 34 || char == 39) quote = char;
    if (char == 40 || char == 91 || char == 123) depth++;
    if (char == 41 || char == 93 || char == 125) depth--;
    if (depth.abs() > 24) {
      throw const FormatException('Express nesting exceeds 24 levels.');
    }
    if (depth < 0) throw const FormatException('Unmatched Express delimiter.');
  }
}

final _binding = RegExp(r'^(/[a-zA-Z_][a-zA-Z0-9_]{0,39}){1,6}$');

void _checkSurface(CreateSurfaceMessage message) {
  final nodes = message.components ?? const [];
  if (nodes.isEmpty || nodes.length > 32) {
    throw const FormatException('A surface must have 1–32 components.');
  }
  if (utf8.encode(jsonEncode(message.dataModel)).length > chatA2uiMaxState) {
    throw const FormatException('Initial surface state is too large.');
  }
  _checkProperties(message.dataModel);
  final children = <String, List<String>>{};
  for (final node in nodes) {
    final id = node['id'] as String;
    if (id.length > 64 ||
        children.containsKey(id) ||
        !chatA2uiCatalog.components.containsKey(node['component'])) {
      throw const FormatException('Unknown component or invalid component ID.');
    }
    if (node['component'] == 'TextField' && node['variant'] == 'obscured') {
      throw const FormatException('Password and secret fields are disabled.');
    }
    if (node['options'] case final List options when options.length > 24) {
      throw const FormatException(
        'A choice picker supports at most 24 options.',
      );
    }
    final list = node['children'];
    if (list != null &&
        (list is! List || list.any((element) => element is! String))) {
      throw const FormatException(
        'Children must be a fixed list of component IDs.',
      );
    }
    children[id] = [
      if (node['child'] case final String child) child,
      if (list is List) ...list.cast<String>(),
    ];
    _checkProperties(node);
  }
  final seen = <String>{};
  void visit(String id, int depth) {
    if (depth > 8 || !seen.add(id) || !children.containsKey(id)) {
      throw const FormatException(
        'Expected a component tree rooted at root, at most 8 levels deep.',
      );
    }
    for (final child in children[id]!) {
      visit(child, depth + 1);
    }
  }

  visit('root', 1);
  if (seen.length != nodes.length) {
    throw const FormatException('Unreachable component.');
  }
}

void _checkProperties(Object? value) {
  if (value is List) {
    for (final item in value) {
      _checkProperties(item);
    }
  } else if (value is Map) {
    if (value.containsKey('@call') ||
        value.containsKey('functionCall') ||
        value.containsKey('metadata') ||
        value.containsKey('checks')) {
      throw const FormatException(
        'Functions, extensions and executable checks are disabled.',
      );
    }
    if (value['@path'] case final Object path) {
      if (path is! String || !_binding.hasMatch(path)) {
        throw const FormatException('Use a simple absolute data binding.');
      }
    }
    if (value['event'] case final Object event) {
      if (event is! Map ||
          !chatA2uiActions.contains(event['name']) ||
          event.keys.any((key) => key != 'name' && key != 'context')) {
        throw const FormatException('This surface event is not allowed.');
      }
      final args = event['context'];
      final valid = event['name'] == 'open_practice'
          ? args == null || (args is Map && args.isEmpty)
          : args is Map && args.length == 1 && args.containsKey('text');
      if (!valid) {
        throw const FormatException(
          'Incorrect context for this surface event.',
        );
      }
    }
    for (final item in value.values) {
      _checkProperties(item);
    }
  }
}

CreateSurfaceMessage readChatA2ui(String json, String id) {
  if (utf8.encode(json).length > 32000) {
    throw const FormatException('Stored surface exceeds 32 KB.');
  }
  final list = jsonDecode(json);
  if (list is! List ||
      list.length != 1 ||
      list.single is! Map<String, dynamic>) {
    throw const FormatException('Invalid stored surface envelope.');
  }
  final message = AgentToRendererMessage.fromJson(
    list.single as Map<String, dynamic>,
  );
  if (message is! CreateSurfaceMessage ||
      message.version != chatA2uiProtocol ||
      message.surfaceId != id ||
      message.catalogId != chatA2uiCatalogId ||
      message.sendDataModel ||
      message.metadata != null) {
    throw const FormatException('Invalid stored surface.');
  }
  _checkSurface(message);
  return message;
}

List<Map<String, String>> chatA2uiOutline(String json, String id) {
  try {
    final message = readChatA2ui(json, id);
    return [
      for (final node in (message.components ?? const []).take(8))
        {
          'type': node['component'] as String,
          for (final field in ['text', 'label', 'front'])
            if (node[field] case final String value)
              field: value.length > 100 ? value.substring(0, 100) : value,
        },
    ];
  } on Exception {
    return const [];
  }
}
