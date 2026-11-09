import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/controller.dart';
import 'android_install.dart';
import 'linux_staging.dart';
import 'update_models.dart';
import 'update_service.dart';

/// Nightly tag baked into this build via `--dart-define=TIXUN_NIGHTLY_TAG=...`
/// (e.g. `nightly-20261109-203000`); empty for ordinary and formal release
/// builds.
const String nightlyTag = String.fromEnvironment(
  'TIXUN_NIGHTLY_TAG',
  defaultValue: '',
);

/// Pref keys for the in-app update feature.
const String _channelPref = 'update_channel';
const String _lastAutoCheckPref = 'update_last_auto_check';

/// Display string for the running build, e.g. `0.5.2+7`, plus
/// ` · nightly-20261109-203000` when this is a nightly build.
final updateCurrentVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final display = '${info.version}+${info.buildNumber}';
  return nightlyTag.isEmpty ? display : '$display · $nightlyTag';
});

/// Holds the release channel the user opted into.
///
/// Reads pref `update_channel` on init (default stable). Changing it
/// persists the pref and triggers an immediate check on the new channel.
class UpdateChannelNotifier extends Notifier<UpdateChannel> {
  bool _selectionMade = false;

  @override
  UpdateChannel build() {
    _loadSaved();
    return UpdateChannel.stable;
  }

  Future<void> _loadSaved() async {
    try {
      final saved = await ref
          .read(appControllerProvider)
          .db
          .preference(_channelPref);
      final channel = UpdateChannel.values.firstWhere(
        (c) => c.name == saved,
        orElse: () => UpdateChannel.stable,
      );
      if (!_selectionMade) state = channel;
    } catch (_) {
      // Keep the default; an explicit selection later persists.
    }
  }

  Future<void> setChannel(UpdateChannel channel) async {
    if (channel == state) return;
    _selectionMade = true;
    state = channel;
    try {
      await ref
          .read(appControllerProvider)
          .db
          .setPreference(_channelPref, channel.name);
    } catch (_) {
      // The in-memory selection still applies for this session.
    }
    await ref.read(updateStatusProvider.notifier).checkForUpdate(manual: true);
  }
}

final updateChannelProvider =
    NotifierProvider<UpdateChannelNotifier, UpdateChannel>(
      UpdateChannelNotifier.new,
    );

enum UpdateStatus { idle, checking, upToDate, available, noneAvailable, failed }

/// One snapshot of the update state shown in Settings.
///
/// [message] is a Chinese l10n key (with [messageArgs] for `{0}` style
/// placeholders); the UI translates it with `context.tr` at display time.
class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.idle,
    this.release,
    this.message,
    this.messageArgs = const [],
    this.downloadProgress,
    this.staged = false,
    this.readyToInstall = false,
    this.installBlocked = false,
  });

  final UpdateStatus status;

  /// The candidate release, when one was found.
  final ReleaseInfo? release;

  /// Short status text (l10n key), or null when nothing should be shown.
  final String? message;
  final List<Object?> messageArgs;

  /// Download progress 0..1 while downloading, null otherwise.
  final double? downloadProgress;

  /// Linux: an update is staged and marked for the next launch.
  final bool staged;

  /// Android: a verified APK is downloaded and ready to install.
  final bool readyToInstall;

  /// Android: installing was refused because unknown apps are not allowed;
  /// the UI offers to open the system install settings.
  final bool installBlocked;

  UpdateState copyWith({
    UpdateStatus? status,
    ReleaseInfo? release,
    String? message,
    List<Object?>? messageArgs,
    double? downloadProgress,
    bool? staged,
    bool? readyToInstall,
    bool? installBlocked,
    // Nullable fields cannot be cleared by passing null (null means
    // "keep"), so clearing needs an explicit flag.
    bool clearMessage = false,
    bool clearDownloadProgress = false,
  }) {
    return UpdateState(
      status: status ?? this.status,
      release: release ?? this.release,
      message: clearMessage ? null : (message ?? this.message),
      messageArgs: messageArgs ?? this.messageArgs,
      downloadProgress: clearDownloadProgress
          ? null
          : (downloadProgress ?? this.downloadProgress),
      staged: staged ?? this.staged,
      readyToInstall: readyToInstall ?? this.readyToInstall,
      installBlocked: installBlocked ?? this.installBlocked,
    );
  }
}

