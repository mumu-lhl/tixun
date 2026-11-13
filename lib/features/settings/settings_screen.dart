import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../progress/profile_editor.dart';
import '../review/review_providers.dart';
import '../update/android_install.dart';
import '../update/update_models.dart';
import '../update/update_providers.dart';
import 'backup_panel.dart';
import 'language_color_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final colors = Theme.of(context).colorScheme;
    Widget heading(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
      child: Text(
        context.tr(title),
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: colors.onSurfaceVariant),
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
                _SettingsGroup(
                  children: [
                    ListTile(
                      key: const Key('settings-subjects'),
                      leading: const _SettingsIcon(Icons.school_outlined),
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
                            leading: const _SettingsIcon(Icons.flag_outlined),
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
                          error: (_, _) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('学习设置读取失败')),
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () =>
                                    ref.invalidate(learningProfileProvider),
                                child: Text(context.tr('重试')),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
                heading('AI 服务'),
                _SettingsGroup(
                  children: [
                    ListTile(
                      key: const Key('settings-ai'),
                      leading: const _SettingsIcon(Icons.hub_outlined),
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
                      leading: const _SettingsIcon(Icons.edit_note_outlined),
                      title: Text(context.tr('提示词管理')),
                      subtitle: Text(context.tr('教学风格与学习任务提示词')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/prompts'),
                    ),
                    ListTile(
                      key: const Key('settings-python'),
                      leading: const _SettingsIcon(Icons.code),
                      title: Text(context.tr('Python 执行')),
                      subtitle: Text(context.tr('审查 AI 代码或设置自动执行权限')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/python'),
                    ),
                  ],
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
                const _UpdateSettings(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// In-app update section: current version, channel selector, manual check,
/// status, download progress and the install / apply actions.
class _UpdateSettings extends ConsumerWidget {
  const _UpdateSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channel = ref.watch(updateChannelProvider);
    final status = ref.watch(updateStatusProvider);
    final version = ref.watch(updateCurrentVersionProvider);
    final busy =
        status.status == UpdateStatus.checking ||
        status.downloadProgress != null;
    final String? statusText = status.status == UpdateStatus.checking
        ? context.tr('正在检查更新…')
        : status.message == null
        ? null
        : context.tr(status.message!, status.messageArgs);
    final showActions =
        (status.status == UpdateStatus.available &&
            !status.staged &&
            !status.readyToInstall) ||
        (Platform.isAndroid && status.readyToInstall) ||
        (Platform.isLinux && status.staged) ||
        status.installBlocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.system_update_outlined),
          title: Text(context.tr('当前版本')),
          subtitle: Text(
            version.when(
              data: (v) => v,
              loading: () => '…',
              error: (_, _) => '…',
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<UpdateChannel>(
            segments: [
              ButtonSegment(
                value: UpdateChannel.stable,
                label: Text(context.tr('正式版')),
              ),
              ButtonSegment(
                value: UpdateChannel.prerelease,
                label: Text(context.tr('预发布')),
              ),
              ButtonSegment(
                value: UpdateChannel.nightly,
                label: Text(context.tr('nightly')),
              ),
            ],
            selected: {channel},
            onSelectionChanged: (v) =>
                ref.read(updateChannelProvider.notifier).setChannel(v.first),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: busy
                ? null
                : () => ref
                      .read(updateStatusProvider.notifier)
                      .checkForUpdate(manual: true),
            child: Text(context.tr('检查更新')),
          ),
        ),
        if (statusText != null) ...[
          const SizedBox(height: 8),
          Text(statusText),
        ],
        if (status.downloadProgress != null) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: status.downloadProgress),
          const SizedBox(height: 4),
          Text(
            context.tr('正在下载… {0}%', [
              ((status.downloadProgress ?? 0) * 100).round(),
            ]),
          ),
        ],
        if (status.staged) ...[
          const SizedBox(height: 8),
          Text(context.tr('已准备好，下次启动时更新')),
        ],
        if (showActions) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status.status == UpdateStatus.available &&
                  !status.staged &&
                  !status.readyToInstall &&
                  status.downloadProgress == null)
                FilledButton(
                  onPressed: () => ref
                      .read(updateStatusProvider.notifier)
                      .downloadAndPrepare(),
                  child: Text(context.tr('下载更新')),
                ),
              if (Platform.isAndroid && status.readyToInstall)
                FilledButton(
                  onPressed: () =>
                      ref.read(updateStatusProvider.notifier).installOrApply(),
                  child: Text(context.tr('安装')),
                ),
              if (status.installBlocked)
                OutlinedButton(
                  // openInstallSettings is a MethodChannel call that can
                  // throw when unimplemented: route it through act so a
                  // failure shows a snackbar instead of an unhandled
                  // async exception.
                  onPressed: () => act(context, openInstallSettings),
                  child: Text(context.tr('打开安装设置')),
                ),
              if (Platform.isLinux && status.staged) ...[
                FilledButton(
                  onPressed: () =>
                      ref.read(updateStatusProvider.notifier).installOrApply(),
                  child: Text(context.tr('立即重启更新')),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(updateStatusProvider.notifier).discardStaged(),
                  child: Text(context.tr('取消')),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// One surface per settings section; each row keeps its own rounded ink path.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.brightness == Brightness.dark
          ? colors.surfaceContainer
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ListTileTheme(
        data: ListTileTheme.of(context).copyWith(minTileHeight: 78),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  indent: 70,
                  endIndent: 16,
                  color: colors.outlineVariant.withValues(alpha: .45),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: colors.onSecondaryContainer),
    );
  }
}
