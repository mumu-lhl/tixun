import "dart:io";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/app_strings.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/library/library_screen.dart";
import "package:tixun/features/library/study_store.dart";

void main() {
  late AppController controller;
  late ProviderContainer scope;
  late String matchingId, singleTagId, outsideDirectoryId, childId;

  setUp(() async {
    controller = AppController(
      AppDatabase.memory(),
      AttachmentStore(await Directory.systemTemp.createTemp("tixun-filter")),
      MemoryKeyStore(),
      MockChatProvider(),
      demo: true,
    );
    await controller.initialize(seed: false);
    scope = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => controller)],
    );
    final study = controller.study;
    final root = await study.modules.create("数学", "函数");
    childId = await study.modules.create("数学", "单调性", parentId: root);
    await study.modules.create("物理", "力学");
    matchingId = (await study.saveKnowledge(
      const KnowledgeDraft(title: "单调性例题", content: "求导判断", tags: ["代数", "复盘"]),
    )).id;
    singleTagId = (await study.saveKnowledge(
      const KnowledgeDraft(title: "导数例题", content: "求导判断", tags: ["代数"]),
    )).id;
    outsideDirectoryId = (await study.saveKnowledge(
      const KnowledgeDraft(title: "数列例题", content: "递推关系", tags: ["代数", "复盘"]),
    )).id;
    await study.modules.assign(matchingId, false, [childId]);
    await study.modules.assign(singleTagId, false, [childId]);
  });

  tearDown(() async {
    scope.dispose();
    await controller.shutdown();
    if (await controller.files.root.exists()) {
      await controller.files.root.delete(recursive: true);
    }
  });

  testWidgets("Search and combine directory and tags at phone width", (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: const MaterialApp(
          home: Scaffold(body: LibraryScreen(isMistake: false)),
        ),
      ),
    );
    await t.pumpAndSettle();
    final l10n = t.element(find.byType(LibraryScreen)).l10n;
    Finder byKey(String key) => find.byKey(ValueKey(key));
    Future<void> tap(Finder finder) async {
      await t.ensureVisible(finder);
      await t.tap(finder);
      await t.pumpAndSettle();
    }

    Future<void> search(String key, String text) async {
      await t.enterText(byKey(key), text);
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
    }

    await tap(byKey("module-filter"));
    await tap(find.text(l10n.manageDirectory));
    expect(byKey("module-add-root"), findsOneWidget);
    await tap(find.byType(BackButton));
    expect(find.text("物理"), findsOneWidget);
    await search("directory-filter-search", "单调");
    expect(byKey("directory-option-").hitTestable(), findsOneWidget);
    expect(
      byKey("directory-option-unclassified").hitTestable(),
      findsOneWidget,
    );
    expect(find.text("函数 / 单调性"), findsOneWidget);
    expect(find.text("力学"), findsNothing);
    final directoryOption = byKey("directory-option-$childId");
    await tap(directoryOption);
    await tap(byKey("module-filter"));
    expect(t.widget<ListTile>(directoryOption).selected, isTrue);
    await tap(find.byTooltip(l10n.close));
    expect(byKey(matchingId), findsOneWidget);
    expect(byKey(singleTagId), findsOneWidget);
    expect(byKey(outsideDirectoryId), findsNothing);

    await tap(byKey("tag-filter"));
    final algebra = byKey("tag-option-代数");
    final recap = byKey("tag-option-复盘");
    expect(t.getTopLeft(algebra).dy, lessThan(t.getTopLeft(recap).dy));
    expect(
      find.descendant(of: algebra, matching: find.text("3")),
      findsOneWidget,
    );
    await tap(algebra);
    await search("tag-filter-search", "复盘");
    expect(algebra, findsNothing);
    expect(find.widgetWithText(InputChip, "代数"), findsOneWidget);
    await tap(recap);
    await tap(find.text(l10n.applyFilters));
    expect(byKey(matchingId), findsOneWidget);
    expect(byKey(singleTagId), findsNothing);
    expect(byKey(outsideDirectoryId), findsNothing);

    await tap(byKey("tag-filter"));
    await tap(find.byTooltip(l10n.removeFilterTag("复盘")));
    await tap(find.text(l10n.applyFilters));
    expect(byKey(singleTagId), findsOneWidget);
    expect(byKey(outsideDirectoryId), findsNothing);

    await search("library-search", "单调性");
    expect(byKey(matchingId), findsOneWidget);
    expect(byKey(singleTagId), findsNothing);

    await tap(byKey("clear-library-filters"));
    expect(find.text(l10n.directoryLabel), findsOneWidget);
    expect(find.text(l10n.tagsLabel), findsOneWidget);
    expect(byKey(outsideDirectoryId), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
}
