import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Publishes whether the wrapped tab is the shell's currently *visible* tab.
///
/// The shell keeps its tabs in an `IndexedStack` so their state (and scroll
/// position) survives a tab switch — which also means an inactive tab is only
/// hidden, never disposed. Screens that own something which must not keep
/// running while hidden (audio playback, in particular) listen to this signal
/// instead of relying on `dispose()`.
///
/// Absent when a screen is opened outside the shell (deep link, pushed route),
/// in which case [maybeOf] returns `null` and the screen just falls back to the
/// app-lifecycle signal.
class TabVisibility extends InheritedWidget {
  const TabVisibility({
    super.key,
    required this.isVisible,
    required super.child,
  });

  /// `true` while this tab is the one the shell is showing.
  final ValueListenable<bool> isVisible;

  /// The visibility signal of the nearest enclosing tab, or `null` when the
  /// screen is not inside the tab shell.
  static ValueListenable<bool>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabVisibility>()?.isVisible;

  @override
  bool updateShouldNotify(TabVisibility oldWidget) =>
      !identical(oldWidget.isVisible, isVisible);
}
