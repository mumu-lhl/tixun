import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/app/theme.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/scratchpad/scratchpad_screen.dart';

void main() {
  late AppController c;
  late ProviderContainer scope;
  setUp(() async {
    final root = await Directory.systemTemp.createTemp('tixun-palette');
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      MockChatProvider(),
    );
    await c.initialize();
    scope = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
    );
  });
  tearDown(() async {
    scope.dispose();
    c.dispose();
    await c.db.close();
    await c.files.root.delete(recursive: true);
  });
  testWidgets('Narrow palettes scroll to select colors without wrapping', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(360, 700);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          theme: appTheme(Brightness.light).copyWith(
            platform: TargetPlatform.android,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.standard,
          ),
          home: const ScratchpadScreen('chat:palette'),
        ),
      ),
    );
    await t.pumpAndSettle();
    final palette = find.byKey(const Key('scratch-colors'));
    final first = find.byKey(const ValueKey('scratch-color-4280232247'));
    final last = find.byKey(const ValueKey('scratch-color-4287323382'));
    expect((t.getCenter(first).dy - t.getCenter(last).dy).abs(), lessThan(1));
    final scroll = t.state<ScrollableState>(
      find.descendant(of: palette, matching: find.byType(Scrollable)),
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await t.drag(palette, const Offset(-180, 0));
    await t.pumpAndSettle();
    expect(scroll.position.pixels, greaterThan(0));
    await t.tap(last);
    await t.pumpAndSettle();
    expect((t.widget<IconButton>(last).icon as Icon).icon, Icons.check_circle);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
}
