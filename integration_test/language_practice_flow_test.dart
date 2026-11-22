import "package:integration_test/integration_test.dart";

import "../test/features/language_learning/language_practice_layout_test.dart"
    as suite;
import "support/gui_capture.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  suite.main(
    capture: (tester, name) async {
      await resizeGui(tester, name.endsWith("360") ? 360 : 1200, 800);
      await guiCapture("language", name);
    },
  );
}
