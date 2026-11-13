import 'package:material_ui/material_ui.dart';

import '../ai/chat_provider.dart';
import '../l10n/app_strings.dart';

Future<void> act(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (!context.mounted) return;
    final message = e is FormatException
        ? e.message
        : e is AiFailure
        ? e.message
        : '操作失败，请检查存储空间或系统密钥环后重试。';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr(message))));
  }
}

Future<String?> editText(
  BuildContext context, {
  required String title,
  String initial = '',
  bool multiline = false,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr(title)),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: multiline ? 4 : 1,
          maxLines: multiline ? 12 : 1,
          decoration: InputDecoration(labelText: context.tr("内容")),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr("取消")),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: Text(context.tr("确定")),
        ),
      ],
    ),
  );
  // Dialog exit animation can still read its text controller.
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  return result;
}