/// Owns the update check / download / install flow and the [UpdateState]
/// shown in Settings.
class UpdateStatusNotifier extends Notifier<UpdateState> {
  final UpdateService _service = UpdateService();
  String? _assetName;
  String? _apkPath;

  @override
  UpdateState build() {
    // A Linux update staged in an earlier session is still pending: surface
    // it so Settings can offer to apply or discard it without re-downloading.
    if (Platform.isLinux) {
      try {
        final pending = readPendingUpdate();
        if (pending != null) {
          return UpdateState(
            status: UpdateStatus.available,
            message: '发现新版本 {0}',
            messageArgs: [pending.tag],
            staged: true,
          );
        }
      } catch (_) {
        // A broken marker must never block startup; it reads as absent.
      }
    }
    return const UpdateState();
  }

  /// Runs [UpdateService.check] on the selected channel.
  ///
  /// Manual checks always run; automatic checks are gated by the 6h rule
  /// in the app-host hook. On completion (any outcome) the
  /// `update_last_auto_check` timestamp is written, so a manual check also
  /// resets the automatic-check window.
  Future<void> checkForUpdate({bool manual = false}) async {
    if (state.status == UpdateStatus.checking) return;
    _assetName = null;
    _apkPath = null;
    state = state.copyWith(
      status: UpdateStatus.checking,
      clearMessage: true,
      messageArgs: const [],
      clearDownloadProgress: true,
      installBlocked: false,
      readyToInstall: false,
    );
    try {
      final info = await PackageInfo.fromPlatform();
      final channel = ref.read(updateChannelProvider);
      final outcome = await _service.check(
        channel,
        // Slice A compares the version without the build number.
        currentVersion: info.version,
        embeddedNightlyTag: nightlyTag,
      );
      switch (outcome.kind) {
        case UpdateCheckKind.upToDate:
          state = state.copyWith(
            status: UpdateStatus.upToDate,
            release: outcome.release,
            message: '已是最新版本',
            messageArgs: const [],
          );
        case UpdateCheckKind.available:
          final release = outcome.release;
          if (release == null) {
            state = state.copyWith(
              status: UpdateStatus.failed,
              message: '检查失败，请稍后重试',
              messageArgs: const [],
            );
            break;
          }
          String? assetName;
          try {
            assetName = await _resolveAssetName(channel, release);
          } catch (_) {
            assetName = null;
          }
          if (assetName == null) {
            state = state.copyWith(
              status: UpdateStatus.failed,
              message: '当前平台暂不支持应用内更新',
              messageArgs: const [],
            );
            break;
          }
          _assetName = assetName;
          state = state.copyWith(
            status: UpdateStatus.available,
            release: release,
            message: '发现新版本 {0}',
            messageArgs: [release.tag],
          );
        case UpdateCheckKind.noneAvailable:
          state = state.copyWith(
            status: UpdateStatus.noneAvailable,
            release: outcome.release,
            message: outcome.message ?? '暂无新版本',
            messageArgs: const [],
          );
        case UpdateCheckKind.failed:
          state = state.copyWith(
            status: UpdateStatus.failed,
            release: outcome.release,
            message: outcome.message ?? '检查失败，请稍后重试',
            messageArgs: const [],
          );
      }
    } catch (_) {
      state = state.copyWith(
        status: UpdateStatus.failed,
        message: '检查失败，请稍后重试',
        messageArgs: const [],
      );
    } finally {
      await _markCheckTimestamp();
    }
  }

  Future<String?> _resolveAssetName(
    UpdateChannel channel,
    ReleaseInfo release,
  ) async {
    if (Platform.isAndroid) {
      final abi = await androidAbiAsset();
      return 'tixun-${release.tag}-android-$abi-release.apk';
    }
    if (Platform.isLinux) {
      return 'tixun-${release.tag}-linux-x64.tar.gz';
    }
    return null;
  }

