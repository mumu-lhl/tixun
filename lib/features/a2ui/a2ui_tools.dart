const aiA2uiEnabledKey = 'ai_a2ui_enabled';
String chatA2uiPreference(String id) => '$aiA2uiEnabledKey:$id';
bool? readA2uiOverride(String? value) => switch (value) {
  'true' => true,
  'false' => false,
  _ => null,
};

final a2uiFollowUp = RegExp(
  r'刚才.{0,8}(界面|卡片|表单|滑杆|控件|选择器|图)|(?:这个|那个|上个|之前的|上面的).{0,8}(界面|卡片|表单|滑杆|控件|选择器|图)|\[TiXun A2UI [0-9a-f-]+\]|\b(?:previous|last|earlier|that|this|above)\s+(?:interactive\s+)?(?:surface|interface|card|form|slider|widget|plot|diagram|graph)\b',
  caseSensitive: false,
);

final interactiveA2uiIntent = RegExp(
  r'交互|表单|卡片|滑杆|控件|选择器|interactive|flashcards?|controls?|sliders?|form\b',
  caseSensitive: false,
);
final drawingA2uiIntent = RegExp(
  r'画|图|函数|数轴|几何|坐标|向量|不等式|\b(?:draw|plot|graph|diagram|visualize|geometry|vector|number line|inequality|function)\b',
  caseSensitive: false,
);

const inlineA2uiPrelude =
    'For interactive teaching UI use raw <a2ui> blocks '
    'with one Express root component, outside Markdown code. The app owns '
    'surface IDs. Use prose around the block.';

final a2uiActionMarker = RegExp(r'^\[TiXun A2UI ([0-9a-f-]{36})\]\s*');

const inlineA2uiInstructions = r'''
For an interactive interface, write raw <a2ui> ... </a2ui> in your reply, without Markdown fences or IDs. One root component per block. Put prose and other blocks before or after it. Express uses assignments, literal arguments, named arguments and data paths such as $/value. Example:
<a2ui>
$/flipped = false
root = FlipCard("Question", "Answer", $/flipped)
</a2ui>
Use Column(children=[item, ...]), Row(children=[...]), Card(child=item), Text(text="..."), Markdown(text="..."), TextField(label="...", value=$/text), CheckBox(label="...", value=$/checked), Slider(label="...", min=0, max=5, value=$/value), or ChoicePicker(options=[{label:"One",value:"1"}], value=$/selected). Button(child=label, action=Event("ask_chat", {text: $/text})) requests user confirmation. copy_text accepts the same context. Do not ask for credentials or use these surfaces as graded assessments. For revisions, output a fresh block.
''';

const inlineDrawingInstructions = r'''
Use raw <a2ui>...</a2ui> blocks for ordinary teaching diagrams. The app computes axes, sampling and layout. No drawing tools or surface IDs are needed. Use:
root = FunctionPlot(title="Caption", expressions=["x^2", "2*x"], domain=[-4,4])
root = NumberLine(title="Caption", marks=[-2,0,3], interval=[-2,3], openLeft=true)
root = GeometryScene(title="Caption", points=[[0,0],[3,0],[0,4]], labels=["A","B","C"], closed=true)
root = VectorDiagram(title="Caption", vectors=[[2,1],[-1,3]])
Each example is a separate root. Domain is optional; use only when mathematically relevant. Functions use x, explicit *, and ^; use the existing math functions (sin, cos, tan, sqrt, ln, exp, abs). Do not fill in undefined values. For interactivity bind FunctionPlot(a=$/a, expressions=["a*x^2"], title="Caption") and a Slider(value=$/a, label="a", min=-3, max=3) in a Column, initializing $/a first. Use formal visual tools only for separate assets, knowledge links, complex geometry/animation or figure-backed practice.
''';
