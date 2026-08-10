import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';

import 'app_router.dart';

/// Listens for incoming `iosforge://screen/<id>` deep links and routes to the
/// matching screen via the app's navigator, both on cold start and while the
/// app is already running.
class DeepLinkHandler {
  DeepLinkHandler(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Future<void> init() async {
    // Links that launched the app from cold.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _route(initial);
    } catch (_) {
      // Ignore — platform may not support initial link (e.g. web).
    }
    // Links delivered while running.
    _sub = _appLinks.uriLinkStream.listen(_route, onError: (_) {});
  }

  void _route(Uri uri) {
    final id = AppRouter.screenIdOf(uri.toString());
    if (id == null) return;
    navigatorKey.currentState?.pushNamed(uri.toString());
  }

  void dispose() => _sub?.cancel();
}
