import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";

import "../test/features/language_learning/language_practice_layout_test.dart"
    as suite;
import "support/gui_capture.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  suite.main(
    enterText: (tester, field, text) async {
      final window = await guiWindow();
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();
      if (window == null) {
        await tester.enterText(field, text);
        return;
      }
      final keyboard = await Process.run("xdotool", [
        "windowfocus",
        "--sync",
        window,
        "key",
        "--clearmodifiers",
        "ctrl+a",
        "type",
        "--clearmodifiers",
        "--delay",
        "35",
        text,
      ]);
      expect(keyboard.exitCode, 0, reason: keyboard.stderr.toString());
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
    },
    capture: (tester, name) async {
      if (name.startsWith("generation-")) {
        final window = await guiWindow();
        if (window != null) {
          final width = name.endsWith("360") ? "360" : "1200";
          expect(
            (await Process.run("xdotool", [
              "windowsize",
              window,
              width,
              "800",
            ])).exitCode,
            0,
          );
          await tester.pump(const Duration(milliseconds: 250));
          await guiCapture("language", name);
        }
        return;
      }
      await resizeGui(tester, name.endsWith("360") ? 360 : 1200, 800);
      if (name.startsWith("fsrs-")) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await guiCapture("language", name);
    },
  );
}
