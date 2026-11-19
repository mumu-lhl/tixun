part of 'app.dart';

class _MainNavigationMotion {
  const _MainNavigationMotion(this.from, this.to);
  final int from;
  final int to;
}

// Ink belongs to its route, not the shell's Scaffold below the Navigator.
// Otherwise an outgoing page can leave its splash on top of a pushed page.
GoRoute _materialRoute({
  required String path,
  required GoRouterWidgetBuilder builder,
  List<RouteBase> routes = const [],
}) {
  final mainIndex = AppShell.paths.indexOf(path);
  Widget content(BuildContext context, GoRouterState state) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: builder(context, state),
  );
  return GoRoute(
    path: path,
    routes: routes,
    builder: mainIndex < 0 ? content : null,
    pageBuilder: mainIndex < 0
        ? null
        : (context, state) {
            final motion = state.extra;
            return MainNavigationPage(
              key: state.pageKey,
              direction:
                  motion is _MainNavigationMotion &&
                      motion.from >= 0 &&
                      motion.to == mainIndex
                  ? motion.to.compareTo(motion.from)
                  : 0,
              child: content(context, state),
            );
          },
  );
}

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
      appBar: AppBar(title: Text(context.l10n.tiXun)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.pageNotFound,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(state.uri.path, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/study'),
                child: Text(context.l10n.returnToStudyPage),
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
            path: '/timeline',
            builder: (_, _) => const TimelineScreen(),
          ),
          _materialRoute(
            path: '/language',
            builder: (_, _) => const LanguageLearningScreen(),
          ),
          _materialRoute(
            path: '/language/quick',
            builder: (_, _) => const QuickLookupScreen(),
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
                path: 'ai-usage',
                builder: (_, _) => const AiUsageScreen(),
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
