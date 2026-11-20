part of "study_store.dart";

const schoolSubjects = ["数学", "物理", "化学", "语文", "英语", "地理", "生物", "历史", "政治"];
const knowledgeKinds = [
  "通用文章",
  "概念",
  "定义",
  "公式",
  "定理",
  "原理",
  "解题方法",
  "解题技巧",
  "易错点",
  "例题",
  "个人笔记",
];
const mistakeReasons = [
  "知识不理解",
  "公式记忆错误",
  "方法选择错误",
  "推理或计算错误",
  "审题错误",
  "遗漏条件",
  "粗心失误",
  "时间不足",
  "暂未确定",
];

class StudyConflict extends FormatException {
  const StudyConflict() : super("这条资料已在其他操作中更新，请重新打开后编辑，避免覆盖新内容。");
}

class KnowledgeDraft {
  const KnowledgeDraft({
    required this.title,
    required this.content,
    this.subject = "数学",
    this.kind = "个人笔记",
    this.chapter = "",
    this.tags = const [],
  });
  final String title, content, subject, kind, chapter;
  final List<String> tags;
}

class MistakeDraft {
  const MistakeDraft({
    required this.title,
    this.question = "",
    this.subject = "数学",
    this.chapter = "",
    this.correctAnswer = "",
    this.originalAnswer = "",
    this.ownAnalysis = "",
    this.aiAnalysis = "",
    this.errorReason = "暂未确定",
    this.suggestedReason = "",
    this.tags = const [],
  });
  final String title,
      question,
      subject,
      chapter,
      correctAnswer,
      originalAnswer,
      ownAnalysis,
      aiAnalysis,
      errorReason,
      suggestedReason;
  final List<String> tags;
}

class KnowledgeDetail {
  const KnowledgeDetail(
    this.item,
    this.tags,
    this.images,
    this.related,
    this.mistakes,
  );
  final KnowledgeItem item;
  final List<String> tags;
  final List<StudyAttachment> images;
  final List<KnowledgeItem> related;
  final List<Mistake> mistakes;
}

class MistakeDetail {
  const MistakeDetail(this.item, this.tags, this.images, this.knowledge);
  final Mistake item;
  final List<String> tags;
  final List<StudyAttachment> images;
  final List<KnowledgeItem> knowledge;
}
