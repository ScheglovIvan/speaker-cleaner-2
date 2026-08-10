import 'package:flutter/material.dart';

import '../../features/onboarding/launch_gate.dart';
import 'app_shell.dart';
import 'screen_registry.dart';

/// Central routing for the app.
///
/// Resolves three stable, parallel-safe route forms to the SAME screen widget
/// for every id in app_spec.json:
///  * `/<id>`                    — direct in-app route
///  * `/screen/:id`              — canonical web-preview route (`/#/screen/<id>`)
///  * `iosforge://screen/<id>`   — deep link (Android intent-filter + app_links)
///
/// These names MUST NOT be renamed or removed (a nav audit depends on them).
class AppRouter {
  AppRouter._();

  static const String initialRoute = '/';

  /// Ids that live inside the bottom-tab shell (Test Hub/Channels/Tones/Level).
  static const List<String> tabIds = AppShell.tabIds;

  /// Optional spec `route` string -> screen id, so the app_spec named routes
  /// (`/paywall`, `/settings`, ...) also resolve. Not required by the audit,
  /// but keeps every navigation edge robust.
  static const Map<String, String> _namedRouteToId = {
    '/splash': '0000',
    '/paywall': '0001',
    '/stereo': '0002',
    '/channels': '0002',
    '/settings': '0003',
    '/settings/language': '0004',
    '/loading': '0005',
    '/plan': '0006',
    '/plan/day': '0007',
    '/clean/instructions': '0008',
    '/plan/list': '0010',
    '/maintenance': '0010',
    '/modes': '0012',
    '/tones': '0012',
    '/db-meter': '0013',
  };

  /// Parse any supported route name into a screen id, or `null`.
  static String? screenIdOf(String? name) {
    if (name == null || name.isEmpty) return null;
    if (name == '/') return ScreenRegistry.homeId;

    final uri = Uri.tryParse(name);
    if (uri != null) {
      // iosforge://screen/<id>
      if (uri.scheme == 'iosforge') {
        final segs = <String>[uri.host, ...uri.pathSegments]
            .where((s) => s.isNotEmpty)
            .toList();
        if (segs.length >= 2 && segs[0] == 'screen') return _valid(segs[1]);
        if (segs.length == 1) return _valid(segs[0]);
      }
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      // /screen/<id>
      if (segs.length >= 2 && segs[0] == 'screen') return _valid(segs[1]);
      // /<id>
      if (segs.length == 1) return _valid(segs[0]);
    }

    // Named spec route fallback (compare on the path only).
    final path = uri?.path ?? name;
    final mapped = _namedRouteToId[path];
    if (mapped != null) return mapped;

    return null;
  }

  static String? _valid(String id) => ScreenRegistry.has(id) ? id : null;

  static bool _isTab(String id) => tabIds.contains(id);

  /// True when the route is the canonical `/screen/:id` preview form, which
  /// must render the screen STANDALONE (no tab shell) for headless verification.
  static bool _isPreview(String name) {
    final uri = Uri.tryParse(name);
    final segs = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ??
        const <String>[];
    return segs.isNotEmpty && segs[0] == 'screen';
  }

  /// `onGenerateRoute` entry point.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '/';
    final id = screenIdOf(name);
    final preview = _isPreview(name);

    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (context) {
        // The initial `/` route runs the launch gate: first-launch onboarding,
        // otherwise the tab shell. Deep links / previews resolve directly below.
        if (name == '/') return const LaunchGate();
        if (id == null) return const AppShell();
        // Tab members open inside the shell (unless explicitly previewed).
        if (!preview && _isTab(id)) return AppShell(initialId: id);
        // Everything else (and all /screen/:id previews) renders standalone.
        return ScreenRegistry.build(context, id) ?? const AppShell();
      },
    );
  }
}
