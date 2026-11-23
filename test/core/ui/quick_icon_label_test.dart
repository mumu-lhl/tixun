import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/app/theme.dart";
import "package:tixun/core/ui/app_menu.dart";

void main() {
  for (final scale in [1.0, 1.6]) {
    testWidgets(
      "expanded icon selector keeps its floating label inside the clip at scale $scale",
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(Brightness.light),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: ExpansionTile(
                      title: const Text("Advanced"),
                      children: [
                        AppSelectField<String>(
                          initialValue: "a",
                          decoration: const InputDecoration(labelText: "Icon"),
                          items: const [
                            DropdownMenuItem(
                              value: "a",
                              child: Icon(Icons.translate),
                            ),
                          ],
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text("Advanced"));
        await tester.pumpAndSettle();
        final label = find.text("Icon");
        final clip = find
            .ancestor(of: label, matching: find.byType(ClipRect))
            .first;
        expect(
          tester.getTopLeft(label).dy,
          greaterThanOrEqualTo(tester.getTopLeft(clip).dy),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
