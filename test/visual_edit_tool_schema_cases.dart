part of "visual_edit_tool_test.dart";

void _visualEditSchemaCases() {
  test("updateVisualToolSchema and getVisualToolSchema are strict", () {
    expect(updateVisualToolSchema.name, "update_visual");
    expect(updateVisualToolSchema.parameters["additionalProperties"], isFalse);
    // scene OR ops: the executor enforces exactly one, so the schema
    // only requires the id.
    expect((updateVisualToolSchema.parameters["required"] as List), [
      "visual_id",
    ]);
    expect(
      (updateVisualToolSchema.parameters["properties"] as Map).keys,
      containsAll(["visual_id", "scene", "ops", "title"]),
    );
    expect(getVisualToolSchema.name, "get_visual");
    expect(getVisualToolSchema.parameters["additionalProperties"], isFalse);
    expect(
      (getVisualToolSchema.parameters["required"] as List),
      contains("visual_id"),
    );
    expect(
      (getVisualToolSchema.parameters["properties"] as Map).keys,
      containsAll(["visual_id", "revision"]),
    );
  });
}
