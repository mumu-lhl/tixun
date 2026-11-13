import '../../core/ui/app_menu.dart';
import '../../core/l10n/app_strings.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/ui/actions.dart';

class LanguageColorSettings extends ConsumerWidget {
  const LanguageColorSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSelectField<String>(
          key: const Key('language-selector'),
          initialValue: c.languageChoice,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.language),
            labelText: context.l10n.interfaceLanguage,
          ),
          items: [
            DropdownMenuItem(value: 'zh', child: Text(context.l10n.chinese)),
            const DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(
              value: 'system',
              child: Text(context.l10n.followSystem),
            ),
          ],
          onChanged: (v) => act(context, () => c.setLanguage(v!)),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const Key('dynamic-colors'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.dynamicColors),
          subtitle: Text(context.l10n.useTheWallpaperOrDesktop),
          value: c.dynamicColors,
          onChanged: (value) => act(context, () => c.setDynamicColors(value)),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
