import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/features/update/version_compare.dart';

void main() {
  group('parseVersionTag', () {
    test('parses a plain tag with leading v', () {
      final parsed = parseVersionTag('v0.5.2');
      expect(parsed.major, 0);
      expect(parsed.minor, 5);
      expect(parsed.patch, 2);
      expect(parsed.prerelease, isFalse);
    });

    test('parses a prerelease tag', () {
      final parsed = parseVersionTag('v0.6.0-beta.1');
      expect(parsed.major, 0);
      expect(parsed.minor, 6);
      expect(parsed.patch, 0);
      expect(parsed.prerelease, isTrue);
    });

    test('parses a version without leading v', () {
      final parsed = parseVersionTag('0.5.2');
      expect((parsed.major, parsed.minor, parsed.patch), (0, 5, 2));
      expect(parsed.prerelease, isFalse);
    });

    test('tolerates missing minor and patch', () {
      expect(parseVersionTag('v1.2').minor, 2);
      expect(parseVersionTag('v1.2').patch, 0);
      expect(parseVersionTag('v2').major, 2);
      expect(parseVersionTag('v2').minor, 0);
      expect(parseVersionTag('v2').patch, 0);
    });
  });

  group('compareVersionTriples', () {
    test('prerelease is less than the same plain triple', () {
      expect(
        compareVersionTriples(
          parseVersionTag('v0.6.0-beta.1'),
          parseVersionTag('v0.6.0'),
        ),
        -1,
      );
      expect(
        compareVersionTriples(
          parseVersionTag('v0.6.0'),
          parseVersionTag('v0.6.0-beta.1'),
        ),
        1,
      );
    });

    test('equal triples compare as 0', () {
      expect(
        compareVersionTriples(
          parseVersionTag('v0.5.2'),
          parseVersionTag('0.5.2'),
        ),
        0,
      );
    });

    test('orders by major, minor, then patch', () {
      expect(
        compareVersionTriples(
          parseVersionTag('v1.0.0'),
          parseVersionTag('v0.9.9'),
        ),
        1,
      );
      expect(
        compareVersionTriples(
          parseVersionTag('v0.5.3'),
          parseVersionTag('v0.5.2'),
        ),
        1,
      );
      expect(
        compareVersionTriples(
          parseVersionTag('v0.5.1'),
          parseVersionTag('v0.5.2'),
        ),
        -1,
      );
    });
  });

  group('isCandidateNewer', () {
    test('same version is not newer', () {
      expect(
        isCandidateNewer(candidateTag: 'v0.5.2', currentVersion: '0.5.2'),
        isFalse,
      );
    });

    test('higher patch is newer', () {
      expect(
        isCandidateNewer(candidateTag: 'v0.5.3', currentVersion: '0.5.2'),
        isTrue,
      );
    });

    test('lower version is not newer', () {
      expect(
        isCandidateNewer(candidateTag: 'v0.5.1', currentVersion: '0.5.2'),
        isFalse,
      );
    });

    test('prerelease of the current release is not newer', () {
      expect(
        isCandidateNewer(
          candidateTag: 'v0.6.0-beta.1',
          currentVersion: '0.6.0',
        ),
        isFalse,
      );
    });

    test('prerelease of a higher triple is newer', () {
      expect(
        isCandidateNewer(
          candidateTag: 'v0.6.0-beta.1',
          currentVersion: '0.5.2',
        ),
        isTrue,
      );
    });
  });

  group('nightlyNeedsUpdate', () {
    test('equal tag needs no update', () {
      expect(
        nightlyNeedsUpdate(
          candidateTag: 'nightly-20261109-abc123',
          embeddedTag: 'nightly-20261109-abc123',
        ),
        isFalse,
      );
    });

    test('different tag needs an update', () {
      expect(
        nightlyNeedsUpdate(
          candidateTag: 'nightly-20261109-abc123',
          embeddedTag: 'nightly-20261108-xyz789',
        ),
        isTrue,
      );
    });

    test('empty embedded tag means any nightly is an update', () {
      expect(
        nightlyNeedsUpdate(
          candidateTag: 'nightly-20261109-abc123',
          embeddedTag: '',
        ),
        isTrue,
      );
    });
  });
}
