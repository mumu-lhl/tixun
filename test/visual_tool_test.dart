import "dart:convert";
import "dart:io";

import "package:dio/dio.dart";
import "package:drift/drift.dart" hide isNull, isNotNull;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/visual_tool.dart";
import "package:tixun/core/l10n/app_error.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/chat/message_visuals.dart";
import "package:tixun/features/visual/visual_card.dart";
import "package:tixun/features/visual/visual_store.dart";

import "support/visual_fixtures.dart";

part "visual_tool_chat_cases.dart";

Map<String, dynamic> _plotArgs({
  Map<String, dynamic>? scene,
  String? title,
  String? alt,
}) {
  final args = <String, dynamic>{
    "scene":
        scene ??
        {
          "v": 1,
          "kind": "plot2d",
          "title": "二次函数",
          "model": {"expression": "x^2-4"},
          "view": {
            "x": [-3, 3],
            "y": [-5, 6],
          },
          "meta": {"alt": "抛物线 y=x^2-4 的图像"},
        },
  };
  if (title != null) args["title"] = title;
  if (alt != null) args["alt"] = alt;
  return args;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString("FontManifest.json")) as List;
    for (final font in manifest) {
      final loader = FontLoader(font["family"] as String);
      for (final asset in font["fonts"] as List) {
        loader.addFont(rootBundle.load(asset["asset"] as String));
      }
      await loader.load();
    }
  });

  test("visualToolSchema is strict", () {
    expect(visualToolSchema.name, "create_visual");
    expect(visualToolSchema.parameters["additionalProperties"], isFalse);
    expect(
      (visualToolSchema.parameters["required"] as List),
      contains("scene"),
    );
    expect(
      (visualToolSchema.parameters["properties"] as Map).keys,
      containsAll(["scene", "title", "alt"]),
    );
  });

  group("executeVisualTool", () {
    late AppDatabase db;
    late VisualStore store;

    setUp(() {
      db = AppDatabase.memory();
      store = VisualStore(db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
    });

    Future<Map<String, dynamic>> runTool(
      String callId,
      Map<String, dynamic> args, {
      String runId = "run-1",
    }) => executeVisualTool(
      store,
      ToolCall(callId, "create_visual", jsonEncode(args)),
      sessionId: "session-1",
      runId: runId,
      cancel: CancelToken(),
    );

    test("valid scene creates a scene and returns computed zeros", () async {
      await seedVisualMessage(db, "session-1", "run-1");
      final result = await runTool("call-1", _plotArgs());
      expect(result["ok"], isTrue);
      expect(result["visual_id"], isA<String>());
      expect((result["visual_id"] as String).isNotEmpty, isTrue);
      expect(result["verification"], "verified");
      final zeros =
          (result["computed"]["zeros"] as List)
              .map((v) => (v as num).toDouble())
              .toList()
            ..sort();
      expect(zeros, hasLength(2));
      expect(zeros[0], closeTo(-2, 1e-9));
      expect(zeros[1], closeTo(2, 1e-9));
      final rows = await db.select(db.visualScenes).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, result["visual_id"]);
      expect(rows.single.title, "二次函数");
      expect(rows.single.verificationStatus, "verified");
      final links = await db.select(db.visualMessageLinks).get();
      expect(links, hasLength(1));
      expect(links.single.messageId, "run-1");
      final ops = await db.select(db.aiToolOperations).get();
      expect(ops, hasLength(1));
      expect(ops.single.name, "create_visual");
      expect(ops.single.status, "succeeded");
    });

    test("create reports quality issues without failing the scene", () async {
      await seedVisualMessage(db, "session-1", "run-1");
      final result = await runTool(
        "call-1",
        _plotArgs(
          scene: {
            "v": 1,
            "kind": "geometry",
            "title": "点",
            "view": {
              "x": [-3, 3],
              "y": [-3, 3],
            },
            "elements": [
              {
                "id": "p1",
                "type": "point",
                "at": [5, 5],
                "label": "P",
              },
            ],
            "meta": {"alt": "点"},
          },
        ),
      );
      expect(result["ok"], isTrue);
      expect(result["verification"], "verified");
      final issues = result["quality_issues"] as List;
      expect(issues.map((i) => (i as Map)["code"]), ["point_outside_view"]);
      expect((issues.single as Map)["path"], "p1");
      final clean = await runTool("call-2", _plotArgs());
      expect(clean["ok"], isTrue);
      expect(clean.containsKey("quality_issues"), isFalse);
    });

    test(
      "a visual created in a study-linked session links to the study item",
      () async {
        await seedVisualMessage(db, "session-1", "run-1");
        final now = DateTime.now();
        await db
            .into(db.knowledgeItems)
            .insert(
              KnowledgeItemsCompanion.insert(
                id: "k",
                title: "二次函数",
                content: "正文",
                subject: "数学",
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.studyChatLinks)
            .insert(
              StudyChatLinksCompanion.insert(
                id: "l1",
                sessionId: "session-1",
                knowledgeId: const Value("k"),
              ),
            );
        final result = await runTool("call-1", _plotArgs());
        expect(result["ok"], isTrue);
        final scenes = await store.listByStudy(knowledgeId: "k");
        expect(scenes.map((s) => s.id), [result["visual_id"]]);
        expect(scenes.single.source, "ai");
      },
    );

    test("invalid expression returns ok:false and creates nothing", () async {
      await seedVisualMessage(db, "session-1", "run-1");
      final result = await runTool(
        "call-1",
        _plotArgs(
          scene: {
            "v": 1,
            "kind": "plot2d",
            "model": {"expression": "z^2"},
            "title": "坏表达式",
          },
        ),
      );
      expect(result["ok"], isFalse);
      expect(result["error"], isA<String>());
      expect((result["error"] as String).isNotEmpty, isTrue);
      expect(await db.select(db.visualScenes).get(), isEmpty);
      expect(await db.select(db.aiToolOperations).get(), isEmpty);
    });

    test("oversized arguments return ok:false", () async {
      await seedVisualMessage(db, "session-1", "run-1");
      final result = await runTool("call-1", _plotArgs(title: "x" * 70000));
      expect(result["ok"], isFalse);
      expect(result["error"], contains("过长"));
      expect(await db.select(db.visualScenes).get(), isEmpty);
    });

    test(
      "replayed call returns the cached result without a duplicate",
      () async {
        await seedVisualMessage(db, "session-1", "run-1");
        final args = _plotArgs();
        final first = await runTool("call-1", args);
        expect(first["ok"], isTrue);
        final second = await runTool("call-1", args);
        expect(second["ok"], isTrue);
        expect(second["visual_id"], first["visual_id"]);
        expect(await db.select(db.visualScenes).get(), hasLength(1));
        final conflict = await runTool("call-1", _plotArgs(title: "另一个标题"));
        expect(conflict["ok"], isFalse);
        expect(await db.select(db.visualScenes).get(), hasLength(1));
      },
    );

    test(
      "a replayed create returns the cached computed values and note",
      () async {
        await seedVisualMessage(db, "session-1", "run-1");
        final first = await runTool("call-1", _plotArgs());
        expect(first["ok"], isTrue);
        expect(first["computed"], isNotNull);
        expect(first["note"], isA<String>());
        final replay = await runTool("call-1", _plotArgs());
        expect(replay["ok"], isTrue);
        expect(replay["visual_id"], first["visual_id"]);
        expect(replay["computed"], first["computed"]);
        expect(replay["note"], first["note"]);
        expect(await db.select(db.visualScenes).get(), hasLength(1));
      },
    );

    test("the 64 KiB cap counts UTF-8 bytes, not UTF-16 units", () async {
      await seedVisualMessage(db, "session-1", "run-1");
      // 20000 CJK chars are 20000 UTF-16 units but ~60000 UTF-8 bytes:
      // under the byte cap, so the scene is created.
      final under = await runTool("call-under", _plotArgs(title: "汉" * 20000));
      expect(under["ok"], isTrue);
      // 30000 CJK chars are still under 64000 UTF-16 units but ~90000
      // UTF-8 bytes: over the cap.
      final over = await runTool("call-over", _plotArgs(title: "汉" * 30000));
      expect(over["ok"], isFalse);
      expect(over["error"], contains("过长"));
      expect(await db.select(db.visualScenes).get(), hasLength(1));
    });

    test("study links for two owners create two study links", () async {
      await seedVisualMessage(db, "session-1", "run-1");
      final now = DateTime.now();
      // Two distinct study owners linked to one session: the loop links
      // the new scene to both. (Two links for the SAME owner cannot be
      // seeded: StudyChatLinks has unique keys on (session, knowledge)
      // and (session, mistake), so the executor never sees the same
      // owner twice; the single-row invariant for one owner is covered
      // at the store level in visual_store_test.dart.)
      for (final k in ["k1", "k2"]) {
        await db
            .into(db.knowledgeItems)
            .insert(
              KnowledgeItemsCompanion.insert(
                id: k,
                title: "知识点 $k",
                content: "正文",
                subject: "数学",
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.studyChatLinks)
            .insert(
              StudyChatLinksCompanion.insert(
                id: "l$k",
                sessionId: "session-1",
                knowledgeId: Value(k),
              ),
            );
      }
      final result = await runTool("call-1", _plotArgs());
      expect(result["ok"], isTrue);
      expect(await db.select(db.visualStudyLinks).get(), hasLength(2));
    });

    test("tool title and alt fill gaps in the scene", () async {
      await seedVisualMessage(db, "session-1", "run-1");
      final result = await runTool(
        "call-1",
        _plotArgs(
          scene: {
            "v": 1,
            "kind": "plot2d",
            "model": {"expression": "x^2"},
          },
          title: "工具标题",
          alt: "工具说明",
        ),
      );
      expect(result["ok"], isTrue);
      final row = (await db.select(db.visualScenes).get()).single;
      expect(row.title, "工具标题");
      final stored = (jsonDecode(row.sceneJson) as Map).cast<String, dynamic>();
      expect(stored["title"], "工具标题");
      expect((stored["meta"] as Map)["alt"], "工具说明");
    });

    test("scene title wins over the tool title", () async {
      await seedVisualMessage(db, "session-1", "run-1");
      final result = await runTool("call-1", _plotArgs(title: "工具标题"));
      expect(result["ok"], isTrue);
      final row = (await db.select(db.visualScenes).get()).single;
      expect(row.title, "二次函数");
      final stored = (jsonDecode(row.sceneJson) as Map).cast<String, dynamic>();
      expect(stored["title"], "二次函数");
    });

    test("unknown tool argument is rejected", () async {
      await seedVisualMessage(db, "session-1", "run-1");
      final result = await runTool("call-1", {
        ..._plotArgs(),
        "surprise": true,
      });
      expect(result["ok"], isFalse);
      expect(await db.select(db.visualScenes).get(), isEmpty);
    });
  });

  group("applyVisualPatchOps", () {
    Map<String, dynamic> groupScene() => {
      "v": 1,
      "kind": "geometry",
      "title": "分组",
      "elements": [
        {
          "id": "g1",
          "type": "group",
          "children": [
            {
              "id": "p1",
              "type": "point",
              "at": [0, 0],
            },
            {
              "id": "g2",
              "type": "group",
              "children": [
                {
                  "id": "p4",
                  "type": "point",
                  "at": [3, 3],
                },
              ],
            },
          ],
        },
        {
          "id": "p3",
          "type": "point",
          "at": [2, 2],
        },
      ],
      "meta": {"alt": "分组场景"},
    };

    test("replace_element reaches a point inside a group", () {
      final patched = applyVisualPatchOps(groupScene(), [
        {
          "op": "replace_element",
          "id": "p1",
          "element": {
            "id": "p1",
            "type": "point",
            "at": [1, 1],
          },
        },
      ]);
      final elements = patched["elements"] as List;
      final g1 = elements[0] as Map;
      expect(((g1["children"] as List)[0] as Map)["at"], [1, 1]);
      expect(((g1["children"] as List)[1] as Map)["id"], "g2");
      expect((elements[1] as Map)["id"], "p3");
      expect((elements[1] as Map)["at"], [2, 2]);
    });

    test("replace_element reaches a point in a nested group", () {
      final patched = applyVisualPatchOps(groupScene(), [
        {
          "op": "replace_element",
          "id": "p4",
          "element": {
            "id": "p4",
            "type": "point",
            "at": [4, 4],
          },
        },
      ]);
      final g1 = (patched["elements"] as List)[0] as Map;
      final g2 = (g1["children"] as List)[1] as Map;
      expect(((g2["children"] as List)[0] as Map)["at"], [4, 4]);
      expect(((g1["children"] as List)[0] as Map)["at"], [0, 0]);
    });

    test("remove_element removes a point inside a group", () {
      final patched = applyVisualPatchOps(groupScene(), [
        {"op": "remove_element", "id": "p1"},
      ]);
      final g1 = (patched["elements"] as List)[0] as Map;
      expect((g1["children"] as List).map((e) => (e as Map)["id"]).toList(), [
        "g2",
      ]);
      expect((patched["elements"] as List).length, 2);
    });

    test("remove_element of a nested-group point keeps its siblings", () {
      final patched = applyVisualPatchOps(groupScene(), [
        {"op": "remove_element", "id": "p4"},
      ]);
      final g1 = (patched["elements"] as List)[0] as Map;
      final g2 = (g1["children"] as List)[1] as Map;
      expect(g2["children"], isEmpty);
      expect(((g1["children"] as List)[0] as Map)["id"], "p1");
    });

    test("add_element rejects an id that exists inside a group", () {
      expect(
        () => applyVisualPatchOps(groupScene(), [
          {
            "op": "add_element",
            "element": {
              "id": "p1",
              "type": "point",
              "at": [9, 9],
            },
          },
        ]),
        throwsA(
          isA<AppFormatException>()
              .having(
                (e) => e.code,
                "code",
                AppErrorCode.errorInvalidParameterType,
              )
              .having((e) => e.message, "message", contains("图元 id 已存在"))
              .having((e) => e.arguments, "arguments", ["id"]),
        ),
      );
    });

    test("replace_element of a group id still replaces the group itself", () {
      final patched = applyVisualPatchOps(groupScene(), [
        {
          "op": "replace_element",
          "id": "g1",
          "element": {
            "id": "g1",
            "type": "group",
            "children": [
              {
                "id": "p1",
                "type": "point",
                "at": [7, 7],
              },
            ],
          },
        },
      ]);
      final g1 = (patched["elements"] as List)[0] as Map;
      expect(((g1["children"] as List)[0] as Map)["at"], [7, 7]);
    });
  });

  _visualToolChatCases();
}
