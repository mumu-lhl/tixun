import 'package:material_ui/material_ui.dart';
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
  bool loadError = false;
  bool saving = false;
  int selection = 0;
  @override
  void initState() {
    super.initState();
    ref
        .read(appControllerProvider)
        .db
        .preference(pythonPolicyKey)
        .then((v) {
          if (mounted) {
            setState(
              () => policy = ['ask', 'auto', 'off'].contains(v) ? v : 'ask',
            );
          }
        })
        .onError((error, stack) {
          if (mounted) setState(() => loadError = true);
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
          title: Text(ctx.l10n.automaticallyAllowArbitraryPythonCode),
          content: Text(ctx.l10n.pythonHasTheSameFile),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              key: const Key('confirm-python-auto'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.allowAutomaticallyAnyway),
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
    appBar: AppBar(title: Text(context.l10n.pythonExecution)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(context.l10n.aiPythonCapabilities),
            const SizedBox(height: 20),
            if (loadError)
              Text(
                context.l10n.couldNotLoadExecutionPermissions,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (policy == null)
              const LinearProgressIndicator()
            else
              SizedBox(
                key: const Key('python-policy'),
                child: AppSelectField<String>(
                  key: ValueKey('$policy-$selection'),
                  initialValue: policy,
                  decoration: InputDecoration(
                    labelText: context.l10n.executionPermission,
                  ),
                  items: [
                    for (final pair in [
                      ('off', context.l10n.close),
                      ('ask', context.l10n.reviewEveryScript),
                      ('auto', context.l10n.automaticallyAllowArbitraryCode),
                    ])
                      DropdownMenuItem(value: pair.$1, child: Text(pair.$2)),
                  ],
                  onChanged: saving
                      ? null
                      : (v) => act(context, () => change(v)),
                ),
              ),
            const SizedBox(height: 20),
            Text(context.l10n.thisIsNotASecurity),
          ],
        ),
      ),
    ),
  );
}
