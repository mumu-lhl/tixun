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
    this.partialFallback = false,
  });
  final String stage, exam, scope, teaching;
  final DateTime? examDate;
  final int dailyMinutes;

  /// True when a stored profile existed but at least one field could not be
  /// read and fell back to its default. Callers that can show UI (the
  /// settings editor) surface this so a bad field never silently overwrites
  /// the rest on the next save.
  final bool partialFallback;
  static Future<LearningProfile> load(AppDatabase db) async {
    final raw = await db.preference('learning_profile');
    if (raw == null || raw.isEmpty) return const LearningProfile();
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const LearningProfile(partialFallback: true);
      data = decoded.cast<String, dynamic>();
    } catch (_) {
      return const LearningProfile(partialFallback: true);
    }
    var partial = false;
    String stringField(String key, String fallback) {
      final value = data[key];
      if (value is String) return value;
      if (value != null) partial = true;
      return fallback;
    }

    int minutesField() {
      final value = data['daily_minutes'];
      final minutes = value is int
          ? value
          : value is num && value == value.roundToDouble()
          ? value.toInt()
          : null;
      if (minutes == null) {
        if (value != null) partial = true;
        return 45;
      }
      return minutes.clamp(5, 480);
    }

    DateTime? dateField() {
      final value = data['exam_date'];
      if (value == null) return null;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed == null) partial = true;
        return parsed;
      }
      partial = true;
      return null;
    }

    var teachingValue = 'guided';
    final teaching = data['teaching'];
    if (teaching is String && ['guided', 'direct', 'exam'].contains(teaching)) {
      teachingValue = teaching;
    } else if (teaching != null) {
      partial = true;
    }
    return LearningProfile(
      stage: stringField('stage', '高中'),
      exam: stringField('exam', '高考'),
      examDate: dateField(),
      dailyMinutes: minutesField(),
      scope: stringField('scope', ''),
      teaching: teachingValue,
      partialFallback: partial,
    );
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
