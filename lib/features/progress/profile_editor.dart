import '../../core/ui/app_menu.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/l10n/app_strings.dart';
import '../review/review_providers.dart';
import 'learning_profile.dart';

class ProfileEditor extends ConsumerStatefulWidget {
  const ProfileEditor(this.profile, {super.key});
  final LearningProfile profile;
  @override
  ConsumerState<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<ProfileEditor> {
  late final stage = TextEditingController(text: widget.profile.stage),
      region = TextEditingController(text: widget.profile.region),
      exam = TextEditingController(text: widget.profile.exam),
      minutes = TextEditingController(text: '${widget.profile.dailyMinutes}'),
      scope = TextEditingController(text: widget.profile.scope);
  late DateTime? date = widget.profile.examDate;
  late String teaching = widget.profile.teaching;
  bool saving = false;
  String? failure;
  @override
  void dispose() {
    for (final c in [stage, region, exam, minutes, scope]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr("学习设置")),
    scrollable: true,
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.profile.partialFallback)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                context.tr('部分设置无法读取，已用默认值。'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          for (final (ctrl, label, lines, keyboard) in [
            (stage, '学习阶段', 1, null),
            (region, '地区（可选，如浙江）', 1, null),
            (exam, '目标考试（可选）', 1, null),
            (minutes, '每日可用分钟数（5–480）', 1, TextInputType.number),
            (scope, '学科与学习范围（自由填写）', 3, null),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: ctrl,
                enabled: !saving,
                keyboardType: keyboard,
                minLines: lines,
                maxLines: lines + 2,
                decoration: InputDecoration(labelText: context.tr(label)),
              ),
            ),
          AppSelectField<String>(
            initialValue: teaching,
            decoration: InputDecoration(labelText: context.tr("新对话的教学方式")),
            items: [
              DropdownMenuItem(
                value: 'guided',
                child: Text(context.tr("引导教学")),
              ),
              DropdownMenuItem(
                value: 'direct',
                child: Text(context.tr("直接解答")),
              ),
              DropdownMenuItem(value: 'exam', child: Text(context.tr("考试训练"))),
            ],
            onChanged: saving ? null : (v) => setState(() => teaching = v!),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final first = DateTime(now.year - 1);
                        final last = DateTime(now.year + 10);
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              date?.isBefore(first) == true ||
                                  date?.isAfter(last) == true
                              ? now
                              : date ?? now,
                          firstDate: first,
                          lastDate: last,
                        );
                        if (picked != null && mounted) {
                          setState(() => date = picked);
                        }
                      },
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  date == null
                      ? context.tr("设置考试日期")
                      : '${date!.year}-${date!.month}-${date!.day}',
                ),
              ),
              if (date != null)
                TextButton(
                  onPressed: saving ? null : () => setState(() => date = null),
                  child: Text(context.tr("清除日期")),
                ),
            ],
          ),
          if (failure != null)
            Text(
              failure!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: Text(context.tr("取消")),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                setState(() => saving = true);
                try {
                  final n = int.tryParse(minutes.text.trim());
                  if (n == null) throw const FormatException('每日时间请输入整数分钟。');
                  await LearningProfile(
                    stage: stage.text,
                    region: region.text,
                    exam: exam.text,
                    examDate: date,
                    dailyMinutes: n,
                    scope: scope.text,
                    teaching: teaching,
                  ).save(ref.read(appControllerProvider).db);
                  ref.invalidate(learningProfileProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    setState(
                      () => failure = e is FormatException
                          ? e.message
                          : '保存失败，请重试。',
                    );
                  }
                }
                if (mounted) setState(() => saving = false);
              },
        child: Text(saving ? context.tr("保存中…") : context.tr("保存")),
      ),
    ],
  );
}
