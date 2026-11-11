import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tixun/features/exams/exam_calendar.dart';
import 'package:tixun/features/chat/session_list.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/app/theme.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

// Keep the splash alive so cross-page paint is observable independently of
// animation duration. Routes, ListTiles and Material ownership are real.
class _InkProbe extends InteractiveInkFeature {
  _InkProbe({
    required super.controller,
    required super.referenceBox,
    required super.color,
    super.onRemoved,
  }) {
    controller.addInkFeature(this);
  }
  int paints = 0;
  bool removed = false;
  @override
  void dispose() {
    removed = true;
    super.dispose();
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    paints++;
    canvas.save();
    canvas.transform(transform.storage);
    canvas.drawRect(Offset.zero & referenceBox.size, Paint()..color = color);
    canvas.restore();
  }
}

class _InkFactory extends InteractiveInkFeatureFactory {
  final inks = <_InkProbe>[];
  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    final ink = _InkProbe(
      controller: controller,
      referenceBox: referenceBox,
      color: Colors.white,
      onRemoved: onRemoved,
    );
    inks.add(ink);
    return ink;
  }
}

void main() {
  late AppController c;
  late ProviderContainer scope;
  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('tixun-navigation');
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(dir),
      MemoryKeyStore(),
      MockChatProvider(),
      demo: true,
    );
    await c.initialize();
    scope = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
    );
  });
  tearDown(() async {
    scope.dispose();
    await c.shutdown();
    if (await c.files.root.exists()) await c.files.root.delete(recursive: true);
  });

  testWidgets(
    'settings rows have rounded ink boundaries and comfortable insets',
    (t) async {
      scope.read(routerProvider).go('/settings');
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      await t.pumpAndSettle();
      final row = find.byKey(const Key('settings-subjects'));
      final ink = t.widget<InkWell>(
        find.descendant(of: row, matching: find.byType(InkWell)),
      );
      expect(ink.customBorder, isA<RoundedRectangleBorder>());
      final shape = ink.customBorder! as RoundedRectangleBorder;
      final corner = shape.borderRadius.resolve(TextDirection.ltr).topLeft;
      expect(corner.x, greaterThan(0));
      expect(corner.y, greaterThan(0));
      final tile = t.widget<ListTile>(row);
      final padding =
          tile.contentPadding ??
          ListTileTheme.of(t.element(row)).contentPadding!;
      expect(padding.resolve(TextDirection.ltr).left, greaterThanOrEqualTo(12));
      final press = await t.startGesture(t.getCenter(row));
      await t.pump(const Duration(milliseconds: 100));
      await press.up();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    },
  );

  testWidgets('Session list exposes hidden conversations by clearing filters', (
    t,
  ) async {
    await c.setSubjectFilter('物理');
    await c.searchSessions('受力');
    expect(c.sessions.length, lessThan(c.allSessions.length));
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(body: SessionList()),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('session-show-all')));
    await t.pumpAndSettle();
    expect(c.subjectFilter, isEmpty);
    expect(c.search, isEmpty);
    expect(c.sessions.length, c.allSessions.length);
    expect(find.text('二次函数：从配方理解顶点'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });

  testWidgets('settings link ink cannot paint on the pushed page', (t) async {
    final ink = _InkFactory();
    final router = scope.read(routerProvider)..go('/settings');
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp.router(
          routerConfig: router,
          theme: appTheme(Brightness.light).copyWith(splashFactory: ink),
        ),
      ),
    );
    await t.pumpAndSettle();
    for (final label in ['模型与连接', '提示词管理', '学习科目']) {
      router.go('/settings');
      await t.pumpAndSettle();
      await t.tap(find.text(label));
      await t.pumpAndSettle();
      expect(ink.inks, isNotEmpty);
      final prior = ink.inks.where((f) => !f.removed).toList();
      for (final feature in prior) {
        feature.paints = 0;
        feature.controller.markNeedsPaint();
      }
      await t.pump();
      expect(
        prior.map((f) => f.paints).fold(0, (a, b) => a + b),
        0,
        reason: 'The $label click effect must stay on its own route',
      );
    }
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });

  testWidgets('exam calendar can return after push and a direct route', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    final router = GoRouter(
      initialLocation: '/study',
      routes: [
        GoRoute(
          path: '/study',
          builder: (_, _) => const Scaffold(body: Text('Study home')),
        ),
        GoRoute(
          path: '/exams',
          builder: (_, _) => const Scaffold(body: ExamCalendarScreen()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    router.push('/exams');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('exam-calendar-back')), findsOneWidget);
    await t.tap(find.byKey(const Key('exam-calendar-back')));
    await t.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/study');
    router.go('/exams');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('exam-calendar-back')));
    await t.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/study');
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
}
