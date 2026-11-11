import '../core/ui/app_menu.dart';
import '../features/settings/ai_settings_screen.dart';
import '../features/settings/python_settings.dart';
import '../features/settings/subjects_screen.dart';
import '../features/exams/exam_calendar.dart';
import '../features/exams/exam_detail.dart';
import '../features/exams/exam_subject_screen.dart';

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
import '../features/settings/chatgpt_screen.dart';
import '../features/settings/settings_screen.dart';
import 'controller.dart';
import 'theme.dart';

// Ink belongs to its route, not the shell's Scaffold below the Navigator.
// Otherwise an outgoing page can leave its splash on top of a pushed page.
GoRoute _materialRoute({
  required String path,
  required GoRouterWidgetBuilder builder,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  routes: routes,
  builder: (context, state) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: builder(context, state),
  ),
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: const String.fromEnvironment(
      'TIXUN_ROUTE',
      defaultValue: '/study',
    ),
    // Unknown paths (mistyped deep links, stale links) must not strand
    // the user on GoRouter's default error page, which sits outside the
    // ShellRoute: no bottom navigation and no in-app way back, so the
    // system back button would exit the app instead.
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: Text(context.tr('题训'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('页面不存在'),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(state.uri.path, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/study'),
                child: Text(context.tr('回学习页')),
              ),
            ],
          ),
        ),
      ),
    ),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(path: state.uri.path, child: child),
        routes: [
          _materialRoute(
            path: '/exams',
            builder: (_, _) => const ExamCalendarScreen(),
            routes: [
              _materialRoute(
                path: ':id',
                builder: (_, s) => ExamDetailScreen(s.pathParameters['id']!),
                routes: [
                  _materialRoute(
                    path: 'subject/:subjectId',
                    builder: (_, s) =>
                        ExamSubjectScreen(s.pathParameters['subjectId']!),
                  ),
                ],
              ),
            ],
          ),
          _materialRoute(
            path: '/study',
            builder: (_, _) => const DashboardScreen(),
          ),
          _materialRoute(
            path: '/review',
            builder: (_, _) => const ReviewScreen(),
          ),
          _materialRoute(
            path: '/progress',
            builder: (_, _) => const ProgressScreen(),
          ),
          _materialRoute(
            path: '/practice',
            builder: (_, _) => const PracticeScreen(),
            routes: [
              _materialRoute(
                path: 'run',
                builder: (_, _) => const PracticeRunScreen(),
              ),
              _materialRoute(
                path: ':id',
                builder: (_, s) => PracticeDetailScreen(
                  s.pathParameters['id']!,
                  attemptId: s.uri.queryParameters['attempt'],
                ),
                routes: [
                  _materialRoute(
                    path: 'history',
                    builder: (_, s) =>
                        PracticeHistoryScreen(s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          _materialRoute(path: '/chat', builder: (_, _) => const ChatScreen()),
          _materialRoute(
            path: '/settings',
            builder: (_, _) => const SettingsScreen(),
            routes: [
              _materialRoute(
                path: 'subjects',
                builder: (_, _) => const SubjectsScreen(),
              ),
              _materialRoute(
                path: 'ai',
                builder: (_, _) => const AiSettingsScreen(),
              ),
              _materialRoute(
                path: 'chatgpt',
                builder: (_, _) => const ChatGptScreen(),
              ),
              _materialRoute(
                path: 'python',
                builder: (_, _) => const PythonSettings(),
              ),
              _materialRoute(
                path: 'prompts',
                builder: (_, _) => const PromptScreen(),
                routes: [
                  _materialRoute(
                    path: ':id',
                    builder: (_, state) =>
                        PromptEditorScreen(state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          _materialRoute(
            path: '/knowledge',
            builder: (_, s) => LibraryScreen(
              isMistake: false,
              initialModule: s.uri.queryParameters['module'],
            ),
            routes: [
              _materialRoute(
                path: ':id',
                builder: (_, state) => StudyDetailScreen(
                  id: state.pathParameters['id']!,
                  isMistake: false,
                ),
              ),
            ],
          ),
          _materialRoute(
            path: '/mistakes',
            builder: (_, s) => LibraryScreen(
              isMistake: true,
              initialModule: s.uri.queryParameters['module'],
            ),
            routes: [
              _materialRoute(
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
        scheme: ref.watch(appControllerProvider.select((c) => c.dynamicColors))
            ? lightDynamic
            : null,
      ),
      darkTheme: appTheme(
        Brightness.dark,
        scheme: ref.watch(appControllerProvider.select((c) => c.dynamicColors))
            ? darkDynamic
            : null,
      ),
      themeMode: ref.watch(appControllerProvider.select((c) => c.themeMode)),
      locale: ref.watch(appControllerProvider.select((c) => c.appLocale)),
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

  /// Navigation index for [path], or -1 when the page is not in the
  /// navigation list (/review, /progress, /practice and their sub-routes).
  /// Callers must handle -1 (no highlight); NavigationBar asserts its
  /// selected index is in range, so it cannot receive this value.
  static int navIndexFor(String path) =>
      paths.indexWhere((p) => path == p || path.startsWith('$p/'));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    // Pages outside the navigation list (/review, /progress, /practice
    // and their sub-routes) intentionally highlight nothing: index stays
    // -1 instead of being clamped to 0, which used to highlight 学习.
    final index = navIndexFor(path);
    final c = ref.read(appControllerProvider);
    final shell = ref.watch(
      appControllerProvider.select(
        (c) => (
          demo: c.demo,
          notice: c.notice,
          subjectFilter: c.subjectFilter,
          subjects: c.learningSubjects,
        ),
      ),
    );
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
            context.go('/mistakes'),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
            context.go('/knowledge'),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () =>
            context.go('/settings'),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          c.stop();
        },
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (shell.demo)
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
              if (shell.notice != null)
                MaterialBanner(
                  content: Text(context.tr(shell.notice!)),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () {
                        c.notice = null;
                        c.changed();
                      },
                      child: Text(context.tr("知道了")),
                    ),
                  ],
                ),
              if (path == '/study')
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Semantics(
                              key: const Key('subject-switch'),
                              label: context.tr('切换科目'),
                              child: AppSelectField<String>(
                                initialValue: shell.subjectFilter,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.school_outlined,
                                    size: 19,
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: '',
                                    child: Text(context.tr('全部科目')),
                                  ),
                                  for (final subject in {
                                    ...shell.subjects,
                                    if (shell.subjectFilter.isNotEmpty)
                                      shell.subjectFilter,
                                  })
                                    DropdownMenuItem(
                                      value: subject,
                                      child: Text(
                                        context.subjectName(subject),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    // This switch only renders on /study,
                                    // so there is no chat page to activate
                                    // from here; setSubjectFilter's
                                    // activateChat branch has no production
                                    // caller left (see controller tests).
                                    act(
                                      context,
                                      () => c.setSubjectFilter(value),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                    Expanded(
                      child: path == '/chat' && !wide
                          ? PopScope(
                              canPop: context.canPop(),
                              onPopInvokedWithResult: (didPop, result) {
                                if (!didPop) context.go('/study');
                              },
                              child: child,
                            )
                          : child,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // The bottom bar is hidden on pages outside the navigation list
        // (/review, /progress, /practice): NavigationBar requires a
        // selected index in range, so there is no way to show it with
        // nothing highlighted; the side rail (wide layout) simply shows
        // no selected tile on those pages.
        bottomNavigationBar:
            wide ||
                path == '/chat' ||
                MediaQuery.viewInsetsOf(context).bottom > 0 ||
                index < 0
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) {
                  if (i == 1) {
                    context.push(paths[i]);
                  } else {
                    context.go(paths[i]);
                  }
                },
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
