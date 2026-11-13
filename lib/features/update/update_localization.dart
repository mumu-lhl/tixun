import 'package:flutter/widgets.dart';

import '../../core/l10n/app_strings.dart';
import 'update_models.dart';

/// Resolves update state codes at display time, so locale changes take effect
/// without repeating the check or storing translated strings.
String updateMessageText(
  BuildContext context,
  UpdateMessage message, {
  String? tag,
}) => switch (message) {
  UpdateMessage.newVersion => context.l10n.newVersionAvailable(tag ?? ''),
  UpdateMessage.upToDate => context.l10n.youAreOnTheLatest,
  UpdateMessage.checkFailed => context.l10n.checkFailedPleaseTryAgain,
  UpdateMessage.unsupportedPlatform => context.l10n.inAppUpdatesAreNot,
  UpdateMessage.noNewVersion => context.l10n.noNewVersionAvailable,
  UpdateMessage.checksumUnavailable => context.l10n.couldNotFetchChecksumInfo,
  UpdateMessage.checksumFailed =>
    context.l10n.downloadVerificationFailedPleaseTry,
  UpdateMessage.downloadFailed => context.l10n.downloadFailedPleaseTryAgain,
  UpdateMessage.installPermission =>
    context.l10n.pleaseAllowInstallingUnknownApps,
  UpdateMessage.installFailed => context.l10n.installationFailedPleaseTryAgain,
  UpdateMessage.applyFailed => context.l10n.failedToApplyTheUpdate,
  UpdateMessage.noStableRelease => context.l10n.noStableReleaseAvailable,
  UpdateMessage.noPrerelease => context.l10n.noPrereleaseAvailable,
  UpdateMessage.noNightly => context.l10n.noNightlyBuildAvailable,
  UpdateMessage.updateCheckFailed => context.l10n.updateCheckFailed,
};
