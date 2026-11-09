// Pure version-tag parsing and comparison for the in-app update feature.
//
// No Flutter imports here, so these functions are unit-testable in isolation.

/// Parses a version tag such as `v0.6.0-beta.1` or `0.5.2`.
///
/// A leading `v` is stripped, everything from the first `-` on is treated
/// as a prerelease suffix, and the `X.Y.Z` part is parsed with missing
/// minor/patch defaulting to `0`. Non-numeric segments parse as `0`.
({int major, int minor, int patch, bool prerelease}) parseVersionTag(
  String tag,
) {
  final cleaned = tag.trim();
  final withoutPrefix = cleaned.startsWith('v') || cleaned.startsWith('V')
      ? cleaned.substring(1)
      : cleaned;
  final dashIndex = withoutPrefix.indexOf('-');
  final numericPart = dashIndex >= 0
      ? withoutPrefix.substring(0, dashIndex)
      : withoutPrefix;
  // Tolerate build metadata such as `1.2.3+build.4`.
  final core = numericPart.split('+').first;
  final parts = core.split('.');
  int at(int index) {
    if (index >= parts.length) return 0;
    return int.tryParse(parts[index]) ?? 0;
  }

  return (major: at(0), minor: at(1), patch: at(2), prerelease: dashIndex >= 0);
}

/// Compares two parsed version triples.
///
/// Returns -1, 0 or 1 by (major, minor, patch); for equal triples a plain
/// release sorts after (is greater than) a prerelease of the same triple.
int compareVersionTriples(
  ({int major, int minor, int patch, bool prerelease}) a,
  ({int major, int minor, int patch, bool prerelease}) b,
) {
  if (a.major != b.major) return a.major < b.major ? -1 : 1;
  if (a.minor != b.minor) return a.minor < b.minor ? -1 : 1;
  if (a.patch != b.patch) return a.patch < b.patch ? -1 : 1;
  if (a.prerelease == b.prerelease) return 0;
  // A plain release is newer than a prerelease of the same triple.
  return a.prerelease ? -1 : 1;
}

/// Whether [candidateTag] (e.g. `v0.5.3`) is newer than [currentVersion]
/// (e.g. `0.5.2`, the `version` from package_info_plus without build
/// number). True only when the candidate triple is strictly greater.
bool isCandidateNewer({
  required String candidateTag,
  required String currentVersion,
}) {
  return compareVersionTriples(
        parseVersionTag(candidateTag),
        parseVersionTag(currentVersion),
      ) >
      0;
}

/// Whether a nightly [candidateTag] is an update over the nightly embedded
/// in the current build. Any nightly tag counts as an update when the
/// current build is not a nightly ([embeddedTag] is empty).
bool nightlyNeedsUpdate({
  required String candidateTag,
  required String embeddedTag,
}) {
  return candidateTag != embeddedTag;
}
