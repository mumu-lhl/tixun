import "dart:io";
import "dart:typed_data";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/library/library_screen.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/export/study_export.dart";
import "package:tixun/core/l10n/app_strings.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/features/library/study_export.dart";
import "package:tixun/features/library/study_export_dialog.dart";
import "package:tixun/features/library/study_store.dart";

void main() {
  group("StudyExportService", () {
    late AppDatabase db;
    late Directory root;
    late StudyStore store;
    late StudyExportService service;

    setUp(() async {
      db = AppDatabase.memory();
      root = await Directory.systemTemp.createTemp("tixun-export");
      store = StudyStore(db, AttachmentStore(root));
      service = StudyExportService(
        store,
        loadFont: (key) async {
          final bytes = await File(key).readAsBytes();
          final data = ByteData.view(
            bytes.buffer,
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          );
          return data;
        },
      );
    });

    tearDown(() async {
      await store.whenIdle;
      store.dispose();
      await db.close();
      await root.delete(recursive: true);
    });

    test("keeps the caller order, tags and attachments", () async {
      final a = await store.saveKnowledge(
        const KnowledgeDraft(
          title: "分页资料 A",
          content: r"二次函数 $y=ax^2$",
          subject: "数学",
          chapter: "第二章",
          tags: ["函数"],
        ),
      );
      final b = await store.saveKnowledge(
        const KnowledgeDraft(title: "导数", content: "导数定义", subject: "数学"),
      );
      await store.importImage(
        a.id,
        "assets/demo/two_problems.png",
        isMistake: false,
      );

      final bundle = await service.load(
        ids: [b.id, a.id],
        title: "知识打印稿",
        generatedAt: DateTime.utc(2026, 11, 10),
        includeImages: true,
      );
      expect(bundle.notes.map((note) => note.title), ["导数", "分页资料 A"]);
      final exported = bundle.notes.last;
      expect(exported.tags, ["函数"]);
      expect(exported.chapter, "第二章");
      expect(exported.images, hasLength(1));
      expect(exported.images.single.isPng, isTrue);
    });

    test(
      "skips trashed notes and images when they are not requested",
      () async {
        final a = await store.saveKnowledge(
          const KnowledgeDraft(title: "保留", content: "内容"),
        );
        final b = await store.saveKnowledge(
          const KnowledgeDraft(title: "回收区", content: "内容"),
        );
        await store.importImage(
          a.id,
          "assets/demo/two_problems.png",
          isMistake: false,
        );
        await store.setDeleted(
          b.id,
          isMistake: false,
          deleted: true,
          expectedRevision: b.revision,
        );

        final bundle = await service.load(
          ids: [a.id, b.id],
          title: "知识打印稿",
          generatedAt: DateTime.utc(2026, 11, 10),
          includeImages: false,
        );
        expect(bundle.notes.map((note) => note.title), ["保留"]);
        expect(bundle.notes.single.images, isEmpty);
      },
    );

    test("renders every format for a note with maths and images", () async {
      final a = await store.saveKnowledge(
        const KnowledgeDraft(
          title: "顶点式",
          content: r"""
## 要点

顶点为 $(h,k)$，判别式 $\Delta=b^2-4ac$。

| 条件 | 开口 |
| --- | --- |
| $a>0$ | 向上 |
""",
          tags: ["函数"],
        ),
      );
      await store.importImage(
        a.id,
        "assets/demo/two_problems.png",
        isMistake: false,
      );
      final bundle = await service.load(
        ids: [a.id],
        title: "知识打印稿",
        generatedAt: DateTime.utc(2026, 11, 10),
        includeImages: true,
      );
      final chrome = StudyExportChrome(
        title: "知识打印稿",
        dateLine: "生成于 2026-11-10 · 共 1 条",
        pageLabel: (page, total) => "第 $page / $total 页",
        noteMeta: (note) => note.subject,
        imagesExcluded: "纯文本导出不包含图片附件。",
      );

      for (final format in StudyExportFormat.values) {
        final bytes = await service.render(
          bundle,
          format,
          chrome: chrome,
          includeImages: true,
        );
        expect(bytes, isNotEmpty, reason: format.name);
        if (format == StudyExportFormat.pdf) {
          expect(String.fromCharCodes(bytes.sublist(0, 4)), "%PDF");
        }
        if (format == StudyExportFormat.docx) {
          // A docx is a zip: local file header signature.
          expect(bytes.sublist(0, 2), [0x50, 0x4b]);
        }
      }
    });

    test("names the file with the local date and the format extension", () {
      final now = DateTime(2026, 11, 10, 9, 5);
      expect(
        exportFileName(now, StudyExportFormat.pdf),
        "tixun-notes-20261110-0905.pdf",
      );
      expect(exportFileName(now, StudyExportFormat.docx), endsWith(".docx"));
      expect(exportFileName(now, StudyExportFormat.markdown), endsWith(".md"));
    });
  });

  group("Library entry point", () {
    late AppController controller;
    late ProviderContainer scope;
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp("tixun-export-ui");
      controller = AppController(
        AppDatabase.memory(),
        AttachmentStore(dir),
        MemoryKeyStore(),
        MockChatProvider(),
        demo: true,
      );
      await controller.initialize();
      scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
      );
    });

    tearDown(() async {
      scope.dispose();
      await controller.shutdown();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    testWidgets("selection offers the print export dialog", (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: const MaterialApp(
            home: Scaffold(body: LibraryScreen(isMistake: false)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("更多操作"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("选择多条资料"));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(find.text("导出打印版"), findsOneWidget);
      await tester.tap(find.text("导出打印版"));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text("导出知识"), findsOneWidget);
      await tester.tap(find.text("取消"));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });

  group("Progress dialog", () {
    Widget host(Future<StudyExportOutcome> Function() run) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const Key("start"),
              onPressed: () async {
                final outcome = await showDialog<StudyExportOutcome>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      StudyExportProgressDialog(message: "正在生成打印文件…", run: run),
                );
                if (!context.mounted || outcome == null) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${outcome.savedName}:${outcome.failed}"),
                  ),
                );
              },
              child: const Text("start"),
            ),
          ),
        ),
      ),
    );

    testWidgets("closes itself and reports the saved file", (tester) async {
      await tester.pumpWidget(
        host(() async => const StudyExportOutcome(savedName: "a.pdf")),
      );
      await tester.tap(find.byKey(const Key("start")));
      await tester.pump();
      expect(find.text("正在生成打印文件…"), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text("正在生成打印文件…"), findsNothing);
      expect(find.text("a.pdf:false"), findsOneWidget);
    });

    testWidgets("turns a thrown error into a failure outcome", (tester) async {
      await tester.pumpWidget(host(() async => throw StateError("boom")));
      await tester.tap(find.byKey(const Key("start")));
      await tester.pumpAndSettle();
      expect(find.text("null:true"), findsOneWidget);
    });
  });

  group("Export dialog", () {
    Widget app() => MaterialApp(
      locale: const Locale("zh"),
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final choice = await showStudyExportDialog(context);
                if (choice == null) return;
                Text(
                  "${choice.format.name}:${choice.includeImages}",
                  textDirection: TextDirection.ltr,
                );
              },
              child: const Text("open"),
            ),
          ),
        ),
      ),
    );

    testWidgets("defaults to PDF with images", (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text("open"));
      await tester.pumpAndSettle();
      expect(find.text("PDF（可直接打印）"), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key("export-include-images")),
            )
            .value,
        isTrue,
      );
    });

    testWidgets("markdown cannot include attachments", (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text("open"));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("export-format-markdown")));
      await tester.pumpAndSettle();
      final tile = tester.widget<SwitchListTile>(
        find.byKey(const Key("export-include-images")),
      );
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNull);
      expect(find.text("纯文本导出不包含图片附件。"), findsOneWidget);
    });
  });
}
