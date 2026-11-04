import 'dart:convert';

import '../../core/database/database.dart';

class LearningProfile {
  const LearningProfile({
    this.stage = '高中',
    this.exam = '高考',
    this.examDate,
    this.dailyMinutes = 45,
    this.scope = '',
    this.teaching = 'guided',
  });
  final String stage, exam, scope, teaching;
  final DateTime? examDate;
  final int dailyMinutes;
  static Future<LearningProfile> load(AppDatabase db) async {
    try {
      final data =
          jsonDecode(await db.preference('learning_profile') ?? '{}') as Map;
      return LearningProfile(
        stage: data['stage'] as String? ?? '高中',
        exam: data['exam'] as String? ?? '高考',
        examDate: DateTime.tryParse(data['exam_date'] as String? ?? ''),
        dailyMinutes: (data['daily_minutes'] as int? ?? 45).clamp(5, 480),
        scope: data['scope'] as String? ?? '',
        teaching: ['guided', 'direct', 'exam'].contains(data['teaching'])
            ? data['teaching'] as String
            : 'guided',
      );
    } catch (_) {
      return const LearningProfile();
    }
  }

  Future<void> save(AppDatabase db) async {
    if (stage.trim().isEmpty ||
        stage.length > 100 ||
        exam.length > 100 ||
        scope.length > 4000 ||
        dailyMinutes < 5 ||
        dailyMinutes > 480 ||
        !['guided', 'direct', 'exam'].contains(teaching)) {
      throw const FormatException('学习设置内容无效。');
    }
    await db.setPreference(
      'learning_profile',
      jsonEncode({
        'stage': stage.trim(),
        'exam': exam.trim(),
        'exam_date': examDate?.toIso8601String(),
        'daily_minutes': dailyMinutes,
        'scope': scope.trim(),
        'teaching': teaching,
      }),
    );
  }
}
