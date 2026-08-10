/// Barrel export for the app state + local persistence layer.
///
/// Screens should `import '../../core/state/state.dart';` and read state via
/// `context.watchAppState` / `context.appState` (see [AppScope]).
library;

export 'app_scope.dart';
export 'app_state.dart';
export 'entitlement_service.dart';
export 'languages.dart';
export 'plan.dart';
export 'remote_config.dart';
