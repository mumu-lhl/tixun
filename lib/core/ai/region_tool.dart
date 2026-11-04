import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../database/database.dart';
import 'chat_provider.dart';
import 'study_tools.dart';

class QuestionRegion {
  const QuestionRegion(
    this.label,
    this.subject,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.question,
  );
  final String label, subject, question;
  final double left, top, right, bottom;
  factory QuestionRegion.fromJson(Map<String, dynamic> a) {
    if (a.keys.any(
      (k) => !{
        'label',
        'subject',
        'left',
        'top',
        'right',
        'bottom',
        'question',
      }.contains(k),
    )) {
      throw const FormatException('分题区域包含未知字段。');
    }
    final label = a['label'],
        subject = a['subject'],
        question = a['question'] ?? '';
    if (label is! String ||
        label.trim().isEmpty ||
        label.length > 150 ||
        subject is! String ||
        subject.trim().isEmpty ||
        subject.length > 80 ||
        question is! String ||
        question.length > 12000) {
      throw const FormatException('分题文字无效。');
    }
    double coordinate(String name) {
      final v = a[name];
      if (v is! num || !v.isFinite || v < 0 || v > 1) {
        throw const FormatException('分题坐标应在图片范围内。');
      }
      return v.toDouble();
    }

    final l = coordinate('left'),
        t = coordinate('top'),
        r = coordinate('right'),
        b = coordinate('bottom');
    if (r - l < .02 || b - t < .02) throw const FormatException('分题范围太小或方向错误。');
    return QuestionRegion(label.trim(), subject.trim(), l, t, r, b, question);
  }
  Map<String, dynamic> toJson() => {
    'label': label,
    'subject': subject,
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
    'question': question,
  };
}

final regionToolSchema = {
  'type': 'function',
  'function': {
    'name': 'suggest_question_regions',
    'description': '对当前请求中的一张图片提出分题建议，不自动创建错题。图片按本次请求出现顺序从0编号。矩形相对于原图归一化，用户可检查、修改并逐题保存。OCR 不确定时 question 留空，禁止编造题目条件。',
    'parameters': {
      'type': 'object',
      'additionalProperties': false,
      'required': ['image_index', 'regions'],
      'properties': {
        'image_index': {'type': 'integer', 'minimum': 0, 'maximum': 3},
        'regions': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 12,
          'items': {
            'type': 'object',
            'additionalProperties': false,
            'required': ['label', 'subject', 'left', 'top', 'right', 'bottom'],
            'properties': {
              'label': {'type': 'string'},
              'subject': {'type': 'string'},
              'question': {'type': 'string'},
              for (final k in ['left', 'top', 'right', 'bottom'])
                k: {'type': 'number', 'minimum': 0, 'maximum': 1},
            },
          },
        },
      },
    },
  },
};
Future<Map<String, dynamic>> executeRegionTool(
  AppDatabase db,
  ToolCall call, {
  required String sessionId,
  required String runId,
  required List<Attachment> sourceImages,
  required CancelToken cancel,
}) async {
  try {
    cancel.checkCancelled();
    if (call.arguments.length > 64000) throw const FormatException('分题建议过长。');
    final args = (jsonDecode(call.arguments) as Map).cast<String, dynamic>();
    if (args.keys.any((k) => !['image_index', 'regions'].contains(k)) ||
        args['image_index'] is! int ||
        args['regions'] is! List) {
      throw const FormatException('分题建议格式无效。');
    }
    final index = args['image_index'] as int, raw = args['regions'] as List;
    if (index < 0 ||
        index >= sourceImages.length ||
        raw.isEmpty ||
        raw.length > 12) {
      throw const FormatException('没有对应原图，或分题数量无效。');
    }
    final image = sourceImages[index];
    if (image.sessionId != sessionId) throw const FormatException('图片不属于本次请求。');
    final regions = raw
        .map((r) => QuestionRegion.fromJson((r as Map).cast<String, dynamic>()))
        .toList();
    final encoded = canonicalJson(args), id = '$runId:${call.id}';
    return await db.transaction(() async {
      cancel.checkCancelled();
      final existing = await (db.select(
        db.aiToolOperations,
      )..where((o) => o.id.equals(id))).getSingleOrNull();
      if (existing != null) {
        if (existing.name != call.name || existing.arguments != encoded) {
          throw const FormatException('工具调用 ID 已被其他参数使用。');
        }
        return (jsonDecode(existing.result!) as Map).cast<String, dynamic>();
      }
      final duplicate =
          await (db.select(db.aiToolOperations)
                ..where(
                  (o) =>
                      o.runId.equals(runId) &
                      o.name.equals(call.name) &
                      o.arguments.equals(encoded) &
                      o.status.equals('succeeded'),
                )
                ..limit(1))
              .getSingleOrNull();
      if (duplicate != null) {
        return (jsonDecode(duplicate.result!) as Map).cast<String, dynamic>();
      }
      final result = {
        'ok': true,
        'image_id': image.id,
        'regions': regions.map((r) => r.toJson()).toList(),
        'accepted': <String, String>{},
        'note': '仅为边界建议，须由用户检查、修改并逐题确认保存。',
      };
      await db
          .into(db.aiToolOperations)
          .insert(
            AiToolOperationsCompanion.insert(
              id: id,
              runId: runId,
              sessionId: sessionId,
              name: call.name,
              arguments: encoded,
              status: 'succeeded',
              result: Value(jsonEncode(result)),
              createdAt: DateTime.now(),
            ),
          );
      cancel.checkCancelled();
      return result;
    });
  } on DioException {
    rethrow;
  } catch (e) {
    return {
      'ok': false,
      'error': e is FormatException ? e.message : '分题建议格式无效或保存失败。',
    };
  }
}
