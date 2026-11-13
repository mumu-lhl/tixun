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
import '../update/update_localization.dart';
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
        title,
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
                  context.l10n.settings,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(context.l10n.makeTheAssistantWorkFor),
                heading(context.l10n.study),
                _SettingsGroup(
                  children: [
                    ListTile(
                      key: const Key('settings-subjects'),
                      leading: const _SettingsIcon(Icons.school_outlined),
                      title: Text(context.l10n.studySubjects),
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
                            title: Text(context.l10n.learningGoals),
                            subtitle: Text(
                              context.l10n.minutesPerDay(
                                l10nArgument((p.stage)),
                                l10nArgument((p.dailyMinutes)),
                              ),
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
                              Text(context.l10n.couldNotReadLearningSettings),
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () =>
                                    ref.invalidate(learningProfileProvider),
                                child: Text(context.l10n.retry),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
                heading(context.l10n.aiService),
                _SettingsGroup(
                  children: [
                    ListTile(
                      key: const Key('settings-ai-usage'),
                      leading: const _SettingsIcon(Icons.analytics_outlined),
                      title: Text(context.l10n.aiUsage),
                      subtitle: Text(context.l10n.aiUsageHelp),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/ai-usage'),
                    ),
                    ListTile(
                      key: const Key('settings-ai'),
                      leading: const _SettingsIcon(Icons.hub_outlined),
                      title: Text(context.l10n.modelsAndConnections),
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
                      title: Text(context.l10n.promptManager),
                      subtitle: Text(context.l10n.teachingStyleAndStudyTask),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/prompts'),
                    ),
                    ListTile(
                      key: const Key('settings-python'),
                      leading: const _SettingsIcon(Icons.code),
                      title: Text(context.l10n.pythonExecution),
                      subtitle: Text(context.l10n.reviewAICodeOrConfigure),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/python'),
                    ),
                  ],
                ),
                heading(context.l10n.appearance),
                const LanguageColorSettings(),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(context.l10n.followSystem),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(context.l10n.light),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(context.l10n.dark),
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
                heading(context.l10n.aboutTiXun),
                Text(context.l10n.openSourceLocalFirstNo),
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
        ? context.l10n.checkingForUpdates
        : status.message == null
        ? null
        : updateMessageText(context, status.message!, tag: status.messageTag);
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
          title: Text(context.l10n.currentVersion),
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
                label: Text(context.l10n.stable),
              ),
              ButtonSegment(
                value: UpdateChannel.prerelease,
                label: Text(context.l10n.prerelease),
              ),
              ButtonSegment(
                value: UpdateChannel.nightly,
                label: Text(context.l10n.nightly),
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
            child: Text(context.l10n.checkForUpdates),
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
            context.l10n.downloading(
              l10nArgument((((status.downloadProgress ?? 0) * 100).round())),
            ),
          ),
        ],
        if (status.staged) ...[
          const SizedBox(height: 8),
          Text(context.l10n.readyTheUpdateWillApply),
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
                  child: Text(context.l10n.downloadUpdate),
                ),
              if (Platform.isAndroid && status.readyToInstall)
                FilledButton(
                  onPressed: () =>
                      ref.read(updateStatusProvider.notifier).installOrApply(),
                  child: Text(context.l10n.install),
                ),
              if (status.installBlocked)
                OutlinedButton(
                  // openInstallSettings is a MethodChannel call that can
                  // throw when unimplemented: route it through act so a
                  // failure shows a snackbar instead of an unhandled
                  // async exception.
                  onPressed: () => act(context, openInstallSettings),
                  child: Text(context.l10n.openInstallSettings),
                ),
              if (Platform.isLinux && status.staged) ...[
                FilledButton(
                  onPressed: () =>
                      ref.read(updateStatusProvider.notifier).installOrApply(),
                  child: Text(context.l10n.restartNowToUpdate),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(updateStatusProvider.notifier).discardStaged(),
                  child: Text(context.l10n.cancel),
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
