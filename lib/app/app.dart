import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_strings.dart';
import '../core/ui/actions.dart';
import '../features/chat/chat_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/library/library_screen.dart';
import '../features/library/study_detail_screen.dart';
import '../features/practice/practice_history_screen.dart';
import '../features/practice/practice_run_screen.dart';
import '../features/practice/practice_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/review/review_screen.dart';
import '../features/settings/prompt_screen.dart';
import '../features/settings/settings_screen.dart';
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
          GoRoute(path: '/review', builder: (_, _) => const ReviewScreen()),
          GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
          GoRoute(
            path: '/practice',
            builder: (_, _) => const PracticeScreen(),
            routes: [
              GoRoute(
                path: 'run',
                builder: (_, _) => const PracticeRunScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) => PracticeDetailScreen(
                  s.pathParameters['id']!,
                  attemptId: s.uri.queryParameters['attempt'],
                ),
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (_, s) =>
                        PracticeHistoryScreen(s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(path: '/chat', builder: (_, _) => const ChatScreen()),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'prompts',
                builder: (_, _) => const PromptScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) =>
                        PromptEditorScreen(state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/knowledge',
            builder: (_, _) => const LibraryScreen(isMistake: false),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => StudyDetailScreen(
                  id: state.pathParameters['id']!,
                  isMistake: false,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/mistakes',
            builder: (_, _) => const LibraryScreen(isMistake: true),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => StudyDetailScreen(
                  id: state.pathParameters['id']!,
                  isMistake: true,
                ),
              ),
            ],
          ),
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
  Widget build(BuildContext context, WidgetRef ref) => DynamicColorBuilder(
    builder: (lightDynamic, darkDynamic) => MaterialApp.router(
      title: '题训 TiXun',
      debugShowCheckedModeBanner: false,
      theme: appTheme(
        Brightness.light,
        scheme: ref.watch(appControllerProvider).dynamicColors
            ? lightDynamic
            : null,
      ),
      darkTheme: appTheme(
        Brightness.dark,
        scheme: ref.watch(appControllerProvider).dynamicColors
            ? darkDynamic
            : null,
      ),
      themeMode: ref.watch(appControllerProvider.select((c) => c.themeMode)),
      locale: ref.watch(appControllerProvider).appLocale,
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        AppStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      localeListResolutionCallback: (requested, supported) =>
          resolveAppLocale(requested ?? []),
      routerConfig: ref.watch(routerProvider),
    ),
  );
}

class AppShell extends ConsumerWidget {
  const AppShell({required this.path, required this.child, super.key});
  final String path;
  final Widget child;
  static const paths = [
    '/study',
    '/chat',
    '/mistakes',
    '/knowledge',
    '/settings',
  ];
  static const labels = ['学习', 'AI 对话', '错题', '知识', '设置'];
  static const icons = [
    Icons.space_dashboard_outlined,
    Icons.forum_outlined,
    Icons.menu_book_outlined,
    Icons.bookmarks_outlined,
    Icons.tune_outlined,
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final index = paths
        .indexWhere((p) => path == p || path.startsWith('$p/'))
        .clamp(0, 4);
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
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
            context.go('/mistakes'),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () =>
            context.go('/knowledge'),
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
                    context.tr("MOCK 体验 · 固定测试回复 · 与真实数据隔离"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                ),
              if (c.notice != null)
                MaterialBanner(
                  content: Text(context.tr(c.notice!)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        c.notice = null;
                        c.changed();
                      },
                      child: Text(context.tr("知道了")),
                    ),
                  ],
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
                                        context.tr("题训"),
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
                                  title: Text(context.tr(labels[i])),
                                  onTap: () => context.go(paths[i]),
                                ),
                              ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                context.tr("理解知识\n独立练习\n真正掌握"),
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
        bottomNavigationBar: wide || MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => context.go(paths[i]),
                destinations: [
                  for (var i = 0; i < paths.length; i++)
                    NavigationDestination(
                      key: Key('nav-$i'),
                      icon: Icon(icons[i]),
                      label: context.tr(labels[i]),
                    ),
                ],
              ),
      ),
    );
  }
}
