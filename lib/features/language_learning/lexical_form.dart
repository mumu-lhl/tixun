import "package:drift/drift.dart";
import "package:uuid/uuid.dart";

import "../../core/database/database.dart";

enum Inflection {
  past,
  pastParticiple,
  presentParticiple,
  thirdPerson,
  plural,
  comparative,
  superlative,
}

class LexicalFormDraft {
  const LexicalFormDraft(this.surface, this.inflection);
  final String surface;
  final Inflection inflection;

  static String normalizeSurface(String value) =>
      value.trim().replaceAll(RegExp(r"\s+"), " ").toLowerCase();

  static const recognitionSkill = "formRecognition";
  static const productionSkill = "formProduction";

  void validate(String lemma) {
    final form = normalizeSurface(surface);
    if (lemma.trim().isEmpty ||
        form.length > 80 ||
        !RegExp(r"^[a-zA-Z]+(?:[ '-][a-zA-Z]+)*$").hasMatch(form)) {
      throw const FormatException("Invalid English inflection");
    }
  }
}

Future<void> insertLexicalForm(
  AppDatabase db,
  String senseId,
  String lemma,
  LexicalFormDraft form,
) async {
  form.validate(lemma);
  final surface = form.surface.trim();
  await db
      .into(db.learningLexicalForms)
      .insert(
        LearningLexicalFormsCompanion.insert(
          id: const Uuid().v4(),
          senseId: senseId,
          surface: surface,
          normalizedSurface: LexicalFormDraft.normalizeSurface(surface),
          inflection: form.inflection.name,
          createdAt: DateTime.now(),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}
