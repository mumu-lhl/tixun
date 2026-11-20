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

  static const recognitionSkill = "formRecognition";
  static const productionSkill = "formProduction";

  void validate(String lemma) {
    final form = surface.trim();
    if (form.isEmpty ||
        !RegExp(r"^[a-zA-Z][a-zA-Z'-]{0,79}$").hasMatch(form) ||
        form.toLowerCase() == lemma.trim().toLowerCase()) {
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
          normalizedSurface: surface.toLowerCase(),
          inflection: form.inflection.name,
          createdAt: DateTime.now(),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}
