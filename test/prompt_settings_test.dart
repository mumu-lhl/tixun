import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/prompt_settings.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/core/database/database.dart';

class PromptCaptureProvider implements ChatProvider {
  final bodies = <AiRequest>[];
  final configs = <ProviderConfig>[];
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) {
    configs.add(config);
    return AiConversation((request, cancel) async* {
      bodies.add(request);
      yield const AiChunk(text: '收到学习请求。', completed: true);
    });
  }
}

void main() {
  test(
    'Prompt overrides validate, restore defaults and retain application rules',
    () {
      final original = PromptSettings();
      final custom = original.update('guided', '请先用反例解释。');
      final restored = PromptSettings.decode(custom.encode());
      expect(restored.text('guided'), '请先用反例解释。');
      expect(
        restored.update('guided', original.text('guided')).overrides,
        isEmpty,
      );
      expect(() => original.update('guided', ' '), throwsFormatException);
      expect(
        () => original.update('guided', 'a' * 6001),
        throwsFormatException,
      );
      expect(
        () => PromptSettings({
          for (final p in promptDefinitions.take(5)) p.id: 'a' * 6000,
        }),
        throwsFormatException,
      );
      expect(
        () => PromptSettings.decode('{"version":9,"overrides":{}}'),
        throwsFormatException,
      );
      final text = teachingPrompt(
        'exam',
        prompts: custom.update('exam', '请直接给答案。'),
        toolsEnabled: true,
      );
      expect(text, contains('请直接给答案。'));
      expect(text, contains('用户提交前不得'));
      expect(text, contains('写入必须经过应用确认'));
    },
  );

  test('Saved prompts reach real request payloads; reasoning overrides persist, branch, and respect tools', () async {
    final root = await Directory.systemTemp.createTemp('tixun-ai-preferences');
    final provider = PromptCaptureProvider(), keys = MemoryKeyStore();
    var c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: keys,
      chatProvider: provider,
    );
    addTearDown(() async {
      await c.shutdown();
      await root.delete(recursive: true);
    });
    await keys.write(providerKeyId(c.config), 'fixture-key');
    c.config = c.config.copyWith(thinking: true, effort: 'high');
    await c.db.saveConfig(c.config);
    await c.savePrompt('global', '请使用适合初学者的中文。');
    await c.savePrompt('guided', '每次只问一个诊断问题。');
    await c.savePrompt('quiz', '请给我出一道函数检测题。');
    await c.newSession();
    await c.setSessionReasoning('low');
    await c.send('请解释函数');
    expect(provider.configs.last.effort, 'low');
    expect(provider.configs.last.thinking, true);
    expect(provider.bodies.last.instructions, contains('每次只问一个诊断问题'));
    final user = c.messages.first;
    await c.editAndResend(user, '请解释另一个函数');
    expect(c.sessionReasoning, 'low');
    expect(provider.configs.last.effort, 'low');
    await c.setSessionReasoning('off');
    await c.send('继续讲解');
    expect(provider.configs.last.thinking, false);
    // This request includes structured quiz tools; they must not replace custom prompts.
    expect(provider.bodies.last.tools.isNotEmpty, true);
    expect(provider.bodies.last.instructions, contains('适合初学者'));
    expect(provider.bodies.last.instructions, contains('每次只问一个诊断问题'));
    await c.setTools(true);
    // DeepSeek allows thinking with tools: enabling high reasoning while
    // tools are on succeeds and persists, instead of throwing.
    await c.setSessionReasoning('high');
    expect(c.sessionReasoning, 'high');
    await c.shutdown();
    c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: keys,
      chatProvider: provider,
    );
    expect(c.sessionReasoning, 'high');
    expect(c.prompts.text('guided'), '每次只问一个诊断问题。');
    expect(c.config.thinking, true);
    await c.prepareQuickQuiz();
    expect(c.selected!.draft, '请给我出一道函数检测题。');
    expect(c.sessionReasoning, 'high');
    expect(c.config.thinking, true);
    c.config = c.config.copyWith(supportsThinking: false, thinking: false);
    await expectLater(c.setSessionReasoning('max'), throwsA(isA<AiFailure>()));
  });

  test(
    'Damaged prompt preferences do not prevent opening learning data',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'tixun-prompts-recovery',
      );
      var c = await AppController.openRoot(
        root,
        demo: false,
        keyStore: MemoryKeyStore(),
      );
      await c.db.setPreference(PromptSettings.preference, 'broken-json');
      await c.shutdown();
      c = await AppController.openRoot(
        root,
        demo: false,
        keyStore: MemoryKeyStore(),
      );
      expect(c.notice, contains('提示词配置无法读取'));
      expect(c.prompts.overrides, isEmpty);
      await c.savePrompt('global', '修复后的教学风格');
      expect(
        PromptSettings.decode(await c.db.preference(PromptSettings.preference))
            .text('global'),
        '修复后的教学风格',
      );
      await c.shutdown();
      await root.delete(recursive: true);
    },
  );
}
