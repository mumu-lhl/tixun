// Models for the in-app update feature (slice A: core service).
//
// Other slices build against exactly these types; do not rename them.

/// The release channel the user opted into.
///
/// Persisted as the pref string values `'stable'`, `'prerelease'` and
/// `'nightly'`.
enum UpdateChannel { stable, prerelease, nightly }

/// One downloadable file attached to a GitHub release.
class ReleaseAssetInfo {
  final String name;
  final String downloadUrl;

  const ReleaseAssetInfo({required this.name, required this.downloadUrl});
}

/// One GitHub release (drafts are filtered out by [UpdateService]).
class ReleaseInfo {
  final String tag;
  final String name;
  final bool prerelease;
  final bool draft;
  final List<ReleaseAssetInfo> assets;

  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.prerelease,
    required this.draft,
    required this.assets,
  });
}

/// A structured, localizable update message. No translated text is persisted.
enum UpdateMessage {
  newVersion,
  upToDate,
  checkFailed,
  unsupportedPlatform,
  noNewVersion,
  checksumUnavailable,
  checksumFailed,
  downloadFailed,
  installPermission,
  installFailed,
  applyFailed,
  noStableRelease,
  noPrerelease,
  noNightly,
  updateCheckFailed,
}

/// The result of an update check.
enum UpdateCheckKind { upToDate, available, noneAvailable, failed }

/// Outcome of [UpdateService.check].
///
/// [release] is the candidate release when one was found (for both
/// [UpdateCheckKind.available] and [UpdateCheckKind.upToDate]); [assetName]
/// is left null here — the caller picks the asset for the current platform.
/// [message] identifies a localizable note for failed or empty outcomes.
class UpdateCheckOutcome {
  final UpdateCheckKind kind;
  final ReleaseInfo? release;
  final String? assetName;
  final UpdateMessage? message;

  const UpdateCheckOutcome({
    required this.kind,
    this.release,
    this.assetName,
    this.message,
  });
}
