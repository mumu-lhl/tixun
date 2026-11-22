const _languageSubjects = {
  "语文",
  "中文",
  "汉语",
  "普通话",
  "chinese",
  "mandarin",
  "外语",
  "英语",
  "英文",
  "english",
  "日语",
  "日文",
  "japanese",
  "法语",
  "french",
  "德语",
  "german",
  "西班牙语",
  "spanish",
  "俄语",
  "russian",
  "韩语",
  "朝鲜语",
  "korean",
  "阿拉伯语",
  "arabic",
  "意大利语",
  "italian",
  "葡萄牙语",
  "portuguese",
};

bool isLanguageLearningSubject(String subject) {
  final label = subject.trim().toLowerCase();
  final qualifier = RegExp(r"\s*[（(]").firstMatch(label);
  return _languageSubjects.contains(label) ||
      qualifier != null &&
          _languageSubjects.contains(label.substring(0, qualifier.start));
}
