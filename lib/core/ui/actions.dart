import 'package:material_ui/material_ui.dart';

import '../ai/chat_provider.dart';
import '../l10n/app_strings.dart';
import '../l10n/app_error_localization.dart';

Future<void> act(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (!context.mounted) return;
    final message = e is FormatException || e is AiFailure
        ? failureText(context.l10n, e)
        : context.l10n.couldNotCompleteTheAction;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
      title: Text(title),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: multiline ? 4 : 1,
          maxLines: multiline ? 12 : 1,
          decoration: InputDecoration(labelText: context.l10n.content),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: Text(context.l10n.confirmChoice),
        ),
      ],
    ),
  );
  // Dialog exit animation can still read its text controller.
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  return result;
}