  /// Downloads the resolved asset, verifies its SHA-256, then prepares it:
  /// Android keeps the verified APK for install; Linux stages it and marks
  /// it pending for the next launch. On a verification mismatch the file is
  /// deleted, the status becomes failed, and nothing proceeds.
  Future<void> downloadAndPrepare() async {
    final current = state;
    if (current.status != UpdateStatus.available ||
        current.release == null ||
        _assetName == null ||
        current.downloadProgress != null) {
      return;
    }
    final release = current.release!;
    final assetName = _assetName!;
    state = current.copyWith(downloadProgress: 0, installBlocked: false);
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = p.join(tempDir.path, assetName);
      final file = await _service.downloadAsset(
        release: release,
        assetName: assetName,
        savePath: savePath,
        onProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(downloadProgress: received / total);
          }
        },
      );
      final expected = await _service.fetchExpectedSha256(release, assetName);
      final ok =
          expected != null && await _service.verifySha256(file, expected);
      if (!ok) {
        try {
          await file.delete();
        } catch (_) {}
        state = state.copyWith(
          status: UpdateStatus.failed,
          message: '下载校验失败，请重试',
          messageArgs: const [],
          clearDownloadProgress: true,
        );
        return;
      }
      if (Platform.isAndroid) {
        // getTemporaryDirectory() is the app cache dir on Android, where
        // the native installer requires the APK to live.
        _apkPath = file.path;
        state = state.copyWith(
          clearDownloadProgress: true,
          readyToInstall: true,
        );
      } else if (Platform.isLinux) {
        final staged = await stageLinuxUpdate(
          tarGzFile: file,
          tag: release.tag,
        );
        await markPendingUpdate(tag: release.tag, stagedPath: staged.path);
        try {
          await file.delete();
        } catch (_) {}
        state = state.copyWith(clearDownloadProgress: true, staged: true);
      } else {
        state = state.copyWith(
          status: UpdateStatus.failed,
          message: '当前平台暂不支持应用内更新',
          messageArgs: const [],
          clearDownloadProgress: true,
        );
      }
    } catch (_) {
      state = state.copyWith(
        status: UpdateStatus.failed,
        message: '下载失败，请稍后重试',
        messageArgs: const [],
        clearDownloadProgress: true,
      );
    }
  }

  /// Android + ready APK: opens the package installer. Linux + staged:
  /// applies the pending update (restarts the process on success and never
  /// returns). When Android refuses the install, the status guides the user
  /// to the system install settings instead of failing outright.
  Future<void> installOrApply() async {
    if (Platform.isAndroid) {
      final apkPath = _apkPath;
      if (!state.readyToInstall || apkPath == null) return;
      try {
        await installApk(apkPath);
      } on InstallNotAllowedException {
        state = state.copyWith(
          message: '需要允许安装未知应用，请在系统设置中开启后重试。',
          messageArgs: const [],
          installBlocked: true,
        );
      } catch (_) {
        state = state.copyWith(
          status: UpdateStatus.failed,
          message: '安装失败，请稍后重试',
          messageArgs: const [],
        );
      }
      return;
    }
    if (Platform.isLinux) {
      if (!state.staged) return;
      final result = await applyPendingUpdate();
      // Success never returns (the process restarts).
      if (result == ApplyResult.nothingPending) {
        state = state.copyWith(staged: false);
      } else if (result == ApplyResult.failed) {
        state = state.copyWith(
          status: UpdateStatus.failed,
          message: '更新应用失败，请稍后重试',
          messageArgs: const [],
        );
      }
      return;
    }
  }

  /// Linux: discards the staged update (marker + staging directory) and
  /// clears the staged state. The release stays `available` so the user
  /// can download it again.
  Future<void> discardStaged() async {
    try {
      if (Platform.isLinux) await discardPendingUpdate();
    } catch (_) {
      // Discard is best effort; clear the local state regardless.
    }
    _apkPath = null;
    final release = state.release;
    state = state.copyWith(
      staged: false,
      readyToInstall: false,
      clearDownloadProgress: true,
      installBlocked: false,
      status: release == null ? UpdateStatus.idle : UpdateStatus.available,
      message: release == null ? null : '发现新版本 {0}',
      clearMessage: release == null,
      messageArgs: release == null ? const [] : [release.tag],
    );
  }

  Future<void> _markCheckTimestamp() async {
    try {
      await ref
          .read(appControllerProvider)
          .db
          .setPreference(
            _lastAutoCheckPref,
            DateTime.now().millisecondsSinceEpoch.toString(),
          );
    } catch (_) {
      // A failed timestamp write must not fail the check itself; the next
      // automatic check simply runs again.
    }
  }
}

final updateStatusProvider =
    NotifierProvider<UpdateStatusNotifier, UpdateState>(
      UpdateStatusNotifier.new,
    );
