import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'library_providers.dart';
import 'study_store.dart';

class StudyEditor extends ConsumerStatefulWidget {
  const StudyEditor({
    required this.isMistake,
    this.knowledge,
    this.mistake,
    this.initialKnowledge,
    this.initialMistake,
    this.sourceSessionId,
    this.sourceMessageId,
    super.key,
  });
  final bool isMistake;
  final KnowledgeDetail? knowledge;
  final MistakeDetail? mistake;
  final KnowledgeDraft? initialKnowledge;
  final MistakeDraft? initialMistake;
  final String? sourceSessionId, sourceMessageId;
  @override
  ConsumerState<StudyEditor> createState() => _StudyEditorState();
}

class _StudyEditorState extends ConsumerState<StudyEditor> {
  final _fields = <String, TextEditingController>{};
  bool _saving = false, _dirty = false;
  late String _kind;
  TextEditingController field(String name) => _fields[name]!;
  @override
  void initState() {
    super.initState();
    final k = widget.knowledge;
    final m = widget.mistake;
    final kd = widget.initialKnowledge;
    final md = widget.initialMistake;
    _kind = k?.item.kind ?? kd?.kind ?? '个人笔记';
    final values = <String, String>{
      'title': k?.item.title ?? m?.item.title ?? kd?.title ?? md?.title ?? '',
      'subject':
          k?.item.subject ??
          m?.item.subject ??
          kd?.subject ??
          md?.subject ??
          '数学',
      'chapter':
          k?.item.chapter ??
          m?.item.chapter ??
          kd?.chapter ??
          md?.chapter ??
          '',
      'tags': (k?.tags ?? m?.tags ?? kd?.tags ?? md?.tags ?? []).join('，'),
      'content': k?.item.content ?? kd?.content ?? '',
      'question': m?.item.question ?? md?.question ?? '',
      'correctAnswer': m?.item.correctAnswer ?? md?.correctAnswer ?? '',
      'originalAnswer': m?.item.originalAnswer ?? md?.originalAnswer ?? '',
      'ownAnalysis': m?.item.ownAnalysis ?? md?.ownAnalysis ?? '',
      'aiAnalysis': m?.item.aiAnalysis ?? md?.aiAnalysis ?? '',
      'errorReason': m?.item.errorReason ?? md?.errorReason ?? '暂未确定',
      'suggestedReason': m?.item.suggestedReason ?? md?.suggestedReason ?? '',
    };
    for (final e in values.entries) {
      _fields[e.key] = TextEditingController(text: e.value)
        ..addListener(() {
          if (!_dirty) setState(() => _dirty = true);
        });
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _discard() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr("放弃未保存的修改？")),
            content: Text(context.tr("当前修改尚未保存。")),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr("继续编辑")),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.tr("放弃修改")),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final store = ref.read(studyStoreProvider);
      final labels = field('tags').text.split(RegExp('[,，]'));
      final oldId = widget.knowledge?.item.id ?? widget.mistake?.item.id;
      final oldSubject =
          widget.knowledge?.item.subject ?? widget.mistake?.item.subject;
      if (oldId != null && oldSubject != field('subject').text.trim()) {
        final linked = await store.modules.ids(oldId, widget.isMistake);
        if (linked.isNotEmpty) {
          if (!mounted) return;
          final yes = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: Text(d.tr('更换科目')),
              content: Text(d.tr('更换科目会清除原科目的目录关联。资料正文和图片会保留。')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d),
                  child: Text(d.tr('取消')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: Text(d.tr('继续保存')),
                ),
              ],
            ),
          );
          if (yes != true) return;
        }
      }

      String id;
      if (widget.isMistake) {
        final row = await store.saveMistake(
          MistakeDraft(
            title: field('title').text,
            question: field('question').text,
            subject: field('subject').text,
            chapter: field('chapter').text,
            tags: labels,
            correctAnswer: field('correctAnswer').text,
            originalAnswer: field('originalAnswer').text,
            ownAnalysis: field('ownAnalysis').text,
            aiAnalysis: field('aiAnalysis').text,
            errorReason: field('errorReason').text,
            suggestedReason: field('suggestedReason').text,
          ),
          id: widget.mistake?.item.id,
          expectedRevision: widget.mistake?.item.revision,
          sourceSessionId: widget.sourceSessionId,
          sourceMessageId: widget.sourceMessageId,
        );
        id = row.id;
      } else {
        final row = await store.saveKnowledge(
          KnowledgeDraft(
            title: field('title').text,
            content: field('content').text,
            subject: field('subject').text,
            kind: _kind,
            chapter: field('chapter').text,
            tags: labels,
          ),
          id: widget.knowledge?.item.id,
          expectedRevision: widget.knowledge?.item.revision,
          sourceSessionId: widget.sourceSessionId,
          sourceMessageId: widget.sourceMessageId,
        );
        id = row.id;
      }
      if (mounted) {
        _dirty = false;
        Navigator.pop(context, id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FormatException ? e.message : context.tr("保存失败，请检查可用存储空间。"),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && !_saving,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && !_saving && await _discard() && context.mounted) {
        setState(() => _dirty = false);
        if (context.mounted) Navigator.pop(context);
      }
    },
    child: Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.tr("关闭编辑"),
            onPressed: _saving
                ? null
                : () async {
                    if (await _discard() && context.mounted) {
                      setState(() => _dirty = false);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
            icon: const Icon(Icons.close),
          ),
          title: Text(
            widget.isMistake ? context.tr("整理错题") : context.tr("编辑知识"),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const Key('save-study'),
                onPressed: _saving ? null : () => act(context, _save),
                child: Text(_saving ? context.tr("保存中…") : context.tr("保存")),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _input(
                        'title',
                        '标题',
                        key: const Key('study-title'),
                        maxLength: 160,
                      ),
                      _input('subject', '科目（可以自定义）', maxLength: 40),
                      if (!widget.isMistake)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _kind,
                            decoration: InputDecoration(
                              labelText: context.tr("知识类型"),
                            ),
                            items: knowledgeKinds
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(context.tr(v)),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() {
                              _kind = v!;
                              _dirty = true;
                            }),
                          ),
                        ),
                      _input('chapter', '章节 / 学习范围', maxLength: 160),
                      _input('tags', '标签（逗号分隔）', maxLength: 800),
                      if (!widget.isMistake)
                        _input(
                          'content',
                          '正文 · 支持 Markdown 和 LaTeX',
                          key: const Key('study-content'),
                          lines: 12,
                        )
                      else ...[
                        _input(
                          'question',
                          '题目文本（图片题可以留空）',
                          key: const Key('study-content'),
                          lines: 5,
                        ),
                        _input('correctAnswer', '正确答案', lines: 3),
                        _input('originalAnswer', '我的原答案', lines: 3),
                        _input('ownAnalysis', '我的分析与想法', lines: 4),
                        _input('aiAnalysis', 'AI 解析（请核对结论）', lines: 6),
                        _input(
                          'errorReason',
                          '我确认的错误原因 · 支持自定义',
                          maxLength: 100,
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: field('errorReason'),
                          builder: (context, value, _) => Wrap(
                            spacing: 6,
                            children: mistakeReasons.map((r) {
                              final selected = value.text == r;
                              final colors = Theme.of(context).colorScheme;
                              return ActionChip(
                                label: Text(
                                  context.tr(r),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: selected
                                        ? colors.onPrimaryContainer
                                        : null,
                                  ),
                                ),
                                backgroundColor: selected
                                    ? colors.primaryContainer
                                    : null,
                                onPressed: () => field('errorReason').text = r,
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _input(
                          'suggestedReason',
                          'AI 建议的原因（未经确认）',
                          lines: 2,
                          maxLength: 500,
                        ),
                      ],
                      Text(
                        context.tr("图片可在保存后的详情页添加。知识的文本版本会自动保留，修改不会覆盖历史。"),
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _input(
    String name,
    String label, {
    int lines = 1,
    int maxLength = 60000,
    Key? key,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      key: key,
      controller: field(name),
      enabled: !_saving,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 4,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: context.tr(label),
        alignLabelWithHint: lines > 1,
        // Show the counter for fields with a real limit so input is never
        // silently truncated; the effectively unlimited body fields keep the
        // counter hidden.
        counterText: maxLength >= 60000 ? '' : null,
      ),
    ),
  );
}
