import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/python/python_tool.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/app_menu.dart';

class PythonSettings extends ConsumerStatefulWidget {
  const PythonSettings({super.key});
  @override
  ConsumerState<PythonSettings> createState() => _PythonSettingsState();
}

class _PythonSettingsState extends ConsumerState<PythonSettings> {
  String? policy;
  bool saving = false;
  int selection = 0;
  @override
  void initState() {
    super.initState();
    ref.read(appControllerProvider).db.preference(pythonPolicyKey).then((v) {
      if (mounted) {
        setState(() => policy = ['ask', 'auto', 'off'].contains(v) ? v : 'ask');
      }
    });
  }

  Future<void> change(String? next) async {
    if (next == null || next == policy) return;
    // Show the saved permission until confirmation and persistence succeed.
    setState(() => selection++);
    if (next == 'auto') {
      final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('自动允许运行任意 Python 代码？')),
          content: Text(
            ctx.tr(
              'Python 与题训拥有相同的文件和网络权限，代码可能读取、修改或删除本地资料，或导致应用退出。自动允许将跳过代码审查；这些操作无法保证撤销。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('取消')),
            ),
            FilledButton(
              key: const Key('confirm-python-auto'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('仍然自动允许')),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    setState(() => saving = true);
    try {
      await ref
          .read(appControllerProvider)
          .db
          .setPreference(pythonPolicyKey, next);
      if (mounted) setState(() => policy = next);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Python 执行'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          context.tr(
            'AI 可以编写完整 Python 代码，在本机计算、验证答案或生成文件。已打包标准库、SymPy 和 mpmath，不需要 Termux。执行输出会发送给当前模型以继续回答。',
          ),
        ),
        const SizedBox(height: 20),
        if (policy == null)
          const LinearProgressIndicator()
        else
          SizedBox(
            key: const Key('python-policy'),
            child: AppSelectField<String>(
              key: ValueKey('$policy-$selection'),
              initialValue: policy,
              decoration: InputDecoration(labelText: context.tr('执行权限')),
              items: [
                for (final pair in [
                  ('off', '关闭'),
                  ('ask', '每次审查代码'),
                  ('auto', '自动允许任意代码'),
                ])
                  DropdownMenuItem(
                    value: pair.$1,
                    child: Text(context.tr(pair.$2)),
                  ),
              ],
              onChanged: saving ? null : (v) => act(context, () => change(v)),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          context.tr(
            '这不是安全沙箱。停止会请求中断 Python；阻塞的原生计算或 I/O 可能需要等待，必要时重启应用。工作目录生成的文件不自动加入学习资料或备份。',
          ),
        ),
      ],
    ),
  );
}
