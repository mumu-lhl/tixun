import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/features/update/update_models.dart';
import 'package:tixun/features/update/update_service.dart';

/// Inline fixture mirroring the GitHub releases API shape (newest first).
/// Contains a nightly, a prerelease, a stable release and a draft that
/// must be skipped.
List<Map<String, dynamic>> get fixtureJson => [
  {
    'tag_name': 'nightly-20261109-abc123',
    'name': 'Nightly 2026-11-09',
    'prerelease': true,
    'draft': false,
    'assets': [
      {
        'name': 'tixun-nightly-linux.zip',
        'browser_download_url':
            'https://example.com/nightly-20261109-abc123.zip',
      },
    ],
  },
  {
    'tag_name': 'v0.6.0-beta.1',
    'name': 'v0.6.0-beta.1',
    'prerelease': true,
    'draft': false,
    'assets': [
      {
        'name': 'tixun-0.6.0-beta.1-linux.zip',
        'browser_download_url': 'https://example.com/beta.zip',
      },
      {
        'name': 'SHA256SUMS',
        'browser_download_url': 'https://example.com/beta/SHA256SUMS',
      },
    ],
  },
  {
    'tag_name': 'v0.5.2',
    'name': 'v0.5.2',
    'prerelease': false,
    'draft': false,
    'assets': [
      {
        'name': 'tixun-0.5.2-linux.zip',
        'browser_download_url': 'https://example.com/stable.zip',
      },
    ],
  },
  {
    'tag_name': 'v0.6.0-draft',
    'name': 'draft release',
    'prerelease': true,
    'draft': true,
    'assets': [],
  },
];

