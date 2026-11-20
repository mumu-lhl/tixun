import "dart:async";

import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";

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

const expressPlot = r'''
$/coefficient = 1
root = Column(children=[curve, control])
curve = FunctionPlot(title="A parabola", expressions=["a*x^2"], domain=[-2,2], a=$/coefficient)
control = Slider(label="Coefficient", value=$/coefficient, min=0.5, max=3)
''';

class A2uiTestProvider extends MockChatProvider {
  A2uiTestProvider({this.plainFollowUp = false});

  final bool plainFollowUp;
  final requests = <AiRequest>[];
  final arrived = Completer<void>();
  final resume = Completer<void>();
  bool pauseAfterBlocks = false;

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        requests.add(request);
        if (!request.instructions.contains("raw <a2ui>") ||
            (plainFollowUp && requests.length > 1)) {
          yield const AiChunk(text: "Plain reply", completed: true);
          return;
        }
        yield const AiChunk(text: "Before the interface.\n\n<a2");
        final introductory = request.instructions.contains("NumberLine")
            ? expressPlot
            : 'root = Text("First")';
        yield AiChunk(
          text:
              "ui>$introductory</a2ui>\n\n"
              '<a2ui>root = Image("https://example.com")</a2ui>',
        );
        yield AiChunk(
          text: '<a2ui>$expressForm</a2ui><a2ui>root = Text("Second")</a2ui>',
        );
        if (pauseAfterBlocks) {
          yield const AiChunk(text: '<a2ui>root = Text("Partial');
          arrived.complete();
          await Future.any([resume.future, cancel.whenCancel]);
          cancel.checkCancelled();
        }
        yield const AiChunk(
          text:
              "\n\nAfter the interface.\n\n"
              '```md\n<a2ui>root = Text("Sample")</a2ui>\n```\n\nFinal prose.',
          completed: true,
        );
      });
}

Future<List<ChatA2uiSurface>> a2uiRows(
  AppDatabase db,
  String messageId,
) async => (db.select(
  db.chatA2uiSurfaces,
)..where((s) => s.messageId.equals(messageId))).get();
