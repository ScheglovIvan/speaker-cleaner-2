import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Exposes the singleton [AppState] to the widget tree.
///
/// Uses [InheritedNotifier] so no third-party state package is needed: any
/// widget that reads via [AppScope.of] / `context.appState` (or the
/// `context.watchAppState` extension) rebuilds when the state notifies.
///
/// Usage:
/// ```dart
/// final state = context.watchAppState; // rebuilds on change
/// final state = context.appState;      // read-only, no rebuild
/// state.setLanguage('fr');
/// ```
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  /// Read the [AppState] and subscribe to changes (rebuilds on notify).
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope.of() called with no AppScope ancestor.');
    return scope!.notifier!;
  }

  /// Read the [AppState] WITHOUT subscribing (for one-off actions in callbacks).
  static AppState read(BuildContext context) {
    final scope =
        context.getElementForInheritedWidgetOfExactType<AppScope>()?.widget
            as AppScope?;
    assert(scope != null, 'AppScope.read() called with no AppScope ancestor.');
    return scope!.notifier!;
  }
}

/// Ergonomic accessors on [BuildContext].
extension AppScopeX on BuildContext {
  /// Rebuilds this widget when the state changes.
  AppState get watchAppState => AppScope.of(this);

  /// Read-only access (no dependency registered) — use inside callbacks.
  AppState get appState => AppScope.read(this);
}
