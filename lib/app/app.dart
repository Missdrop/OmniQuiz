import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../presentation/library/library_page.dart';
import '../presentation/library/library_view_model.dart';
import '../presentation/practice/practice_page.dart';
import '../presentation/practice/practice_view_model.dart';
import '../presentation/review/review_page.dart';
import '../presentation/review/review_view_model.dart';
import '../presentation/settings/settings_page.dart';
import '../presentation/settings/settings_view_model.dart';
import 'dependencies.dart';
import 'theme.dart';

class OmniQuizApp extends StatefulWidget {
  const OmniQuizApp({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<OmniQuizApp> createState() => _OmniQuizAppState();
}

class _OmniQuizAppState extends State<OmniQuizApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  static const _paths = ['/library', '/practice', '/review', '/settings'];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = GoRouter(
      initialLocation: '/library',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              _shell(context, state.uri.path, child),
          routes: [
            GoRoute(path: '/library', builder: (_, _) => const LibraryPage()),
            GoRoute(path: '/practice', builder: (_, _) => const PracticePage()),
            GoRoute(path: '/review', builder: (_, _) => const ReviewPage()),
            GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          ],
        ),
      ],
    );
    _router.routeInformationProvider.addListener(_routeChanged);
    unawaited(widget.dependencies.library.refresh());
    unawaited(widget.dependencies.practice.refresh());
    unawaited(widget.dependencies.review.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.dependencies.coordinator.stop());
    }
  }

  String _lastPath = '/library';

  void _routeChanged() {
    final path = _router.routeInformationProvider.value.uri.path;
    if (path == _lastPath) return;
    _lastPath = path;
    if (path != '/practice') unawaited(widget.dependencies.coordinator.stop());
    unawaited(widget.dependencies.library.refresh());
    unawaited(widget.dependencies.practice.refresh());
    unawaited(widget.dependencies.review.refresh());
  }

  void _navigate(int index) => _router.go(_paths[index]);

  Widget _shell(BuildContext context, String path, Widget child) {
    final selected = _paths.indexOf(path).clamp(0, 3);
    final wide = MediaQuery.sizeOf(context).width >= 850;
    const icons = [
      Icons.auto_stories_outlined,
      Icons.play_circle_outline,
      Icons.history_rounded,
      Icons.tune_rounded,
    ];
    const labels = ['Library', 'Practice', 'Review', 'Settings'];
    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: const Text(
                'OmniQuiz',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              centerTitle: false,
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              SizedBox(
                width: 220,
                child: Material(
                  color: const Color(0xFFEDF1E8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 36, 24, 4),
                        child: Row(
                          children: [
                            Icon(Icons.spa, color: Color(0xFF245C46)),
                            SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'OmniQuiz',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 4, 24, 32),
                        child: Text(
                          'Make knowledge yours.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                      for (var i = 0; i < labels.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: ListTile(
                            selected: selected == i,
                            selectedTileColor: const Color(0xFFDDE8D7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Icon(icons[i]),
                            title: Text(labels[i]),
                            onTap: () => _navigate(i),
                          ),
                        ),
                      const Spacer(),
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 16),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Local by design',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: _navigate,
              destinations: List.generate(
                4,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: labels[i],
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider<LibraryViewModel>.value(
        value: widget.dependencies.library,
      ),
      ChangeNotifierProvider<PracticeViewModel>.value(
        value: widget.dependencies.practice,
      ),
      ChangeNotifierProvider<ReviewViewModel>.value(
        value: widget.dependencies.review,
      ),
      ChangeNotifierProvider<SettingsViewModel>.value(
        value: widget.dependencies.settings,
      ),
    ],
    child: MaterialApp.router(
      title: 'OmniQuiz',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.routeInformationProvider.removeListener(_routeChanged);
    _router.dispose();
    super.dispose();
  }
}
