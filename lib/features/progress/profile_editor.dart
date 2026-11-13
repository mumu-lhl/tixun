import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/core/l10n/app_error_localization.dart';

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
  Object? failure;
  @override
  void dispose() {
    for (final c in [stage, region, exam, minutes, scope]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.learningSettings),
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
                context.l10n.someSettingsCouldNotBe,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          for (final (ctrl, label, lines, keyboard) in [
            (stage, context.l10n.learningStage, 1, null),
            (region, context.l10n.regionOptionalEGZhejiang, 1, null),
            (exam, context.l10n.targetExamOptional, 1, null),
            (
              minutes,
              context.l10n.dailyTimeInMinutes5,
              1,
              TextInputType.number,
            ),
            (scope, context.l10n.subjectsAndLearningScope, 3, null),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: ctrl,
                enabled: !saving,
                keyboardType: keyboard,
                minLines: lines,
                maxLines: lines + 2,
                decoration: InputDecoration(labelText: label),
              ),
            ),
          AppSelectField<String>(
            initialValue: teaching,
            decoration: InputDecoration(
              labelText: context.l10n.teachingModeForNewConversations,
            ),
            items: [
              DropdownMenuItem(
                value: 'guided',
                child: Text(context.l10n.guidedLearning),
              ),
              DropdownMenuItem(
                value: 'direct',
                child: Text(context.l10n.directAnswer),
              ),
              DropdownMenuItem(
                value: 'exam',
                child: Text(context.l10n.examPractice),
              ),
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
                      ? context.l10n.setExamDate
                      : '${date!.year}-${date!.month}-${date!.day}',
                ),
              ),
              if (date != null)
                TextButton(
                  onPressed: saving ? null : () => setState(() => date = null),
                  child: Text(context.l10n.clearDate),
                ),
            ],
          ),
          if (failure != null)
            Text(
              failureText(context.l10n, failure!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                setState(() => saving = true);
                try {
                  final n = int.tryParse(minutes.text.trim());
                  if (n == null) {
                    throw const AppFormatException(
                      AppErrorCode.errorEnterTheDailyTimeAsA,
                      '每日时间请输入整数分钟。',
                    );
                  }
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
                          ? e
                          : const AppFormatException(
                              AppErrorCode.errorSaveTryAgain,
                              '保存失败，请重试。',
                            ),
                    );
                  }
                }
                if (mounted) setState(() => saving = false);
              },
        child: Text(saving ? context.l10n.savingEllipsis : context.l10n.save),
      ),
    ],
  );
}
