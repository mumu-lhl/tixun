import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../app/controller.dart';
import '../../core/ai/region_tool.dart';
import '../../core/database/database.dart';
import '../../core/ui/actions.dart';
import 'image_editor.dart';
import 'study_store.dart';

Future<String> saveSplitSuggestion(
  StudyStore store,
  String operationId,
  int index,
  Uint8List bytes,
  Rect crop,
  int turns,
) async {
  if (![
        crop.left,
        crop.top,
        crop.right,
        crop.bottom,
      ].every((v) => v.isFinite) ||
      crop.left < 0 ||
      crop.top < 0 ||
      crop.right > 1 ||
      crop.bottom > 1 ||
      crop.width <= 0 ||
      crop.height <= 0 ||
      turns < 0 ||
      turns > 3) {
    throw const FormatException('用户裁剪范围无效。');
  }
  if (bytes.isEmpty ||
      bytes.length > 8 * 1024 * 1024 ||
      index < 0 ||
      index > 11) {
    throw const FormatException('分题图片或编号无效。');
  }
  final relative = 'attachments/${const Uuid().v4()}.png';
  var used = false;
  var attached = false;
  try {
    final file = store.files.resolve(relative);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    final id = await store.db.transaction(() async {
      final db = store.db;
      final op =
          await (db.select(db.aiToolOperations)..where(
                (o) =>
                    o.id.equals(operationId) &
                    o.name.equals('suggest_question_regions') &
                    o.status.equals('succeeded'),
              ))
              .getSingle();
      final data = (jsonDecode(op.result!) as Map).cast<String, dynamic>();
      final regions = data['regions'] as List;
      if (index >= regions.length) throw const FormatException('未找到此分题建议。');
      final region = QuestionRegion.fromJson(
        (regions[index] as Map).cast<String, dynamic>(),
      );
      final accepted = (data['accepted'] as Map? ?? {}).cast<String, dynamic>();
      final prior = accepted['$index'];
      if (prior is String) {
        await store.mistake(prior, includeDeleted: true);
        return prior;
      }
      final image =
          await (db.select(db.attachments)..where(
                (a) =>
                    a.id.equals(data['image_id'] as String) &
                    a.sessionId.equals(op.sessionId),
              ))
              .getSingle();
      final row = await store.saveMistake(
        MistakeDraft(
          title: region.label,
          subject: region.subject,
          question: region.question,
          aiAnalysis: region.question.isEmpty
              ? ''
              : '题目文字由 AI 从图片转录，尚未核对，请以原图为准。',
        ),
        sourceSessionId: op.sessionId,
        sourceMessageId: op.runId,
      );
      final original = await store.addImageReference(
        row.id,
        image.relativePath,
        image.mime,
        image.byteLength,
        isMistake: true,
      );
      await store.addImageReference(
        row.id,
        relative,
        'image/png',
        bytes.length,
        isMistake: true,
        parentId: original.id,
        role: 'crop',
      );
      await (db.update(
        db.aiToolOperations,
      )..where((o) => o.id.equals(operationId))).write(
        AiToolOperationsCompanion(
          result: Value(
            jsonEncode({
              ...data,
              'accepted': {...accepted, '$index': row.id},
              'user_crops': {
                ...(data['user_crops'] as Map? ?? {}),
                '$index': {
                  'left': crop.left,
                  'top': crop.top,
                  'right': crop.right,
                  'bottom': crop.bottom,
                  'clockwise_turns': turns,
                },
              },
            }),
          ),
        ),
      );
      attached = true;
      return row.id;
    });
    used = attached;
    store.changed();
    return id;
  } finally {
    if (!used && await store.files.resolve(relative).exists()) {
      await store.files.resolve(relative).delete();
    }
  }
}

final _splitImageProvider = FutureProvider.autoDispose
    .family<Attachment?, String>((ref, id) {
      final db = ref.read(appControllerProvider).db;
      return (db.select(
        db.attachments,
      )..where((a) => a.id.equals(id))).getSingleOrNull();
    });

class SplitSuggestionCard extends ConsumerWidget {
  const SplitSuggestionCard(this.operation, {super.key});
  final AiToolOperation operation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(appControllerProvider);
    try {
      final data = (jsonDecode(operation.result!) as Map)
          .cast<String, dynamic>();
      final regions = (data['regions'] as List)
          .map(
            (r) => QuestionRegion.fromJson((r as Map).cast<String, dynamic>()),
          )
          .toList();
      final accepted = (data['accepted'] as Map? ?? {}).cast<String, dynamic>();
      return ref
          .watch(_splitImageProvider(data['image_id'] as String))
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text('分题原图读取失败。'),
            data: (image) {
              if (image == null || image.sessionId != operation.sessionId) {
                return const Text('原图记录不存在，无法继续分题。');
              }
              return Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '分题建议 · ${regions.length} 个范围',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AI 边界可能不准确。逐题打开检查，可重新框选、旋转后保存；原图与裁剪结果都会保留。',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Image.file(
                      c.files.resolve(image.relativePath),
                      height: 200,
                      cacheWidth: 700,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text('图片无法解码。'),
                    ),
                    for (var i = 0; i < regions.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(regions[i].label),
                        subtitle: Text(regions[i].subject),
                        trailing: TextButton(
                          key: Key('check-region-$i'),
                          onPressed: () => act(context, () async {
                            final prior = accepted['$i'];
                            if (prior is String) {
                              context.push('/mistakes/$prior');
                              return;
                            }
                            final region = regions[i];
                            final selected = await showDialog<String>(
                              context: context,
                              useSafeArea: false,
                              builder: (_) => StudyImageEditor(
                                attachment: StudyAttachment(
                                  id: image.id,
                                  mistakeId: null,
                                  knowledgeId: null,
                                  relativePath: image.relativePath,
                                  mime: image.mime,
                                  byteLength: image.byteLength,
                                  parentId: null,
                                  role: 'original',
                                  deleted: false,
                                ),
                                isMistake: true,
                                initialCrop: Rect.fromLTRB(
                                  region.left,
                                  region.top,
                                  region.right,
                                  region.bottom,
                                ),
                                onCreate: (bytes, crop, turns) =>
                                    saveSplitSuggestion(
                                      c.study,
                                      operation.id,
                                      i,
                                      bytes,
                                      crop,
                                      turns,
                                    ),
                              ),
                            );
                            if (selected != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('分题已保存，原图已保留。'),
                                  action: SnackBarAction(
                                    label: '查看',
                                    onPressed: () =>
                                        context.push('/mistakes/$selected'),
                                  ),
                                ),
                              );
                            }
                          }),
                          child: Text(
                            accepted['$i'] is String ? '查看错题' : '检查并保存',
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
    } catch (_) {
      return const Text('分题建议数据不完整，请重新请求；已有资料未改变。');
    }
  }
}
