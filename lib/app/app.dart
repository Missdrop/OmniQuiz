// Composes providers, localized navigation and practice lifecycle; repositories own persistence.

import '../l10n/localization.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../presentation/library/library_page.dart';
import '../presentation/library/library_view_model.dart';
import '../presentation/practice/practice_page.dart';
import '../presentation/practice/practice_view_model.dart';
import '../presentation/practice/guidance_view_model.dart';
import '../presentation/review/review_page.dart';
import '../presentation/review/review_view_model.dart';
import '../presentation/settings/settings_page.dart';
import '../presentation/settings/settings_view_model.dart';
import 'dependencies.dart';
import 'theme.dart';
import '../infrastructure/platform/window_title.dart';
import '../presentation/settings/language_view_model.dart';
import '../presentation/settings/appearance_view_model.dart';
import '../presentation/settings/question_language_view_model.dart';
import '../presentation/updates/update_controller.dart';
import '../presentation/updates/update_panel.dart';

/// Localized application shell for a single library dependency graph.
class OmniQuizApp extends StatefulWidget {
  const OmniQuizApp({
    super.key,
    required this.dependencies,
    this.libraryControls,
    this.settingsControls,
    this.currentLibraryName,
    this.updates,
    this.hasLibrary = true,
  });
  final AppDependencies dependencies;
  final Widget? libraryControls;
  final Widget? settingsControls;
  final String? currentLibraryName;
  final UpdateController? updates;
  final bool hasLibrary;
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
            GoRoute(
              path: '/library',
              builder: (_, _) => LibraryPage(
                controls: widget.libraryControls,
                hasLibrary: widget.hasLibrary,
                unavailable:
                    !widget.hasLibrary && widget.currentLibraryName != null,
              ),
            ),
            GoRoute(
              path: '/practice',
              builder: (_, _) => PracticePage(hasLibrary: widget.hasLibrary),
            ),
            GoRoute(path: '/review', builder: (_, _) => const ReviewPage()),
            GoRoute(
              path: '/settings',
              builder: (_, _) => SettingsPage(
                controls: widget.settingsControls,
                updates: widget.updates,
              ),
            ),
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
    // Backgrounding pauses transport, while leaving Practice ends user intent.
    // Keeping these distinct permits safe foreground resume without surprise calls.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(widget.dependencies.practice.suspendPractice());
    } else if (state == AppLifecycleState.resumed && _lastPath == '/practice') {
      unawaited(widget.dependencies.practice.resumePractice());
    }
  }

  String _lastPath = '/library';

  void _routeChanged() {
    final path = _router.routeInformationProvider.value.uri.path;
    if (path == _lastPath) return;
    if (_lastPath == '/settings') widget.dependencies.settings.dismissMessage();
    _lastPath = path;
    if (path != '/practice') {
      unawaited(widget.dependencies.practice.endPractice());
    }
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
    final labels = [
      context.l10n.library,
      context.l10n.practice,
      context.l10n.review,
      context.l10n.settings,
    ];
    return UpdateNoticeHost(
      controller: widget.updates,
      child: Scaffold(
        appBar: wide
            ? null
            : AppBar(
                title: Row(
                  children: [
                    Image.asset(
                      'assets/branding/logo.png',
                      width: 36,
                      height: 36,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.l10n.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                actions: const [_ThemeToggle()],
                centerTitle: false,
              ),
        body: SafeArea(
          child: Row(
            children: [
              if (wide)
                _DesktopNavigation(
                  labels: labels,
                  icons: icons,
                  selected: selected,
                  onSelected: _navigate,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.currentLibraryName != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Text(
                          widget.currentLibraryName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider<GuidanceViewModel>.value(
        value: widget.dependencies.guidance,
      ),
      ChangeNotifierProvider<QuestionLanguageViewModel>.value(
        value: widget.dependencies.questionLanguage,
      ),
      ChangeNotifierProvider<AppearanceViewModel>.value(
        value: widget.dependencies.appearance,
      ),
      ChangeNotifierProvider<LanguageViewModel>.value(
        value: widget.dependencies.language,
      ),
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
    child: Consumer2<LanguageViewModel, AppearanceViewModel>(
      builder: (context, language, appearance, _) => MaterialApp.router(
        locale: language.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateTitle: (context) {
          // Localizations are available here; the Windows HWND needs its own bridge.
          final title = context.l10n.appName;
          unawaited(DesktopWindowTitle.update(title));
          return title;
        },
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        darkTheme: buildTheme(brightness: Brightness.dark),
        themeMode: appearance.mode,
        routerConfig: _router,
      ),
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

/// Desktop navigation stays anchored while the content scrolls independently.
class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.labels,
    required this.icons,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final List<IconData> icons;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 232,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : scheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: scheme.outlineVariant.withValues(alpha: .4)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 30, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/branding/logo.png',
                        width: 36,
                        height: 36,
                        excludeFromSemantics: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.l10n.appName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.tagline,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          selected: selected == i,
                          selectedTileColor: scheme.primary.withValues(
                            alpha: .1,
                          ),
                          selectedColor: scheme.primary,
                          iconColor: scheme.onSurfaceVariant,
                          minLeadingWidth: 22,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                          leading: Icon(icons[i], size: 22),
                          title: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected == i
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: selected == i
                              ? Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                          onTap: () => onSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
              child: Column(
                children: [const Divider(), const _ThemeToggle(expanded: true)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({this.expanded = false});
  final bool expanded;
  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceViewModel>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final toggle = appearance.saving
        ? null
        : () => appearance.select(dark ? ThemeMode.light : ThemeMode.dark);
    final icon = dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined;
    if (expanded) {
      return Tooltip(
        message: dark ? context.l10n.switchToLight : context.l10n.switchToDark,
        child: ListTile(
          key: const ValueKey('appearance-toggle-row'),
          enabled: !appearance.saving,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          minLeadingWidth: 22,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          leading: Icon(icon, size: 22),
          title: Text(
            context.l10n.appearance,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          onTap: toggle,
        ),
      );
    }
    return IconButton(
      tooltip: dark ? context.l10n.switchToLight : context.l10n.switchToDark,
      icon: Icon(icon),
      onPressed: toggle,
    );
  }
}
