import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/features/language_learning/vocabulary_example.dart";

void main() {
  test(
    "examples emphasize whole forms and phrases without modifying the text",
    () {
      const text = "He took part in the party. Take  care of the artwork.";
      const style = TextStyle(
        color: Color(0xff226450),
        decoration: TextDecoration.underline,
      );
      final span = vocabularyExampleSpan(text, [
        "take",
        "took",
        "part",
        "take care",
        "art",
      ], style);
      final marked = <String>[];
      span.visitChildren((child) {
        if (child is TextSpan &&
            child.style?.decoration == TextDecoration.underline) {
          marked.add(child.text!);
        }
        return true;
      });
      expect(span.toPlainText(), text);
      expect(marked, ["took", "part", "Take  care"]);
    },
  );
}
