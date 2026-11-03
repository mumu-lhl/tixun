import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/chat_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/settings/settings_screen.dart';
import '../core/ui/actions.dart';
import 'controller.dart';
import 'theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: const String.fromEnvironment(
      'TIXUN_ROUTE',
      defaultValue: '/study',
    ),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/study', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/chat', builder: (_, _) => const ChatScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class TixunApp extends ConsumerWidget {
  const TixunApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: '题训 TiXun',
    debugShowCheckedModeBanner: false,
    theme: appTheme(Brightness.light),
    darkTheme: appTheme(Brightness.dark),
    themeMode: ref.watch(appControllerProvider.select((c) => c.themeMode)),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: ref.watch(routerProvider),
  );
}

class AppShell extends ConsumerWidget {
  const AppShell({required this.path, required this.child, super.key});
  final String path;
  final Widget child;
  static const paths = ['/study', '/chat', '/settings'];
  static const labels = ['学习', 'AI 对话', '设置'];
  static const icons = [
    Icons.space_dashboard_outlined,
    Icons.forum_outlined,
    Icons.tune_outlined,
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final index = paths.indexOf(path).clamp(0, 2);
    final c = ref.watch(appControllerProvider);
    final colors = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            act(context, () async {
              await c.newSession();
              if (context.mounted) context.go('/chat');
            }),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            context.go('/study'),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            context.go('/chat'),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
            context.go('/settings'),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          c.stop();
        },
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (c.demo)
                Container(
                  width: double.infinity,
                  color: colors.tertiaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: Text(
                    'MOCK 体验 · 固定测试回复 · 与真实数据隔离',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                ),
              Expanded(
                child: Row(
                  children: [
                    if (wide) ...[
                      SizedBox(
                        width: 202,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                28,
                                20,
                                38,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.school_outlined,
                                      color: colors.onPrimary,
                                      size: 23,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '题训',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      Text(
                                        'TiXun',
                                        style: TextStyle(
                                          fontSize: 11,
                                          letterSpacing: 2,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            for (var i = 0; i < paths.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                child: ListTile(
                                  key: Key('nav-$i'),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  selected: i == index,
                                  selectedTileColor: colors.primaryContainer
                                      .withValues(alpha: .65),
                                  leading: Icon(icons[i], size: 22),
                                  title: Text(labels[i]),
                                  onTap: () => context.go(paths[i]),
                                ),
                              ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '理解知识\n独立练习\n真正掌握',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 2,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                    ],
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => context.go(paths[i]),
                destinations: [
                  for (var i = 0; i < paths.length; i++)
                    NavigationDestination(
                      key: Key('nav-$i'),
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                ],
              ),
      ),
    );
  }
}
