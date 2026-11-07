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