/// A Dio that answers from [handlers] instead of the network.
/// Each handler maps a request URL to the response body; a missing URL
/// rejects with a [DioException] so unexpected network access fails loudly.
Dio stubDio(Map<String, Object?> handlers, {bool failAll = false}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (failAll || !handlers.containsKey(options.path)) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'stubbed network failure for ${options.path}',
            ),
          );
          return;
        }
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            data: handlers[options.path],
            statusCode: 200,
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  group('parseReleases', () {
    test('parses releases and skips drafts', () {
      final releases = UpdateService.parseReleases(fixtureJson);
      expect(releases.length, 3);
      expect(releases[0].tag, 'nightly-20261109-abc123');
      expect(releases[1].tag, 'v0.6.0-beta.1');
      expect(releases[1].prerelease, isTrue);
      expect(releases[1].assets.length, 2);
      expect(releases[1].assets[0].name, 'tixun-0.6.0-beta.1-linux.zip');
      expect(releases[1].assets[0].downloadUrl, 'https://example.com/beta.zip');
      expect(releases[2].tag, 'v0.5.2');
      expect(releases[2].prerelease, isFalse);
    });

    test('non-list JSON yields an empty list', () {
      expect(UpdateService.parseReleases({'not': 'a list'}), isEmpty);
      expect(UpdateService.parseReleases(null), isEmpty);
    });
  });

  group('pickRelease', () {
    late List<ReleaseInfo> releases;

    setUp(() {
      releases = UpdateService.parseReleases(fixtureJson);
    });

    test('stable picks the first non-prerelease', () {
      expect(
        UpdateService().pickRelease(releases, UpdateChannel.stable)?.tag,
        'v0.5.2',
      );
    });

    test('prerelease picks the first v* prerelease', () {
      expect(
        UpdateService().pickRelease(releases, UpdateChannel.prerelease)?.tag,
        'v0.6.0-beta.1',
      );
    });

    test('nightly picks the first nightly- tag', () {
      expect(
        UpdateService().pickRelease(releases, UpdateChannel.nightly)?.tag,
        'nightly-20261109-abc123',
      );
    });

    test('prerelease channel with no v* prerelease returns null', () {
      final noVersionedPrerelease = UpdateService.parseReleases([
        {
          'tag_name': 'nightly-20261109-abc123',
          'name': 'Nightly',
          'prerelease': true,
          'draft': false,
          'assets': [],
        },
        {
          'tag_name': 'v0.5.2',
          'name': 'v0.5.2',
          'prerelease': false,
          'draft': false,
          'assets': [],
        },
      ]);
      expect(
        UpdateService().pickRelease(
          noVersionedPrerelease,
          UpdateChannel.prerelease,
        ),
        isNull,
      );
    });

    test('empty list returns null for every channel', () {
      for (final channel in UpdateChannel.values) {
        expect(UpdateService().pickRelease([], channel), isNull);
      }
    });
  });

  group('check (stubbed Dio, no network)', () {
    test('stable: newer candidate -> available', () async {
      final service = UpdateService(
        dio: stubDio({UpdateService.releasesUrl: fixtureJson}),
      );
      final outcome = await service.check(
        UpdateChannel.stable,
        currentVersion: '0.5.1',
        embeddedNightlyTag: '',
      );
      expect(outcome.kind, UpdateCheckKind.available);
      expect(outcome.release?.tag, 'v0.5.2');
      expect(outcome.assetName, isNull);
    });

    test('stable: same version -> upToDate', () async {
      final service = UpdateService(
        dio: stubDio({UpdateService.releasesUrl: fixtureJson}),
      );
      final outcome = await service.check(
        UpdateChannel.stable,
        currentVersion: '0.5.2',
        embeddedNightlyTag: '',
      );
      expect(outcome.kind, UpdateCheckKind.upToDate);
      expect(outcome.release?.tag, 'v0.5.2');
    });

    test('prerelease with no candidate -> noneAvailable', () async {
      final service = UpdateService(
        dio: stubDio({
          UpdateService.releasesUrl: [
            {
              'tag_name': 'v0.5.2',
              'name': 'v0.5.2',
              'prerelease': false,
              'draft': false,
              'assets': [],
            },
          ],
        }),
      );
      final outcome = await service.check(
        UpdateChannel.prerelease,
        currentVersion: '0.5.2',
        embeddedNightlyTag: '',
      );
      expect(outcome.kind, UpdateCheckKind.noneAvailable);
      expect(outcome.message, '暂无预发布');
    });

    test('stable with no candidate -> noneAvailable', () async {
      final service = UpdateService(
        dio: stubDio({UpdateService.releasesUrl: []}),
      );
      final outcome = await service.check(
        UpdateChannel.stable,
        currentVersion: '0.5.2',
        embeddedNightlyTag: '',
      );
      expect(outcome.kind, UpdateCheckKind.noneAvailable);
      expect(outcome.message, '暂无正式版');
    });

    test(
      'nightly: different tag -> available, equal tag -> upToDate',
      () async {
        final service = UpdateService(
          dio: stubDio({UpdateService.releasesUrl: fixtureJson}),
        );
        final newer = await service.check(
          UpdateChannel.nightly,
          currentVersion: '0.5.2',
          embeddedNightlyTag: 'nightly-20261108-xyz789',
        );
        expect(newer.kind, UpdateCheckKind.available);
        final same = await service.check(
          UpdateChannel.nightly,
          currentVersion: '0.5.2',
          embeddedNightlyTag: 'nightly-20261109-abc123',
        );
        expect(same.kind, UpdateCheckKind.upToDate);
      },
    );

    test('network failure -> failed, never throws', () async {
      final service = UpdateService(dio: stubDio({}, failAll: true));
      final outcome = await service.check(
        UpdateChannel.stable,
        currentVersion: '0.5.2',
        embeddedNightlyTag: '',
      );
      expect(outcome.kind, UpdateCheckKind.failed);
      expect(outcome.message, isNotNull);
    });
  });

  group('fetchExpectedSha256 (stubbed Dio, no network)', () {
    const sumsText =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  tixun-0.6.0-beta.1-linux.zip\n'
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb  other-file.zip\n';

    test('parses the hash for the matching filename', () async {
      final releases = UpdateService.parseReleases(fixtureJson);
      final beta = releases.firstWhere((r) => r.tag == 'v0.6.0-beta.1');
      final service = UpdateService(
        dio: stubDio({'https://example.com/beta/SHA256SUMS': sumsText}),
      );
      expect(
        await service.fetchExpectedSha256(beta, 'tixun-0.6.0-beta.1-linux.zip'),
        'a' * 64,
      );
    });

    test('matches filenames with the ./ prefix CI writes', () async {
      // Real releases are generated with `sha256sum ./*.apk ./*.tar.gz`,
      // so every entry is `./<filename>` (see nightly.yml / release.yml).
      const prefixedSums =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  ./tixun-0.6.0-beta.1-linux.zip\n'
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc  *./other-file.zip\n';
      final releases = UpdateService.parseReleases(fixtureJson);
      final beta = releases.firstWhere((r) => r.tag == 'v0.6.0-beta.1');
      final service = UpdateService(
        dio: stubDio({'https://example.com/beta/SHA256SUMS': prefixedSums}),
      );
      expect(
        await service.fetchExpectedSha256(beta, 'tixun-0.6.0-beta.1-linux.zip'),
        'a' * 64,
      );
      expect(
        await service.fetchExpectedSha256(beta, 'other-file.zip'),
        'c' * 64,
      );
    });

    test('returns null when the filename is not listed', () async {
      final releases = UpdateService.parseReleases(fixtureJson);
      final beta = releases.firstWhere((r) => r.tag == 'v0.6.0-beta.1');
      final service = UpdateService(
        dio: stubDio({'https://example.com/beta/SHA256SUMS': sumsText}),
      );
      expect(await service.fetchExpectedSha256(beta, 'missing.zip'), isNull);
    });

    test('returns null when the release has no SHA256SUMS asset', () async {
      final releases = UpdateService.parseReleases(fixtureJson);
      final stable = releases.firstWhere((r) => r.tag == 'v0.5.2');
      final service = UpdateService(dio: stubDio({}));
      expect(
        await service.fetchExpectedSha256(stable, 'tixun-0.5.2-linux.zip'),
        isNull,
      );
    });
  });

  group('verifySha256', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('update_service_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('matches the known SHA-256 of "abc"', () async {
      // sha256('abc') =
      // ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
      final file = File('${tempDir.path}/abc.txt');
      await file.writeAsString('abc');
      expect(
        await UpdateService().verifySha256(
          file,
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        ),
        isTrue,
      );
    });

    test('is case-insensitive and rejects a wrong hash', () async {
      final file = File('${tempDir.path}/abc.txt');
      await file.writeAsString('abc');
      final service = UpdateService();
      expect(
        await service.verifySha256(
          file,
          'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD',
        ),
        isTrue,
      );
      expect(await service.verifySha256(file, '0' * 64), isFalse);
    });

    test('returns false for a missing file', () async {
      expect(
        await UpdateService().verifySha256(
          File('${tempDir.path}/missing.bin'),
          '0' * 64,
        ),
        isFalse,
      );
    });
  });

  group('downloadAsset', () {
    test('throws when the asset is not in the release', () async {
      final releases = UpdateService.parseReleases(fixtureJson);
      final stable = releases.firstWhere((r) => r.tag == 'v0.5.2');
      await expectLater(
        UpdateService(dio: stubDio({})).downloadAsset(
          release: stable,
          assetName: 'nope.zip',
          savePath: '/tmp/does-not-matter.zip',
        ),
        throwsArgumentError,
      );
    });
  });
}
