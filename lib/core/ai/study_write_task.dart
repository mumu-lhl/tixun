import 'package:tixun/core/l10n/app_error.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../database/database.dart';
import 'ai_types.dart';

/// A UI-authorized writing task for one exact user turn. Later conversation
/// turns use the ordinary session permissions; retries retain the same scope.
class StudyWriteTask {
  StudyWriteTask({
    required this.operation,
    required String prompt,
    this.knowledgeId,
    this.sourceSessionId,
  }) : promptHash = _hash(prompt) {
    _validate();
  }
  StudyWriteTask._(
    this.operation,
    this.promptHash,
    this.knowledgeId,
    this.sourceSessionId,
  ) {
    _validate();
  }
  final String operation, promptHash;
  final String? knowledgeId, sourceSessionId;
  static String key(String session) => 'study_write_task:$session';
  static String _hash(String text) =>
      sha256.convert(utf8.encode(text.trim())).toString();
  void _validate() {
    if (![
          'create_knowledge',
          'update_knowledge',
          'create_mistake',
        ].contains(operation) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(promptHash) ||
        (operation == 'update_knowledge' &&
            (knowledgeId == null || knowledgeId!.isEmpty)) ||
        (knowledgeId?.length ?? 0) > 100 ||
        (sourceSessionId?.length ?? 0) > 100) {
      throw const AppFormatException(
        AppErrorCode.thisWritingTaskIsInvalid,
        '资料整理任务无效，请重新发起。',
      );
    }
  }

  Set<String> get tools => switch (operation) {
    'create_knowledge' => {
      'search_knowledge',
      'get_knowledge',
      'create_knowledge',
    },
    'update_knowledge' => {'get_knowledge', 'update_knowledge'},
    _ => {'create_mistake'},
  };
  bool allows(ToolCall call) {
    if (!tools.contains(call.name)) return false;
    if (operation != 'update_knowledge') return true;
    try {
      return (jsonDecode(call.arguments) as Map)['id'] == knowledgeId;
    } catch (_) {
      return false;
    }
  }

  Future<void> save(AppDatabase db, String session) => db.setPreference(
    key(session),
    jsonEncode({
      'operation': operation,
      'prompt_hash': promptHash,
      if (knowledgeId != null) 'knowledge_id': knowledgeId,
      if (sourceSessionId != null) 'source_session_id': sourceSessionId,
    }),
  );
  static Future<StudyWriteTask?> load(
    AppDatabase db,
    String session,
    String prompt,
  ) async {
    final raw = await db.preference(key(session));
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map;
      final task = StudyWriteTask._(
        m['operation'] as String,
        m['prompt_hash'] as String,
        m['knowledge_id'] as String?,
        m['source_session_id'] as String?,
      );
      return task.promptHash == _hash(prompt) ? task : null;
    } catch (_) {
      throw const AiFailure.localized(
        AppErrorCode.thisWritingTaskIsInvalid,
        '资料整理任务无效，请重新发起。',
      );
    }
  }

  Map<String, Object?> get context => {
    'operation': operation,
    if (knowledgeId != null) 'knowledge_id': knowledgeId,
  };
}
