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
import 'package:tixun/features/practice/question_localization.dart';
import 'package:tixun/features/exams/exam_localization.dart';
import 'package:tixun/features/exams/exam_ai.dart';
import 'package:tixun/features/settings/prompt_localization.dart';
import 'package:tixun/features/review/review_screen.dart';
import 'package:tixun/features/library/study_localization.dart';
import 'package:tixun/features/update/update_localization.dart';
import 'package:tixun/features/update/update_models.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/app/app_notice.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ui/reasoning_labels.dart';
import 'package:tixun/core/ai/prompt_settings.dart';
import 'package:tixun/core/l10n/app_strings.dart';
import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/core/l10n/app_error_localization.dart';
import 'package:tixun/features/chat/chat_failure.dart';
import 'package:tixun/core/l10n/generated/app_localizations.dart';
import 'package:tixun/core/l10n/generated/app_localizations_en.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';

class _LegacyTranslationCalls extends RecursiveAstVisitor<void> {
  final calls = <String>[];
  String path = '';

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'tr' || node.methodName.name == 'uiText') {
      calls.add('$path: ${node.methodName.name}');
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructor = node.constructorName;
    if (constructor.name == null &&
        (constructor.type.toSource() == 'FormatException' ||
            constructor.type.toSource() == 'AiFailure') &&
        node.argumentList.arguments.isNotEmpty) {
      final first = node.argumentList.arguments.first;
      if ((first is StringLiteral) &&
          RegExp(r'[\u3400-\u9fff]').hasMatch(first.toSource())) {
        calls.add('$path: untyped app-authored exception ${first.toSource()}');
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

void main() {
  test('UI does not use source-text translation lookups', () {
    final visitor = _LegacyTranslationCalls();
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') ||
          file.path.endsWith('.g.dart') ||
          file.path.contains('/generated/')) {
        continue;
      }
      visitor.path = file.path;
      parseString(
        content: file.readAsStringSync(),
        throwIfDiagnostics: false,
      ).unit.accept(visitor);
    }
    expect(visitor.calls, isEmpty);
  });

  test('ARB catalogs have matching IDs and placeholder declarations', () {
    Map<String, dynamic> catalog(String locale) =>
        jsonDecode(File('assets/l10n/app_$locale.arb').readAsStringSync())
            as Map<String, dynamic>;
    final zh = catalog('zh');
    final en = catalog('en');
    expect(zh['@@locale'], 'zh');
    expect(en['@@locale'], 'en');
    final ids = zh.keys.where((key) => !key.startsWith('@')).toSet();
    expect(en.keys.where((key) => !key.startsWith('@')).toSet(), ids);
    for (final id in ids) {
      expect((zh[id] as String).trim(), isNotEmpty, reason: id);
      expect((en[id] as String).trim(), isNotEmpty, reason: id);
      Set<String> slots(Map<String, dynamic> catalog) {
        final metadata = catalog['@$id'] as Map<String, dynamic>?;
        final placeholders = metadata?['placeholders'] as Map<String, dynamic>?;
        return placeholders?.keys.toSet() ?? <String>{};
      }

      expect(slots(zh), slots(en), reason: id);
    }
    expect(
      resolveAppLocale([const Locale('fr'), const Locale('zh', 'TW')]),
      const Locale('zh'),
    );
    expect(resolveAppLocale([const Locale('de')]), const Locale('en'));
    final prompts = PromptSettings()
        .update('guided', '保留我的自定义内容')
        .withLanguage('en');
    expect(prompts.text('guided'), '保留我的自定义内容');
    expect(prompts.text('global'), startsWith('You are TiXun'));
    expect(
      teachingPrompt('exam', prompts: prompts),
      contains('Do not reveal answers'),
    );
  });

  test('typed failures and historical chat errors preserve unknown text', () {
    final en = AppLocalizationsEn();
    for (final code in AppErrorCode.values) {
      expect(appErrorText(en, code), isNotEmpty, reason: code.name);
    }
    const code = AppErrorCode.theNetworkRequestFailedTry;
    expect(
      chatFailureText(en, encodeChatFailure(code)),
      en.theNetworkRequestFailedTry,
    );
    expect(chatFailureText(en, '网络请求失败，请重试。'), en.theNetworkRequestFailedTry);
    expect(
      chatFailureText(en, encodeRawChatFailure('网络请求失败，请重试。')),
      '网络请求失败，请重试。',
    );
    expect(chatFailureText(en, '保存'), '保存');
    expect(
      chatFailureText(en, '${chatFailurePrefix}unknown'),
      '${chatFailurePrefix}unknown',
    );
    expect(
      failureText(en, const AiFailure.localized(code, '源文案')),
      en.theNetworkRequestFailedTry,
    );
    expect(
      failureText(en, const AppFormatException(code, '源文案')),
      en.theNetworkRequestFailedTry,
    );
    expect(failureText(en, const AiFailure('保存')), '保存');
    expect(failureText(en, const FormatException('保存')), '保存');
    const paramError = AppFormatException(
      AppErrorCode.errorMissingParameter,
      '缺少参数：{用户}。',
      ['{用户}'],
    );
    expect(failureText(en, paramError), 'Missing parameter: {用户}.');
    expect(
      failureText(en, AiFailure.fromFormatException(paramError)),
      'Missing parameter: {用户}.',
    );
    expect(
      failureText(
        en,
        const AppFormatException(AppErrorCode.errorStudyFieldTooLong, '标题过长', [
          'title',
          '160',
          'builtin',
        ]),
      ),
      'Title is too long (maximum 160 characters).',
    );
    expect(
      failureText(
        en,
        const AppFormatException(
          AppErrorCode.errorStudyFieldRequired,
          '自定义不能为空',
          ['自定义'],
        ),
      ),
      '自定义 cannot be empty.',
    );
    expect(
      failureText(
        en,
        const AppFormatException(
          AppErrorCode.errorStudyFieldRequired,
          'title不能为空',
          ['title'],
        ),
      ),
      'title cannot be empty.',
    );
    final stored = encodeChatFailure(AppErrorCode.errorServiceReturnedDetails, [
      '：{用户}',
    ]);
    expect(
      chatFailureText(en, stored),
      'The service returned an error：{用户}. Check the model configuration and try again.',
    );
    expect(
      chatFailureText(en, '$chatFailurePrefix{invalid'),
      '$chatFailurePrefix{invalid',
    );
    try {
      parseExamScores('{"questions":[{"label":"1","earned":"5"}]}');
      fail('expected parse failure');
    } on ExamScoresParseFailure catch (error) {
      expect(failureText(en, error), isNot(error.message));
      expect(error.rawText, contains('questions'));
    }
  });

  testWidgets('Generated accessors follow locale changes', (t) async {
    Widget app(Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Builder(
        builder: (context) => Column(
          children: [
            Text(context.l10n.interfaceLanguage),
            Text(context.l10n.overdueByDays('2')),
          ],
        ),
      ),
    );
    await t.pumpWidget(app(const Locale('en')));
    expect(find.text('Interface language'), findsOneWidget);
    expect(find.text('Overdue by 2 days'), findsOneWidget);
    await t.pumpWidget(app(const Locale('zh')));
    expect(find.text('界面语言'), findsOneWidget);
    expect(find.text('已逾期 2 天'), findsOneWidget);
  });

  testWidgets('Subject labels translate only built-in subjects', (t) async {
    late BuildContext context;
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: supportedAppLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(context.subjectName('数学'), 'Mathematics');
    // This is a translation key, but can also be a user-defined subject.
    expect(context.subjectName('保存'), '保存');
    expect(context.subjectName('自定义科目'), '自定义科目');
    expect(
      const AppNotice(
        AppNoticeKind.studyPhotosRecovered,
        photoCount: 1,
        mistake: true,
      ).text(context.l10n),
      'Restored one photo to Mistakes. Check the contents and add an explanation.',
    );
    expect(
      const AppNotice(
        AppNoticeKind.studyPhotosRecovered,
        photoCount: 2,
        mistake: true,
      ).text(context.l10n),
      'Restored 2 photos to Mistakes. Check the contents and add an explanation.',
    );
    expect(
      updateMessageText(context, UpdateMessage.newVersion, tag: 'v1'),
      'New version available: v1',
    );
    expect(knowledgeKindLabel(context, '概念'), 'Concept');
    expect(knowledgeKindLabel(context, '自定义'), '自定义');
    expect(mistakeReasonLabel(context, '粗心失误'), 'Careless mistake');
    expect(mistakeReasonLabel(context, '自定义'), '自定义');
    expect(questionKindLabel(context, 'single_choice'), 'Single choice');
    expect(questionKindLabel(context, 'custom_question'), 'custom_question');
    expect(examImageRoleLabel(context, 'sheet'), 'Answer sheet');
    expect(examImageRoleLabel(context, 'custom_role'), 'custom_role');
    const config = ProviderConfig(
      id: 1,
      kind: 'deepseek',
      baseUrl: '',
      model: '',
      vision: false,
      supportsTools: false,
      thinking: true,
      supportsThinking: true,
      effort: 'max',
    );
    expect(reasoningEffortLabel(context, AiOptions(config), 'max'), 'Maximum');
    expect(
      reasoningEffortLabel(context, AiOptions(config), 'custom'),
      'custom',
    );
    expect(
      reasoningOffLabel(context, AiOptions(config), choice: true),
      'Thinking off',
    );
    expect(
      reviewReason(context, '用户手动调整复习日期。'),
      'The review date was adjusted manually.',
    );
    expect(reviewReason(context, '我的自定义原因'), '我的自定义原因');
    final zh = jsonDecode(
      File('assets/l10n/app_zh.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final en = jsonDecode(
      File('assets/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final prompt in promptDefinitions) {
      String translation(String source) {
        final id = zh.entries
            .firstWhere(
              (entry) => !entry.key.startsWith('@') && entry.value == source,
            )
            .key;
        return en[id] as String;
      }

      expect(
        promptTitle(context, prompt),
        translation(prompt.title),
        reason: prompt.id,
      );
      expect(
        promptDescription(context, prompt),
        translation(prompt.description),
        reason: prompt.id,
      );
    }
  });

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
      expect(c.l10n.newStudyConversation, 'New study conversation');
      expect(c.l10n.subjectWithName('数学 {1}'), 'Subject: 数学 {1}');
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
