import '../features/timeline/timeline_screen.dart';
import '../features/settings/ai_settings_screen.dart';
import '../features/settings/ai_usage_screen.dart';
import '../features/settings/python_settings.dart';
import '../features/settings/subjects_screen.dart';
import '../features/exams/exam_calendar.dart';
import '../features/exams/exam_detail.dart';
import '../features/exams/exam_subject_screen.dart';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_strings.dart';
import '../core/l10n/generated/app_localizations.dart';
import '../core/ui/actions.dart';
import '../features/chat/chat_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/language_learning/language_screen.dart';
import '../features/language_learning/quick_lookup/quick_screen.dart';
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
import 'main_navigation_page.dart';
import 'theme.dart';

part 'app_routes.dart';

class TixunApp extends ConsumerWidget {
  const TixunApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DynamicColorBuilder(
    builder: (lightDynamic, darkDynamic) => MaterialApp.router(
      // Keep legacy package widgets themed and localized during their migration.
      builder: (context, child) =>
          // ignore: deprecated_member_use
          MaterialUiCompatibilityBridge(child: child!),
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
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
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

  Future<void> _openSubjectChat(
    BuildContext context,
    AppController controller, {
    bool push = false,
    Object? extra,
  }) async {
    await controller.prepareSubjectChat();
    // A slow history load must not navigate over a later destination tap.
    if (!context.mounted || GoRouter.of(context).state.uri.path != path) return;
    if (push) {
      context.push('/chat', extra: extra);
    } else {
      context.go('/chat', extra: extra);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    // Pages outside the navigation list (/review, /progress, /practice
    // and their sub-routes) intentionally highlight nothing: index stays
    // -1 instead of being clamped to 0, which used to highlight 学习.
    final index = navIndexFor(path);
    final c = ref.read(appControllerProvider);
    final shell = ref.watch(
      appControllerProvider.select((c) => (demo: c.demo, notice: c.notice)),
    );
    final colors = Theme.of(context).colorScheme;
    final labels = [
      context.l10n.study,
      context.l10n.aiChat,
      context.l10n.mistakeQuestions,
      context.l10n.knowledge,
      context.l10n.settings,
    ];
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
            act(context, () => _openSubjectChat(context, c)),
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
                    context.l10n.mockFixedTestResponsesIsolated,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                ),
              if (shell.notice != null)
                MaterialBanner(
                  content: Text(shell.notice!.text(context.l10n)),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () {
                        c.notice = null;
                        c.changed();
                      },
                      child: Text(context.l10n.gotIt),
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
                                        context.l10n.tiXun,
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
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  minTileHeight: 56,
                                  minVerticalPadding: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  selected: i == index,
                                  selectedTileColor: colors.primaryContainer
                                      .withValues(alpha: .65),
                                  leading: Icon(icons[i], size: 22),
                                  title: Text(labels[i]),
                                  onTap: i == 1
                                      ? () => act(
                                          context,
                                          () => _openSubjectChat(context, c),
                                        )
                                      : () => context.go(paths[i]),
                                ),
                              ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                context
                                    .l10n
                                    .understandKnowledgePracticeIndependentlyBuild,
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
        bottomNavigationBar: wide
            ? null
            : AnimatedSwitcher(
                key: const Key('bottom-navigation-transition'),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child:
                    path == '/chat' ||
                        MediaQuery.viewInsetsOf(context).bottom > 0 ||
                        index < 0
                    ? const SizedBox.shrink(
                        key: ValueKey('hidden-navigation-bar'),
                      )
                    : NavigationBar(
                        key: const ValueKey('main-navigation-bar'),
                        selectedIndex: index,
                        onDestinationSelected: (i) {
                          if (i == index) return;
                          final motion = _MainNavigationMotion(index, i);
                          if (i == 1) {
                            act(
                              context,
                              () => _openSubjectChat(
                                context,
                                c,
                                push: true,
                                extra: motion,
                              ),
                            );
                          } else {
                            context.go(paths[i], extra: motion);
                          }
                        },
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
      ),
    );
  }
}
