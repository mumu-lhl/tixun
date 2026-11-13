import 'package:tixun/core/l10n/app_error.dart';

class PracticeRun {
  const PracticeRun(this.ids, this.attempts, this.index);
  final List<String> ids;
  final List<String?> attempts;
  final int index;
  bool get completed => index == ids.length;
  Map<String, dynamic> toJson() => {
    'ids': ids,
    'attempts': attempts,
    'index': index,
  };
  factory PracticeRun.fromJson(Map<String, dynamic> a) {
    final ids = a['ids'], attempts = a['attempts'], index = a['index'];
    if (ids is! List ||
        ids.isEmpty ||
        ids.length > 20 ||
        ids.any(
          (v) => v is! String || v.isEmpty || v.length > 200 || v.contains('|'),
        ) ||
        ids.toSet().length != ids.length ||
        attempts is! List ||
        attempts.length != ids.length ||
        attempts.any(
          (v) =>
              v != null &&
              (v is! String || v.isEmpty || v.length > 200 || v.contains('|')),
        ) ||
        index is! int ||
        index < 0 ||
        index > ids.length) {
      throw const AppFormatException(
        AppErrorCode.errorTheQuizRecoveryStateIsInvalid,
        '小测恢复状态无效，可结束本轮后重新开始；已有作答仍保留。',
      );
    }
    return PracticeRun(ids.cast<String>(), attempts.cast<String?>(), index);
  }
}
