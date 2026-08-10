import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'screen_registry.dart';
import 'tab_visibility.dart';

/// The persistent bottom-tab shell (Test Hub / Channels / Tones / Level).
///
/// Presentation may diverge ~20% from the source, but reachability is fixed:
/// every tab id still resolves to its screen. Screens keep their own AppBars,
/// so the shell only supplies the bottom navigation + the active body.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialId});

  /// Optional screen id to open on first build (e.g. deep-linked tab).
  final String? initialId;

  /// Tab order is test-first: Test Hub, Channel Test, Tone Generator, Level.
  static const List<String> tabIds = ['0011', '0002', '0012', '0013'];

  /// Switch the enclosing shell to the tab hosting [id]. Returns false when the
  /// caller is not inside a shell (standalone `/screen/<id>` preview) or [id] is
  /// not a tab, so the caller can fall back to a normal push.
  static bool openTab(BuildContext context, String id) {
    final index = tabIds.indexOf(id);
    if (index < 0) return false;
    final shell = context.findAncestorStateOfType<_AppShellState>();
    if (shell == null) return false;
    shell._select(index);
    return true;
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index;

  /// One visibility flag per tab, published to the tab's subtree via
  /// [TabVisibility]. `IndexedStack` keeps a hidden tab alive (so its state
  /// survives), which means a screen can only learn it went off-screen from
  /// this signal — `dispose()` never runs on a tab switch. Screens that play
  /// audio use it to stop playback the instant they stop being visible.
  late final List<ValueNotifier<bool>> _tabVisibility;

  // Icons are fixed; labels are localized per-build (re-localizes with the app
  // language, matching Settings ▸ App language).
  static const _destinations = <_TabDest>[
    _TabDest('nav_tests', Icons.fact_check_outlined),
    _TabDest('nav_channels', Icons.headphones_rounded),
    _TabDest('nav_tones', Icons.graphic_eq_rounded),
    _TabDest('nav_level', Icons.speed_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final i = AppShell.tabIds.indexOf(widget.initialId ?? '');
    _index = i >= 0 ? i : 0;
    _tabVisibility = [
      for (var t = 0; t < AppShell.tabIds.length; t++)
        ValueNotifier<bool>(t == _index),
    ];
  }

  @override
  void dispose() {
    for (final n in _tabVisibility) {
      n.dispose();
    }
    super.dispose();
  }

  /// Switch tabs and publish the new visibility so the tab being left can stop
  /// anything it is playing.
  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    for (var t = 0; t < _tabVisibility.length; t++) {
      _tabVisibility[t].value = t == i;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: [
          for (var t = 0; t < AppShell.tabIds.length; t++)
            TabVisibility(
              isVisible: _tabVisibility[t],
              child: ScreenRegistry.build(context, AppShell.tabIds[t]) ??
                  const SizedBox.shrink(),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.icon, color: AppColors.primary),
              label: l.t(d.label),
            ),
        ],
      ),
    );
  }
}

class _TabDest {
  const _TabDest(this.label, this.icon);
  final String label;
  final IconData icon;
}
