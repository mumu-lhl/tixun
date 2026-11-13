import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/features/progress/learning_profile.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/prompt_settings.dart';
import 'package:tixun/core/l10n/app_strings.dart';
import 'package:tixun/core/l10n/messages_en.g.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';

class _TranslationCalls extends RecursiveAstVisitor<void> {
  final missing = <String>[];
  String path = '';

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'tr' &&
        node.argumentList.arguments.isNotEmpty) {
      final argument = node.argumentList.arguments.first.argumentExpression;
      if (argument is SimpleStringLiteral &&
          RegExp(r'[\u3400-\u9fff]').hasMatch(argument.value) &&
          !englishMessages.containsKey(argument.value)) {
        missing.add('$path: ${argument.value}');
      }
    }
    super.visitMethodInvocation(node);
  }
}

void main() {
  test('Literal UI translations have English catalog entries', () {
    final visitor = _TranslationCalls();
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('.g.dart')) {
        continue;
      }
      visitor.path = file.path;
      parseString(
        content: file.readAsStringSync(),
        throwIfDiagnostics: false,
      ).unit.accept(visitor);
    }
    expect(
      visitor.missing,
      isEmpty,
      reason: 'Add English translations for these UI messages',
    );
  });

  test(
    'English catalog matches its source and preserves all argument slots',
    () {
      final source = jsonDecode(File('assets/l10n/en.json').readAsStringSync());
      expect(englishMessages, source);
      final slot = RegExp(r'\{\d+\}');
      for (final entry in englishMessages.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
        expect(
          slot.allMatches(entry.value).map((m) => m[0]).toSet(),
          slot.allMatches(entry.key).map((m) => m[0]).toSet(),
          reason: entry.key,
        );
      }
      expect(
        resolveAppLocale([const Locale('fr'), const Locale('zh', 'TW')]),
        const Locale('zh'),
      );
      expect(resolveAppLocale([const Locale('de')]), const Locale('en'));
      expect(
        const AppStrings(Locale('en')).text('{0} · {1}', ['User {1}', 'label']),
        'User {1} · label',
      );
      expect(const AppStrings(Locale('en')).text('未知的用户内容'), '未知的用户内容');
      final prompts = PromptSettings()
          .update('guided', '保留我的自定义内容')
          .withLanguage('en');
      expect(prompts.text('guided'), '保留我的自定义内容');
      expect(prompts.text('global'), startsWith('You are TiXun'));
      expect(
        teachingPrompt('exam', prompts: prompts),
        contains('Do not reveal answers'),
      );
    },
  );

  test(
    'Language, palette and custom prompts survive a real database restart',
    () async {
      final root = await Directory.systemTemp.createTemp('tixun-locale-disk');
      final keys = MemoryKeyStore();
      var c = await AppController.openRoot(
        root,
        demo: false,
        keyStore: keys,
        chatProvider: MockChatProvider(),
      );
      await c.setLanguage('en');
      await c.setDynamicColors(false);
      await const LearningProfile(stage: '高三', region: '浙江').save(c.db);
      await c.savePrompt('guided', '请保留这段提示词。');
      await c.shutdown();
      c = await AppController.openRoot(
        root,
        demo: false,
        keyStore: keys,
        chatProvider: MockChatProvider(),
      );
      expect((await LearningProfile.load(c.db)).region, '浙江');
      expect((await LearningProfile.load(c.db)).stage, '高三');
      expect(c.languageChoice, 'en');
      expect(c.dynamicColors, false);
      expect(c.prompts.text('guided'), '请保留这段提示词。');
      expect(c.prompts.text('global'), startsWith('You are TiXun'));
      await c.shutdown();
      await root.delete(recursive: true);
    },
  );

  testWidgets(
    'English phone and desktop routes fit; language and colors persist without altering user content',
    (t) async {
      late AppController c;
      late Directory root;
      final keys = MemoryKeyStore();
      await t.runAsync(() async {
        root = await Directory.systemTemp.createTemp('tixun-locale');
        c = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          keys,
          MockChatProvider(),
          demo: true,
        );
        await c.initialize(seed: false);
        await c.savePrompt('guided', '请保留我的自定义提示词。');
        await c.newSession();
        await c.renameSession(c.selected!, '我的中文会话');
        await c.setLanguage('en');
        await c.setDynamicColors(false);
      });
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((_) => c)],
      );
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      for (final width in [360.0, 390.0, 1280.0]) {
        t.view.physicalSize = Size(width, 844);
        for (final path in [
          '/study',
          '/settings',
          '/settings/prompts',
          '/settings/prompts/guided',
          '/chat',
          '/knowledge',
          '/mistakes',
          '/practice',
          '/review',
          '/progress',
        ]) {
          scope.read(routerProvider).go(path);
          await t.pump();
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: '$width $path');
        }
      }
      scope.read(routerProvider).go('/settings');
      await t.pumpAndSettle();
      expect(find.text('Interface language'), findsOneWidget);
      expect(find.text('Dynamic colors'), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('dynamic-colors')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('dynamic-colors')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pumpAndSettle();
      expect(c.dynamicColors, true);
      await t.runAsync(() => c.setLanguage('zh'));
      await t.pumpAndSettle();
      expect(find.text('界面语言'), findsOneWidget);
      expect(c.prompts.text('guided'), '请保留我的自定义提示词。');
      expect(c.selected!.title, '我的中文会话');
      await t.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      await t.runAsync(() async {
        await c.db.close();
        if (await root.exists()) await root.delete(recursive: true);
      });
    },
  );
}
