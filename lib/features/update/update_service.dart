import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'update_models.dart';
import 'version_compare.dart';

/// Fetches GitHub releases for tixun and decides whether an update is
/// available on the requested channel.
///
/// Network access uses the existing `dio` dependency; no new dependencies.
/// [check] never throws — network/parse failures surface as a
/// [UpdateCheckKind.failed] outcome.
class UpdateService {
  UpdateService({Dio? dio}) : _dio = dio ?? Dio();

  static const String releasesUrl =
      'https://api.github.com/repos/mumu-lhl/tixun/releases?per_page=20';

  static const Duration _timeout = Duration(seconds: 10);

  final Dio _dio;

  /// Fetches the release list (newest first), skipping drafts.
  Future<List<ReleaseInfo>> fetchReleases() async {
    final response = await _dio.get<dynamic>(
      releasesUrl,
      options: Options(connectTimeout: _timeout, receiveTimeout: _timeout),
    );
    return parseReleases(response.data);
  }

  /// Pure JSON -> models conversion, shared by [fetchReleases] and tests.
  ///
  /// Expects the decoded JSON list from the GitHub releases API. Draft
  /// releases are skipped; malformed entries are skipped rather than
  /// failing the whole parse.
  static List<ReleaseInfo> parseReleases(dynamic json) {
    if (json is! List) return const [];
    final releases = <ReleaseInfo>[];
    for (final entry in json) {
      if (entry is! Map<String, dynamic>) continue;
      if (entry['draft'] as bool? ?? false) continue;
      final assets = <ReleaseAssetInfo>[];
      final rawAssets = entry['assets'];
      if (rawAssets is List) {
        for (final rawAsset in rawAssets) {
          if (rawAsset is! Map<String, dynamic>) continue;
          final name = rawAsset['name'] as String? ?? '';
          final downloadUrl = rawAsset['browser_download_url'] as String? ?? '';
          if (name.isEmpty || downloadUrl.isEmpty) continue;
          assets.add(ReleaseAssetInfo(name: name, downloadUrl: downloadUrl));
        }
      }
      releases.add(
        ReleaseInfo(
          tag: entry['tag_name'] as String? ?? '',
          name: entry['name'] as String? ?? '',
          prerelease: entry['prerelease'] as bool? ?? false,
          draft: entry['draft'] as bool? ?? false,
          assets: assets,
        ),
      );
    }
    return releases;
  }

  /// Picks the newest release for [channel] from a newest-first list.
  ///
  /// stable: first release with `prerelease == false`.
  /// prerelease: first release with `prerelease == true` and a tag
  /// starting with `v`. nightly: first release with a tag starting with
  /// `nightly-`. Returns null when no release matches.
  ReleaseInfo? pickRelease(List<ReleaseInfo> releases, UpdateChannel channel) {
    for (final release in releases) {
      switch (channel) {
        case UpdateChannel.stable:
          if (!release.prerelease) return release;
        case UpdateChannel.prerelease:
          if (release.prerelease && release.tag.startsWith('v')) {
            return release;
          }
        case UpdateChannel.nightly:
          if (release.tag.startsWith('nightly-')) return release;
      }
    }
    return null;
  }

  /// Checks for an update on [channel]. Never throws.
  ///
  /// [currentVersion] is the app version without build number (e.g.
  /// `0.5.2`); [embeddedNightlyTag] is the nightly tag embedded in the
  /// current build, or `''` when the current build is not a nightly.
  Future<UpdateCheckOutcome> check(
    UpdateChannel channel, {
    required String currentVersion,
    required String embeddedNightlyTag,
  }) async {
    try {
      final releases = await fetchReleases();
      final candidate = pickRelease(releases, channel);
      if (candidate == null) {
        return UpdateCheckOutcome(
          kind: UpdateCheckKind.noneAvailable,
          message: switch (channel) {
            UpdateChannel.stable => '暂无正式版',
            UpdateChannel.prerelease => '暂无预发布',
            UpdateChannel.nightly => '暂无 nightly 构建',
          },
        );
      }
      if (channel == UpdateChannel.nightly) {
        final needsUpdate = nightlyNeedsUpdate(
          candidateTag: candidate.tag,
          embeddedTag: embeddedNightlyTag,
        );
        return UpdateCheckOutcome(
          kind: needsUpdate
              ? UpdateCheckKind.available
              : UpdateCheckKind.upToDate,
          release: candidate,
        );
      }
      final newer = isCandidateNewer(
        candidateTag: candidate.tag,
        currentVersion: currentVersion,
      );
      return UpdateCheckOutcome(
        kind: newer ? UpdateCheckKind.available : UpdateCheckKind.upToDate,
        release: candidate,
      );
    } catch (_) {
      return const UpdateCheckOutcome(
        kind: UpdateCheckKind.failed,
        message: '检查更新失败',
      );
    }
  }

  /// Downloads the `SHA256SUMS` asset of [release] as text and returns the
  /// expected SHA-256 hex for [assetName], or null when the asset is absent
  /// or its content cannot be parsed.
  Future<String?> fetchExpectedSha256(
    ReleaseInfo release,
    String assetName,
  ) async {
    try {
      final sumsAsset = release.assets
          .where((asset) => asset.name == 'SHA256SUMS')
          .firstOrNull;
      if (sumsAsset == null) return null;
      final response = await _dio.get<String>(
        sumsAsset.downloadUrl,
        options: Options(
          responseType: ResponseType.plain,
          connectTimeout: _timeout,
          receiveTimeout: _timeout,
        ),
      );
      final text = response.data;
      if (text == null || text.isEmpty) return null;
      for (final line in const LineSplitter().convert(text)) {
        final tokens = line.trim().split(RegExp(r'\s+'));
        if (tokens.length < 2) continue;
        final hash = tokens.first;
        var filename = tokens.last;
        if (filename.startsWith('*')) filename = filename.substring(1);
        // CI generates the file with `sha256sum ./*.apk ./*.tar.gz`, so
        // entries carry a `./` prefix (e.g. `./tixun-...-linux-x64.tar.gz`).
        if (filename.startsWith('./')) filename = filename.substring(2);
        if (filename == assetName) return hash;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads [assetName] of [release] to [savePath], reporting progress.
  /// Throws on failure (including when the asset is not in the release).
  Future<File> downloadAsset({
    required ReleaseInfo release,
    required String assetName,
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    final asset = release.assets.where((a) => a.name == assetName).firstOrNull;
    if (asset == null) {
      throw ArgumentError('Asset not found in release: $assetName');
    }
    await _dio.download(
      asset.downloadUrl,
      savePath,
      onReceiveProgress: onProgress,
    );
    return File(savePath);
  }

  /// Whether [file]'s SHA-256 (lowercase hex) equals [expectedHash].
  /// Returns false when the file cannot be read.
  Future<bool> verifySha256(File file, String expectedHash) async {
    try {
      final bytes = await file.readAsBytes();
      final actual = sha256.convert(bytes).toString();
      return actual == expectedHash.trim().toLowerCase();
    } catch (_) {
      return false;
    }
  }
}
