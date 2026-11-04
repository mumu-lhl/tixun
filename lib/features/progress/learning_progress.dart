import '../../core/database/database.dart';

class TopicEvidence {
  const TopicEvidence(this.name, this.subject, this.questions, this.correct);
  final String name, subject;
  final int questions, correct;
  String get description => questions < 3
      ? '样本不足：$questions 道独立检测题'
      : '最近独立检测 $correct / $questions 道正确';
}

class LearningProgress {
  const LearningProgress({
    required this.total,
    required this.checked,
    required this.self,
    required this.unverified,
    required this.hinted,
    required this.correct,
    required this.topics,
    required this.recent,
    required this.errorReasons,
  });
  final int total, checked, self, unverified, hinted, correct;
  final List<TopicEvidence> topics;
  final List<
    ({
      String stem,
      String subject,
      String basis,
      bool correct,
      bool hint,
      DateTime time,
    })
  >
  recent;
  final Map<String, int> errorReasons;
  static Future<LearningProgress> load(AppDatabase db) async {
    final counts = await db
        .customSelect(
          "SELECT count(*) total, sum(grading_basis='deterministic') checked, sum(grading_basis='self') self, sum(grading_basis='ai_reference') unverified, sum(hint_used) hinted, sum(correct) correct FROM practice_attempts WHERE status='graded'",
        )
        .getSingle();
    int n(String name) => counts.readNullable<int>(name) ?? 0;
    final topics = await db.customSelect(
      '''WITH ranked AS (
      SELECT a.*,row_number() OVER(PARTITION BY question_id ORDER BY submitted_at DESC,rowid DESC) pos
      FROM practice_attempts a WHERE status='graded')
      SELECT t.name,t.subject,count(*) n,sum(a.correct) correct FROM ranked a
      JOIN practice_question_topics l ON l.question_id=a.question_id
      JOIN learning_topics t ON t.id=l.topic_id
      WHERE a.pos=1 AND a.grading_basis='deterministic' AND a.hint_used=0
      GROUP BY t.id ORDER BY (count(*)-sum(a.correct)) DESC,count(*) DESC LIMIT 12''',
    ).get();
    final recent = await db.customSelect('''SELECT q.stem,q.subject,a.grading_basis,a.correct,a.hint_used,a.submitted_at
      FROM practice_attempts a JOIN practice_questions q ON q.id=a.question_id WHERE a.status='graded'
      ORDER BY a.submitted_at DESC,a.rowid DESC LIMIT 12''').get();
    final reasons = await db
        .customSelect(
          "SELECT error_reason,count(*) n FROM mistakes WHERE deleted=0 AND error_reason<>'暂未确定' GROUP BY error_reason ORDER BY n DESC LIMIT 8",
        )
        .get();
    return LearningProgress(
      total: n('total'),
      checked: n('checked'),
      self: n('self'),
      unverified: n('unverified'),
      hinted: n('hinted'),
      correct: n('correct'),
      topics: topics
          .map(
            (r) => TopicEvidence(
              r.read<String>('name'),
              r.read<String>('subject'),
              r.read<int>('n'),
              r.read<int>('correct'),
            ),
          )
          .toList(),
      recent: recent
          .map(
            (r) => (
              stem: r.read<String>('stem'),
              subject: r.read<String>('subject'),
              basis: r.read<String>('grading_basis'),
              correct: r.read<bool>('correct'),
              hint: r.read<bool>('hint_used'),
              time: DateTime.fromMillisecondsSinceEpoch(
                r.read<int>('submitted_at') * 1000,
              ),
            ),
          )
          .toList(),
      errorReasons: {
        for (final r in reasons)
          r.read<String>('error_reason'): r.read<int>('n'),
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'graded_attempts': total,
    'checked_answer_attempts': checked,
    'self_assessed': self,
    'ai_reference_unverified': unverified,
    'hinted_attempts': hinted,
    'mastery': null,
    'evidence_note':
        '仅展示真实作答证据，不推断考试分数或精确掌握度。知识点使用每道题最近一次已评分作答，仅纳入已核对且未用提示的结果；少于3道题标为样本不足。',
    'topics': topics
        .map(
          (t) => {
            'name': t.name,
            'subject': t.subject,
            'distinct_questions': t.questions,
            'correct': t.correct,
            'sufficient_sample': t.questions >= 3,
          },
        )
        .toList(),
  };
}
