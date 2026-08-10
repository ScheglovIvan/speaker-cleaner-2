import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../router/tab_visibility.dart';

/// Ties screen-owned playback to the screen actually being *visible*.
///
/// The tab shell holds every tab in an `IndexedStack`, so switching tabs merely
/// hides a screen: its `dispose()` never runs and a player left running keeps
/// sounding from behind another tab. This mixin listens to the shell's per-tab
/// [TabVisibility] signal *and* to the app lifecycle, and calls
/// [onScreenHidden] the moment the screen stops being the visible tab or the
/// app leaves the foreground. [onScreenVisible] fires on the way back (no-op by
/// default — a screen only resumes if that is the right behaviour for it).
///
/// Used with `WidgetsBindingObserver`:
/// `class _FooState extends State<Foo> with WidgetsBindingObserver, AudioVisibilityGuard<Foo>`
mixin AudioVisibilityGuard<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  ValueListenable<bool>? _tabVisible;

  /// Stop whatever this screen is playing — the screen just became hidden.
  void onScreenHidden();

  /// The screen became visible again. Default: do nothing (playback stays
  /// stopped until the user asks for it again).
  void onScreenVisible() {}

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final signal = TabVisibility.maybeOf(context);
    if (identical(signal, _tabVisible)) return;
    _tabVisible?.removeListener(_onTabVisibilityChanged);
    _tabVisible = signal;
    _tabVisible?.addListener(_onTabVisibilityChanged);
  }

  void _onTabVisibilityChanged() {
    if (_tabVisible?.value == true) {
      onScreenVisible();
    } else {
      onScreenHidden();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Backgrounded (or covered by the app switcher) — silence the tone. A
    // transient `inactive` (control centre, incoming banner) is left alone.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      onScreenHidden();
    } else if (state == AppLifecycleState.resumed) {
      // Only the visible tab may resume.
      if (_tabVisible?.value ?? true) onScreenVisible();
    }
  }

  @override
  void dispose() {
    _tabVisible?.removeListener(_onTabVisibilityChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
