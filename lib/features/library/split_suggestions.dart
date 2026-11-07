import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/ai/region_tool.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
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
) => store.acceptQuestionRegion(operationId, index, bytes, (
  left: crop.left,
  top: crop.top,
  right: crop.right,
  bottom: crop.bottom,
), turns);

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
            error: (_, _) => Text(context.tr("分题原图读取失败。")),
            data: (image) {
              if (image == null || image.sessionId != operation.sessionId) {
                return Text(context.tr("原图记录不存在，无法继续分题。"));
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
                      context.tr("分题建议 · {0} 个范围", [regions.length]),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr("AI 边界可能不准确。逐题打开检查，可重新框选、旋转后保存；原图与裁剪结果都会保留。"),
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Image.file(
                      c.files.resolve(image.relativePath),
                      height: 200,
                      cacheWidth: 700,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Text(context.tr("图片无法解码。")),
                    ),
                    for (var i = 0; i < regions.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(regions[i].label),
                        subtitle: Text(context.subjectName(regions[i].subject)),
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
                                  content: Text(context.tr("分题已保存，原图已保留。")),
                                  action: SnackBarAction(
                                    label: context.tr("查看"),
                                    onPressed: () =>
                                        context.push('/mistakes/$selected'),
                                  ),
                                ),
                              );
                            }
                          }),
                          child: Text(
                            accepted['$i'] is String
                                ? context.tr("查看错题")
                                : context.tr("检查并保存"),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
    } catch (_) {
      return Text(context.tr("分题建议数据不完整，请重新请求；已有资料未改变。"));
    }
  }
}
