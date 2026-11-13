import '../../core/ui/app_menu.dart';

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/ai/ai_options.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/image_viewer.dart';
import '../../core/ui/reasoning_panel.dart';
import 'exam_photo_intake.dart';
import 'exam_ai.dart';
import 'exam_calendar.dart';
import 'exam_detail.dart';
import 'exam_store.dart';
import 'score_editor.dart';
import 'exam_image_editor.dart';
import '../../core/platform/photo_picker.dart';

class ExamSubjectScreen extends ConsumerWidget {
  const ExamSubjectScreen(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    return StreamBuilder<ExamSubject?>(
      stream: (c.db.select(
        c.db.examSubjects,
      )..where((t) => t.id.equals(id))).watchSingleOrNull(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text(context.tr('考试记录读取失败，请重新打开。')));
        }
        if (!snap.hasData) {
          return Center(
            child: Text(
              context.tr(
                snap.connectionState == ConnectionState.waiting
                    ? '正在加载…'
                    : '记录不存在',
              ),
            ),
          );
        }
        final subject = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        BackButton(),
                        Expanded(
                          child: Text(
                            context.tr(subject.subject),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              editSubject(context, c, subject.eventId, subject),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(context.tr('编辑成绩')),
                        ),
                        IconButton(
                          tooltip: context.tr('删除科目'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (d) => AlertDialog(
                                title: Text(d.tr('删除科目')),
                                content: Text(
                                  d.tr('将删除这个科目的成绩、小分表和照片，其他科目保留。此操作无法撤销。'),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d),
                                    child: Text(d.tr('取消')),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(d, true),
                                    child: Text(d.tr('删除')),
                                  ),
                                ],
                              ),
                            );
                            if (yes == true && context.mounted) {
                              await act(context, () async {
                                await c.exams.deleteSubject(id);
                                if (context.mounted) {
                                  context.go('/exams/${subject.eventId}');
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${context.tr('裸分')} ${points(subject.rawScore)}${subject.maximum == null ? '' : ' / ${points(subject.maximum)}'}${subject.usesScaling ? ' · ${context.tr('赋分')} ${points(subject.scaledScore)}' : ''}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (subject.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SelectableText(subject.notes),
                      ),
                    const Divider(height: 32),
                    Text(
                      context.tr('考试资料'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      context.tr('原图保存在本机，备份包含这些照片；只有点击 AI 整理并确认后才会上传所选照片。'),
                    ),
                    StreamBuilder<List<ExamAttachment>>(
                      stream:
                          (c.db.select(c.db.examAttachments)
                                ..where((t) => t.subjectId.equals(id))
                                ..orderBy([
                                  (t) => OrderingTerm.asc(t.createdAt),
                                  (t) => OrderingTerm.asc(t.id),
                                ]))
                              .watch(),
                      builder: (ctx, images) {
                        if (images.hasError) {
                          return Text(ctx.tr('图片读取失败，请重新打开。'));
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final role in examImageRoles.entries)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ctx.tr(role.value),
                                          style: Theme.of(ctx)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                      if (Platform.isAndroid)
                                        IconButton(
                                          tooltip: ctx.tr('拍照'),
                                          icon: const Icon(
                                            Icons.photo_camera_outlined,
                                          ),
                                          onPressed: () => act(
                                            ctx,
                                            () => _pick(
                                              ctx,
                                              c,
                                              role.key,
                                              camera: true,
                                            ),
                                          ),
                                        ),
                                      TextButton.icon(
                                        icon: const Icon(
                                          Icons.add_photo_alternate_outlined,
                                        ),
                                        label: Text(ctx.tr('添加图片')),
                                        onPressed: () => act(
                                          ctx,
                                          () => _pick(ctx, c, role.key),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final image
                                          in (images.data ?? <ExamAttachment>[])
                                              .where((i) => i.role == role.key))
                                        SizedBox(
                                          width: 140,
                                          height: 110,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                InkWell(
                                                  key: Key(
                                                    'exam-image-preview-${image.id}',
                                                  ),
                                                  onTap: () {
                                                    final roleImages =
                                                        (images.data ??
                                                                <
                                                                  ExamAttachment
                                                                >[])
                                                            .where(
                                                              (i) =>
                                                                  i.role ==
                                                                  role.key,
                                                            )
                                                            .toList();
                                                    showImageViewer(
                                                      ctx,
                                                      images: [
                                                        for (final item
                                                            in roleImages)
                                                          ImageViewerItem(
                                                            file: c.files.resolve(
                                                              item.relativePath,
                                                            ),
                                                            heroTag:
                                                                'exam-image-${item.id}',
                                                            cacheWidth: 2000,
                                                            errorText: ctx.tr(
                                                              '图片无法读取，原记录仍保留',
                                                            ),
                                                          ),
                                                      ],
                                                      initialIndex: roleImages
                                                          .indexWhere(
                                                            (i) =>
                                                                i.id ==
                                                                image.id,
                                                          ),
                                                      title: ctx.tr(role.value),
                                                    );
                                                  },
                                                  child: Hero(
                                                    tag:
                                                        'exam-image-${image.id}',
                                                    child: Image.file(
                                                      c.files.resolve(
                                                        image.relativePath,
                                                      ),
                                                      width: 140,
                                                      height: 110,
                                                      fit: BoxFit.cover,
                                                      cacheWidth: 400,
                                                      errorBuilder: (_, _, _) =>
                                                          SizedBox(
                                                            height: 110,
                                                            child: Center(
                                                              child: Text(
                                                                ctx.tr(
                                                                  '图片无法读取，原记录仍保留',
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: Material(
                                                    color: Theme.of(ctx)
                                                        .colorScheme
                                                        .surface
                                                        .withValues(alpha: .92),
                                                    shape: const CircleBorder(),
                                                    child: PopupMenuButton<String>(
                                                      key: Key(
                                                        'exam-image-menu-${image.id}',
                                                      ),
                                                      tooltip: ctx.tr('图片操作'),
                                                      popUpAnimationStyle:
                                                          menuAnimation(ctx),
                                                      position:
                                                          PopupMenuPosition
                                                              .under,
                                                      icon: const Icon(
                                                        Icons.more_vert,
                                                        size: 20,
                                                      ),
                                                      onSelected: (action) =>
                                                          _imageAction(
                                                            ctx,
                                                            c,
                                                            image,
                                                            action,
                                                          ),
                                                      itemBuilder: (_) => [
                                                        PopupMenuItem(
                                                          value: 'edit',
                                                          child: Text(
                                                            ctx.tr(
                                                              '裁剪 / 旋转 / 缩小',
                                                            ),
                                                          ),
                                                        ),
                                                        if (image
                                                                .originalPath !=
                                                            null)
                                                          PopupMenuItem(
                                                            value: 'original',
                                                            child: Text(
                                                              ctx.tr('查看保留的原图'),
                                                            ),
                                                          ),
                                                        const PopupMenuDivider(),
                                                        PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text(
                                                            ctx.tr('删除图片'),
                                                            style: TextStyle(
                                                              color: Theme.of(ctx)
                                                                  .colorScheme
                                                                  .error,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            const Divider(height: 32),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  key: const Key('exam-edit-scores'),
                                  onPressed: () =>
                                      Navigator.of(
                                        ctx,
                                        rootNavigator: true,
                                      ).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              ScoreEditor(subject: subject),
                                        ),
                                      ),
                                  icon: const Icon(Icons.table_rows_outlined),
                                  label: Text(ctx.tr('编辑小分表')),
                                ),
                                OutlinedButton.icon(
                                  onPressed: (images.data ?? []).isEmpty
                                      ? null
                                      : () =>
                                            Navigator.of(
                                              ctx,
                                              rootNavigator: true,
                                            ).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) => ExamAiScreen(
                                                  subject: subject,
                                                  images: images.data!,
                                                ),
                                              ),
                                            ),
                                  icon: const Icon(Icons.auto_awesome_outlined),
                                  label: Text(ctx.tr('AI 整理小分表')),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    if (subject.aiReasoning.isNotEmpty)
                      ReasoningPanel(text: subject.aiReasoning),
                    const SizedBox(height: 16),
                    StreamBuilder<List<ExamScoreRow>>(
                      stream:
                          (c.db.select(c.db.examScoreRows)
                                ..where((t) => t.subjectId.equals(id))
                                ..orderBy([
                                  (t) => OrderingTerm.asc(t.position),
                                ]))
                              .watch(),
                      builder: (ctx, snap) {
                        if (snap.hasError) {
                          return Text(ctx.tr('小分表读取失败，请重新打开。'));
                        }
                        final rows = snap.data ?? [];
                        final drafts = rows
                            .map(
                              (r) => ScoreDraft(
                                id: r.id,
                                parentId: r.parentId,
                                label: r.label,
                                earned: r.earned,
                                maximum: r.maximum,
                              ),
                            )
                            .toList();
                        final (earned, maximum, complete) = scoreTotals(drafts);
                        final parents = rows
                            .map((r) => r.parentId)
                            .nonNulls
                            .toSet();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (rows.isEmpty)
                              Text(ctx.tr('还没有小分表，可手动连续录入，或让 AI 从照片整理。')),
                            if (rows.isNotEmpty)
                              Text(
                                '${ctx.tr('明细合计')} ${points(earned)} / ${rows.any((r) => !parents.contains(r.id) && r.maximum == null) ? '—' : points(maximum)} · ${ctx.tr(complete ? '已填写得分' : '含未知得分，合计不完整')}',
                                style: Theme.of(ctx).textTheme.titleMedium,
                              ),
                            if (subject.rawScore != null &&
                                complete &&
                                (earned - subject.rawScore!).abs() > .001)
                              Text(
                                ctx.tr('明细合计与裸分不同，请核对；不会自动覆盖成绩。'),
                                style: TextStyle(
                                  color: Theme.of(ctx).colorScheme.error,
                                ),
                              ),
                            for (final row in rows)
                              ListTile(
                                contentPadding: EdgeInsets.only(
                                  left: row.parentId == null ? 0 : 24,
                                ),
                                title: Text(row.label),
                                subtitle: row.note.isEmpty
                                    ? null
                                    : Text(row.note),
                                trailing: Text(
                                  parents.contains(row.id)
                                      ? ctx.tr('按小题汇总')
                                      : '${points(row.earned)} / ${points(row.maximum)}',
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _imageAction(
    BuildContext context,
    AppController c,
    ExamAttachment image,
    String action,
  ) async {
    if (!context.mounted) return;
    switch (action) {
      case 'edit':
        await act(context, () => editExamPhoto(context, c, image));
      case 'original':
        if (image.originalPath == null) return;
        await showImageViewer(
          context,
          images: [
            ImageViewerItem(
              file: c.files.resolve(image.originalPath!),
              cacheWidth: 1600,
              errorText: context.tr('原图无法读取。'),
            ),
          ],
          title: context.tr('保留的原图'),
        );
      case 'delete':
        final yes = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(d.tr('删除图片')),
            content: Text(d.tr('删除本机保存的这张照片？')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(d.tr('取消')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(d.tr('删除')),
              ),
            ],
          ),
        );
        if (yes == true && context.mounted) {
          await act(context, () => c.exams.deleteImage(image));
        }
    }
  }

  Future<void> _pick(
    BuildContext context,
    AppController c,
    String role, {
    bool camera = false,
  }) async {
    if (Platform.isAndroid) {
      await ExamPhotoIntake.pick(c, id, role, context: context, camera: camera);
    } else {
      final files = await pickPhotos(context);
      final added = <ExamAttachment>[];
      for (final file in files) {
        added.add(await c.exams.addImage(id, role, file.path));
      }
      for (final image in added) {
        if (!context.mounted) break;
        await editExamPhoto(context, c, image);
      }
    }
  }
}

class ExamAiScreen extends ConsumerStatefulWidget {
  const ExamAiScreen({required this.subject, required this.images, super.key});
  final ExamSubject subject;
  final List<ExamAttachment> images;
  @override
  ConsumerState<ExamAiScreen> createState() => _ExamAiState();
}

class _ExamAiState extends ConsumerState<ExamAiScreen> {
  final selected = <String>{};
  final cancel = CancelToken();
  bool busy = false;
  String reasoning = '', effort = '';
  String? error;
  List<ScoreDraft>? proposal;
  @override
  void initState() {
    super.initState();
    selected.addAll(
      widget.images.where((i) => i.role != 'paper').map((i) => i.id),
    );
  }

  @override
  void dispose() {
    cancel.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final config = AiOptions.forSession(c.config, effort);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('AI 整理小分表'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.tr('仅上传勾选的照片。建议同时选择答题卡和参考答案；主观题没有评分依据时留空。AI 建议必须人工核对。')),
          if (c.demo) Text(context.tr('Mock 模式不读取照片评分，请使用手动录入验证小分表。')),
          if (!AiOptions(config).vision)
            Text(context.tr('当前模型不支持图片，请选择支持视觉的模型。')),
          AppSelectField<String>(
            initialValue: effort,
            decoration: InputDecoration(labelText: context.tr('思考强度')),
            items: [
              for (final e in {
                '': '跟随全局默认',
                'off': AiOptions(c.config).offChoiceLabel,
                for (final level in AiOptions(c.config).reasoningEfforts)
                  level: AiOptions(c.config).label(level),
              }.entries)
                DropdownMenuItem(
                  value: e.key,
                  enabled:
                      e.key.isEmpty ||
                      e.key == 'off' ||
                      c.config.supportsThinking,
                  child: Text(context.tr(e.value)),
                ),
            ],
            onChanged: busy ? null : (v) => setState(() => effort = v ?? ''),
          ),
          for (final image in widget.images)
            CheckboxListTile(
              value: selected.contains(image.id),
              title: Text(context.tr(examImageRoles[image.role]!)),
              secondary: Image.file(
                c.files.resolve(image.relativePath),
                width: 55,
                height: 55,
                fit: BoxFit.cover,
                cacheWidth: 150,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        selected.add(image.id);
                      } else {
                        selected.remove(image.id);
                      }
                    }),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                busy || c.demo || !AiOptions(config).vision || selected.isEmpty
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                      proposal = null;
                      reasoning = '';
                    });
                    try {
                      final rows = await generateExamScores(
                        provider: c.provider,
                        config: config,
                        files: c.files,
                        images: widget.images
                            .where((i) => selected.contains(i.id))
                            .toList(),
                        subject: widget.subject.subject,
                        prompt: c.prompts.text('exam_scores'),
                        cancel: cancel,
                        onReasoning: (value) {
                          if (mounted && value != reasoning) {
                            setState(() => reasoning = value);
                          }
                        },
                      );
                      if (mounted) {
                        await (c.db.update(
                          c.db.examSubjects,
                        )..where((t) => t.id.equals(widget.subject.id))).write(
                          ExamSubjectsCompanion(
                            aiReasoning: Value(reasoning),
                            aiModel: Value(config.model),
                          ),
                        );
                        if (mounted) {
                          setState(() {
                            proposal = rows;
                            busy = false;
                          });
                        }
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(() {
                          busy = false;
                          error = context.tr(
                            'AI 整理失败，未修改小分表。请检查网络、图片及模型配置后重试。',
                          );
                        });
                      }
                    }
                  },
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(context.tr('上传所选照片并整理')),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          if (busy)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('停止并返回')),
            ),
          if (reasoning.isNotEmpty)
            ReasoningPanel(text: reasoning, generating: busy),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (proposal != null) ...[
            const SizedBox(height: 16),
            Text(context.tr('整理完成，尚未修改小分表。打开核对后，可编辑每项分数再保存。')),
            for (final row in proposal!)
              ListTile(
                contentPadding: EdgeInsets.only(
                  left: row.parentId == null ? 0 : 20,
                ),
                title: Text(row.label),
                subtitle: row.note.isEmpty ? null : Text(row.note),
                trailing: Text(
                  '${points(row.earned)} / ${points(row.maximum)}',
                ),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ScoreEditor(subject: widget.subject, proposal: proposal),
                ),
              ),
              child: Text(context.tr('核对并编辑小分表')),
            ),
          ],
        ],
      ),
    );
  }
}
