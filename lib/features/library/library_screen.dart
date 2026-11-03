import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/actions.dart';
import '../../app/controller.dart';
import 'library_providers.dart';
import 'study_editor.dart';
import 'study_images.dart';
import 'study_store.dart';
import 'study_photo_intake.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({required this.isMistake, super.key});
  final bool isMistake;
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = '', _subject = '';
  bool _trash = false, _importing = false;
  int _epoch = -1;
  Timer? _debounce;
  Future<List<_Entry>>? _future;
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _refresh() => setState(() => _epoch = -1);
  Future<List<_Entry>> _load(StudyStore store) async => widget.isMistake
      ? (await store.searchMistakes(
              query: _query,
              subject: _subject,
              trash: _trash,
              limit: 200,
            ))
            .map(
              (m) => _Entry(
                m.id,
                m.title,
                m.subject,
                m.chapter,
                m.question,
                m.errorReason,
                m.revision,
              ),
            )
            .toList()
      : (await store.searchKnowledge(
              query: _query,
              subject: _subject,
              trash: _trash,
              limit: 200,
            ))
            .map(
              (k) => _Entry(
                k.id,
                k.title,
                k.subject,
                k.chapter,
                k.content,
                k.kind,
                k.revision,
              ),
            )
            .toList();
  Future<void> _create() async {
    final id = await showDialog<String>(
      context: context,
      useSafeArea: false,
      builder: (_) => StudyEditor(isMistake: widget.isMistake),
    );
    if (id != null && mounted) {
      context.push('${widget.isMistake ? '/mistakes' : '/knowledge'}/$id');
    }
  }

  Future<void> _import() async {
    if (_importing) return;
    final picked = await pickStudyImages();
    if (picked.isEmpty || !mounted) return;
    setState(() => _importing = true);
    var imported = 0;
    try {
      for (final file in picked) {
        await ref
            .read(studyStoreProvider)
            .importMistake(
              file.path,
              file.name,
              subject: _subject.isEmpty ? '数学' : _subject,
            );
        imported++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已录入 $imported 道图片错题，可分别补充答案与解析。')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已保存 $imported 道；${e is FormatException ? e.message : '其余图片导入失败，请重试。'}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _nativeImport(String kind) async {
    if (kind == 'file') return _import();
    if (_importing) return;
    setState(() => _importing = true);
    try {
      await StudyPhotoIntake.pick(
        ref.read(appControllerProvider),
        isMistake: true,
        camera: kind == 'camera',
        subject: _subject.isEmpty ? '数学' : _subject,
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(studyStoreProvider);
    final colors = Theme.of(context).colorScheme;
    final name = widget.isMistake ? '错题本' : '知识库';
    if (_epoch != store.epoch) {
      _epoch = store.epoch;
      _future = _load(store);
    }
    final small = MediaQuery.sizeOf(context).width < 700;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            small ? 20 : 32,
            20,
            small ? 16 : 32,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _trash ? '$name · 回收区' : name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: _trash ? '返回资料' : '打开回收区',
                    onPressed: () => setState(() {
                      _trash = !_trash;
                      _epoch = -1;
                    }),
                    icon: Icon(
                      _trash
                          ? Icons.inventory_2_outlined
                          : Icons.restore_from_trash_outlined,
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('create-study'),
                    onPressed: _trash ? null : () => act(context, _create),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('新建'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.isMistake
                    ? '保留原题，记录思路，让每次错误都有收获。'
                    : '概念、公式和自己的理解，都值得留下。',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('library-search'),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 250), () {
                    if (mounted) {
                      setState(() {
                        _query = v;
                        _epoch = -1;
                      });
                    }
                  });
                },
                decoration: const InputDecoration(
                  hintText: '搜索标题、正文、章节或标签',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _subject,
                        isExpanded: true,
                        items:
                            [
                                  '',
                                  ...schoolSubjects,
                                  if (_subject.isNotEmpty &&
                                      !schoolSubjects.contains(_subject))
                                    _subject,
                                ]
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      s.isEmpty ? '全部科目' : s,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (s) => setState(() {
                          _subject = s!;
                          _epoch = -1;
                        }),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final subject = await editText(
                        context,
                        title: '按自定义科目筛选',
                        initial: _subject,
                      );
                      if (subject != null && mounted) {
                        setState(() {
                          _subject = subject;
                          _epoch = -1;
                        });
                      }
                    },
                    child: const Text('自定义科目', style: TextStyle(fontSize: 12)),
                  ),
                  if (widget.isMistake && !_trash)
                    if (Platform.isAndroid)
                      PopupMenuButton<String>(
                        tooltip: '快速录入错题',
                        enabled: !_importing,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        onSelected: (kind) =>
                            act(context, () => _nativeImport(kind)),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'camera', child: Text('拍照录题')),
                          PopupMenuItem(
                            value: 'gallery',
                            child: Text('相册录题（每张独立）'),
                          ),
                          PopupMenuItem(
                            value: 'file',
                            child: Text('文件录题（每张独立）'),
                          ),
                        ],
                      )
                    else
                      IconButton(
                        tooltip: '多图录入（每张独立建题）',
                        onPressed: _importing
                            ? null
                            : () => act(context, _import),
                        icon: _importing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined),
                      ),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: FutureBuilder<List<_Entry>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('加载失败，点击重试'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snapshot.data!;
              if (entries.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isMistake
                              ? Icons.menu_book_outlined
                              : Icons.bookmarks_outlined,
                          size: 40,
                          color: colors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _trash
                              ? '回收区为空'
                              : _query.isNotEmpty || _subject.isNotEmpty
                              ? '没有找到相关资料'
                              : '从${widget.isMistake ? '一道错题' : '一个知识点'}开始',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _trash
                              ? '删除的资料可在这里恢复。'
                              : widget.isMistake
                              ? '手动记录题目、导入图片，或从对话保存。\n多张图片导入后，每张建立独立记录。'
                              : '自由记录自己的理解，支持 Markdown 与数学公式。\n也可以从对话中保存内容，再补充自己的思考。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            height: 1.8,
                          ),
                        ),
                        if (!_trash)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: OutlinedButton(
                              onPressed: () => act(context, _create),
                              child: Text(
                                '新建${widget.isMistake ? '错题' : '知识'}',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: small ? 12 : 28,
                  vertical: 8,
                ),
                itemCount: entries.length + (entries.length == 200 ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  if (index == entries.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('当前显示最近 200 条，请使用搜索缩小范围。'),
                    );
                  }
                  final e = entries[index];
                  return ListTile(
                    key: ValueKey(e.id),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    title: Text(
                      e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${e.subject} · ${e.chapter.isEmpty ? e.badge : e.chapter}',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 12,
                            ),
                          ),
                          if (e.preview.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                e.preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    trailing: _trash
                        ? TextButton(
                            onPressed: () => act(
                              context,
                              () => store.setDeleted(
                                e.id,
                                isMistake: widget.isMistake,
                                deleted: false,
                                expectedRevision: e.revision,
                              ),
                            ),
                            child: const Text('恢复'),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _trash
                        ? null
                        : () => context.push(
                            '${widget.isMistake ? '/mistakes' : '/knowledge'}/${e.id}',
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Entry {
  const _Entry(
    this.id,
    this.title,
    this.subject,
    this.chapter,
    this.preview,
    this.badge,
    this.revision,
  );
  final String id, title, subject, chapter, preview, badge;
  final int revision;
}
