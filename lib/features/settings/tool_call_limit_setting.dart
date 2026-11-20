import "package:material_ui/material_ui.dart";

import "../../app/controller.dart";
import "../../core/l10n/app_error.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";

Future<void> editToolCallLimit(
  BuildContext context,
  AppController controller,
) => act(context, () async {
  final value = await editText(
    context,
    title: context.l10n.maxToolCalls,
    helperText: context.l10n.maxToolCallsHelp,
    keyboardType: TextInputType.number,
    initial: controller.maxToolCalls.toString(),
  );
  if (value == null) return;
  final limit = int.tryParse(value);
  if (limit == null || limit < 0) {
    throw const AppFormatException(
      AppErrorCode.invalidToolCallLimit,
      "请输入非负整数；0 表示不限制工具调用次数。",
    );
  }
  await controller.setMaxToolCalls(limit);
});
