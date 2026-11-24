import "package:flutter_test/flutter_test.dart";
import "package:tixun/features/language_learning/lexical_form.dart";

void main() {
  test(
    "unchanged and spaced inflections are valid, malformed forms are not",
    () {
      const LexicalFormDraft("cut", Inflection.past).validate("cut");
      const LexicalFormDraft("sheep", Inflection.plural).validate("sheep");
      const LexicalFormDraft(
        "more useful",
        Inflection.comparative,
      ).validate("useful");
      for (final surface in ["", " ", "-cut", "cut-", "cut123", "cut, cut"]) {
        expect(
          () => LexicalFormDraft(surface, Inflection.past).validate("cut"),
          throwsFormatException,
        );
      }
      expect(
        LexicalFormDraft.normalizeSurface(" MORE   useful "),
        "more useful",
      );
    },
  );
}
