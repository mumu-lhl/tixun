import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/features/update/android_install.dart';

void main() {
  group('abiToAssetAbi', () {
    test('arm64-v8a maps to itself', () {
      expect(abiToAssetAbi('arm64-v8a'), 'arm64-v8a');
    });

    test('armeabi-v7a maps to itself', () {
      expect(abiToAssetAbi('armeabi-v7a'), 'armeabi-v7a');
    });

    test('x86_64 maps to itself', () {
      expect(abiToAssetAbi('x86_64'), 'x86_64');
    });

    test('x86 falls back to universal', () {
      expect(abiToAssetAbi('x86'), 'universal');
    });

    test('null falls back to universal', () {
      expect(abiToAssetAbi(null), 'universal');
    });

    test('empty string falls back to universal', () {
      expect(abiToAssetAbi(''), 'universal');
    });
  });
}
