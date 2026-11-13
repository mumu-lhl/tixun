import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart' as camera;

import '../l10n/app_strings.dart';

typedef CameraCaptureResult = ({String? path, bool useSystemCamera});

enum _CameraError { stillBusy, pickerFailure }

/// The picker owns capture controls; this page only supplies error feedback
/// and an escape to the device camera, after releasing the embedded controller.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});
  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureState();
}

class _CameraCaptureState extends State<CameraCaptureScreen> {
  final picker = camera.CameraPickerState();
  bool switching = false;
  _CameraError? error;

  Future<void> useSystemCamera() async {
    if (switching ||
        (picker.innerController != null && picker.isControllerBusy)) {
      return;
    }
    setState(() => switching = true);
    try {
      // Do not let two apps contend for the same camera while initializing.
      if (picker.cameras.isNotEmpty || error == null) {
        await picker.initializeLock?.future.timeout(const Duration(seconds: 8));
      }
      final controller = picker.innerController;
      picker.innerController = null;
      await picker.disposeCameraController(controller);
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop<CameraCaptureResult>(context, (
          path: null,
          useSystemCamera: true,
        ));
      }
    } catch (_) {
      if (mounted) setState(() => error = _CameraError.stillBusy);
    } finally {
      if (mounted) setState(() => switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final english = Localizations.maybeLocaleOf(context)?.languageCode == 'en';
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          camera.CameraPicker(
            createPickerState: () => picker,
            pickerConfig: camera.CameraPickerConfig(
              enableAudio: false,
              enableRecording: false,
              shouldDeletePreviewFile: false,
              textDelegate: english
                  ? const camera.EnglishCameraPickerTextDelegate()
                  : const camera.CameraPickerTextDelegate(),
              onError: (_, _) {
                if (mounted) setState(() => error = _CameraError.pickerFailure);
              },
              onXFileCaptured: (file, _) {
                if (mounted &&
                    !switching &&
                    ModalRoute.of(context)?.isCurrent == true) {
                  switching = true;
                  Navigator.pop<CameraCaptureResult>(context, (
                    path: file.path,
                    useSystemCamera: false,
                  ));
                }
                return true;
              },
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, left: 56, right: 56),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      key: const Key('system-camera-fallback'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black54,
                      ),
                      onPressed: switching ? null : useSystemCamera,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(
                        (switching
                            ? context.l10n.switchingCamera
                            : context.l10n.useSystemCamera),
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Material(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              switch (error!) {
                                _CameraError.stillBusy =>
                                  context.l10n.theCameraIsStillBusy,
                                _CameraError.pickerFailure =>
                                  context.l10n.theCameraReportedAnError,
                              },
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
