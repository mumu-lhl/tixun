import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/l10n/app_strings.dart';
import '../progress/profile_editor.dart';
import '../review/review_providers.dart';
import 'backup_panel.dart';
import 'language_color_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    Widget heading(String title) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        context.tr(title),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 700 ? 20 : 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('设置'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(context.tr('让学习助手适合你的使用习惯')),
                heading('学习'),
                ListTile(
                  key: const Key('settings-subjects'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.school_outlined),
                  title: Text(context.tr('学习科目')),
                  subtitle: Text(
                    c.learningSubjects.map(context.subjectName).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/subjects'),
                ),
                ref
                    .watch(learningProfileProvider)
                    .when(
                      data: (p) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(context.tr('学习目标')),
                        subtitle: Text(
                          context.tr('{0} · 每日 {1} 分钟', [
                            p.stage,
                            p.dailyMinutes,
                          ]),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => ProfileEditor(p),
                        ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text(context.tr('学习设置读取失败')),
                    ),
                heading('AI 服务'),
                ListTile(
                  key: const Key('settings-ai'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.hub_outlined),
                  title: Text(context.tr('模型与连接')),
                  subtitle: Text(
                    '${c.config.kind == 'chatgpt'
                        ? 'ChatGPT'
                        : c.config.kind == 'deepseek'
                        ? 'DeepSeek'
                        : 'OpenAI-compatible'} · ${c.config.model}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/ai'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_note_outlined),
                  title: Text(context.tr('提示词管理')),
                  subtitle: Text(context.tr('自定义教学风格、讲解、出题与分题提示词')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/prompts'),
                ),
                heading('外观'),
                const LanguageColorSettings(),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(context.tr('跟随系统')),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(context.tr('浅色')),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(context.tr('深色')),
                      ),
                    ],
                    selected: {c.themeMode},
                    onSelectionChanged: (v) => c.theme(v.first),
                  ),
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 20),
                const BackupPanel(),
                heading('关于题训'),
                Text(
                  context.tr(
                    '开源 · 本地优先 · 无需账号。已有资料和练习可离线使用，AI 请求仅发送本次所需内容。卸载应用前请先导出完整备份。',
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
