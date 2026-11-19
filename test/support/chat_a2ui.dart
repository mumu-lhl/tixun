import 'dart:async';
import 'dart:convert';

import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';

const expressForm = r'''
$/word = "pleasure"
$/score = 3
$/flipped = false
$/choices = []
root = Column([card, field, slider, picker, hint, button])
card = FlipCard("Front of card", "Back of card", $/flipped)
field = TextField("Expression", $/word)
slider = Slider(label="Confidence", value=$/score, min=0, max=5)
picker = ChoicePicker(label="Usage", options=[{label: "Formal", value: "formal"}, {label: "Casual", value: "casual"}], value=$/choices, displayStyle="chips")
hint = Markdown("**Examples**")
button = Button(label, action=Event("ask_chat", {text: $/word}))
label = Text("Ask about this")
''';

ToolCall _create(String id, String express, String placement) => ToolCall(
  id,
  'create_a2ui',
  jsonEncode({'express': express, 'placement': placement}),
);

class A2uiTestProvider extends MockChatProvider {
  final requests = <AiRequest>[];
  final results = <Map<String, dynamic>>[];
  final arrived = Completer<void>();
  final resume = Completer<void>();
  bool pauseAfterTools = false;

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) {
    var round = 0;
    return AiConversation((request, cancel) async* {
      requests.add(request);
      switch (round++) {
        case 0:
          if (!request.tools.any((tool) => tool.name == 'enable_a2ui')) {
            yield const AiChunk(text: 'Plain reply', completed: true);
            return;
          }
          yield const AiChunk(
            text: 'Before the interface.',
            calls: [ToolCall('enable', 'enable_a2ui', '{}')],
            completed: true,
          );
        case 1:
          yield AiChunk(
            calls: [
              _create('here-one', 'root = Text("First")', 'here'),
              _create('invalid', 'root = Image("https://example.com")', 'here'),
              _create('reference', expressForm, 'reference'),
              _create('here-two', 'root = Text("Second")', 'here'),
            ],
            completed: true,
          );
        default:
          results.addAll(
            request.messages.reversed
                .take(4)
                .map(
                  (message) =>
                      (jsonDecode(message.text) as Map).cast<String, dynamic>(),
                )
                .toList()
                .reversed,
          );
          if (pauseAfterTools) {
            arrived.complete();
            await Future.any([resume.future, cancel.whenCancel]);
            cancel.checkCancelled();
          }
          final first = results[0]['surface_id'];
          final ref = results[2]['surface_id'];
          yield AiChunk(
            text:
                'After the interface.\n\n'
                '![duplicate here](a2ui:$first)\n\n'
                '![form](a2ui:$ref)\n\n![duplicate form](a2ui:$ref)\n\n'
                '```md\n![example](a2ui:$ref)\n```',
          );
          yield const AiChunk(text: '\n\nFinal prose.', completed: true);
      }
    });
  }
}

Future<List<ChatA2uiSurface>> a2uiRows(
  AppDatabase db,
  String messageId,
) async => (db.select(
  db.chatA2uiSurfaces,
)..where((s) => s.messageId.equals(messageId))).get();
