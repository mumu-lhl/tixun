import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

/// Thrown when the user has not allowed installing unknown apps.
/// The caller should offer to open the system install-unknown-apps
/// settings page via [openInstallSettings].
class InstallNotAllowedException implements Exception {}

const _channel = MethodChannel('org.tixun/app_update');

/// Maps a device ABI to the ABI suffix used in release asset names
/// (`tixun-{tag}-android-{abi}-release.apk`).
/// Unknown, null or empty ABIs fall back to the universal APK.
String abiToAssetAbi(String? abi) {
  switch (abi) {
    case 'arm64-v8a':
    case 'armeabi-v7a':
    case 'x86_64':
      return abi!;
    default:
      return 'universal';
  }
}

/// The ABI suffix of the release APK matching this device,
/// from the first entry of [AndroidDeviceInfo.supportedAbis].
Future<String> androidAbiAsset() async {
  final info = await DeviceInfoPlugin().androidInfo;
  final abis = info.supportedAbis;
  return abiToAssetAbi(abis.isEmpty ? null : abis.first);
}

/// Opens the Android package installer for the APK at [apkPath].
/// The APK must sit under the app cache dir (enforced natively).
/// Throws [InstallNotAllowedException] when installing unknown apps
/// is not allowed for this app; other failures rethrow.
Future<void> installApk(String apkPath) async {
  try {
    await _channel.invokeMethod('installApk', {'path': apkPath});
  } on PlatformException catch (e) {
    if (e.code == 'INSTALL_NOT_ALLOWED') {
      throw InstallNotAllowedException();
    }
    rethrow;
  }
}

/// Opens the system "install unknown apps" settings page for this app.
Future<void> openInstallSettings() async {
  await _channel.invokeMethod('openInstallSettings');
}
