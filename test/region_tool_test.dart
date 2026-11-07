import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/region_tool.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/split_suggestions.dart';

void main() {
  test('Region schema rejects incomplete, nonfinite, reversed and out-of-image rectangles', () {
    final good = {
      'label': '第一题',
      'subject': '数学',
      'left': 0.0,
      'top': 0.1,
      'right': 1.0,
      'bottom': 0.5,
    };
    expect(QuestionRegion.fromJson(good).bottom, .5);
    for (final bad in [
      {...good, 'right': -1},
      {...good, 'top': double.nan},
      {...good, 'left': .99},
      {...good, 'path': '/etc/passwd'},
      {...good}..remove('bottom'),
    ]) {
      expect(() => QuestionRegion.fromJson(bad), throwsFormatException);
    }
  });
  test('AI split stays a proposal until confirmed; acceptance is atomic, deduplicated and retains original and crop', () async {
    final root = await Directory.systemTemp.createTemp('tixun-regions');
    final c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      MockChatProvider(),
    );
    addTearDown(() async {
      await c.shutdown();
      await root.delete(recursive: true);
    });
    await c.initialize();
    await c.newSession();
    await c.addImage('assets/demo/two_problems.png');
    await c.send('请给这张图片分题');
    expect(c.messages.last.status, 'complete');
    expect(await c.study.searchMistakes(), isEmpty);
    final op = (await c.db.select(c.db.aiToolOperations).get()).single;
    expect(op.name, 'suggest_question_regions');
    final result = jsonDecode(op.result!) as Map;
    expect((result['regions'] as List).length, 2);
    final bytes = await File('assets/demo/two_problems.png').readAsBytes();
    final one = await saveSplitSuggestion(
      c.study,
      op.id,
      0,
      bytes,
      const Rect.fromLTRB(0, .1, 1, .4),
      0,
    );
    final twice = await saveSplitSuggestion(
      c.study,
      op.id,
      0,
      bytes,
      const Rect.fromLTRB(0, .1, 1, .4),
      0,
    );
    expect(twice, one);
    expect((await c.study.searchMistakes()).length, 1);
    final images = await c.study.images(one, isMistake: true);
    expect(images.length, 2);
    expect(images.map((a) => a.role).toSet(), {'original', 'crop'});
    expect((await c.study.mistake(one)).sourceMessageId, op.runId);
    final originals = await root
        .list(recursive: true)
        .where((f) => f is File)
        .toList();
    await c.db.customStatement(
      "CREATE TRIGGER reject_proposal_accept BEFORE UPDATE ON ai_tool_operations BEGIN SELECT RAISE(ABORT,'fail'); END",
    );
    await expectLater(
      saveSplitSuggestion(
        c.study,
        op.id,
        1,
        bytes,
        const Rect.fromLTRB(0, .5, 1, .9),
        0,
      ),
      throwsA(anything),
    );
    expect(
      (await c.study.searchMistakes()).length,
      1,
      reason: 'Audit failure rolls new mistake back',
    );
    expect(
      (await root.list(recursive: true).where((f) => f is File).toList())
          .length,
      originals.length,
      reason: 'Unused crop is removed after rollback',
    );
    final noImage = await executeRegionTool(
      c.db,
      ToolCall(
        'bad',
        'suggest_question_regions',
        jsonEncode({'image_index': 1, 'regions': result['regions']}),
      ),
      sessionId: c.selected!.id,
      runId: op.runId,
      sourceImages: c.attachments,
      cancel: CancelToken(),
    );
    expect(noImage['ok'], false);
    expect(await c.db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
}
