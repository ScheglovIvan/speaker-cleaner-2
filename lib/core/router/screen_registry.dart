import 'package:flutter/widgets.dart';

// Every screen id in app_spec.json maps to exactly one feature file + widget.
// A later screen task overwrites only lib/features/<id>/ (same path + class),
// so this registry never needs editing when a screen becomes real.
import '../../features/0000/0000_screen.dart';
import '../../features/0001/0001_screen.dart';
import '../../features/0002/0002_screen.dart';
import '../../features/0003/0003_screen.dart';
import '../../features/0004/0004_screen.dart';
import '../../features/0005/0005_screen.dart';
import '../../features/0006/0006_screen.dart';
import '../../features/0007/0007_screen.dart';
import '../../features/0008/0008_screen.dart';
import '../../features/0009/0009_screen.dart';
import '../../features/0010/0010_screen.dart';
import '../../features/0011/0011_screen.dart';
import '../../features/0012/0012_screen.dart';
import '../../features/0013/0013_screen.dart';

/// Central id -> screen-builder table. The single source of truth the router
/// and tab shell both consult, so every screen id stays reachable.
class ScreenRegistry {
  ScreenRegistry._();

  /// The Home screen shown at `/` and after splash.
  static const String homeId = '0011';

  static final Map<String, WidgetBuilder> builders = <String, WidgetBuilder>{
    '0000': (_) => const Screen_0000(),
    '0001': (_) => const Screen_0001(),
    '0002': (_) => const Screen_0002(),
    '0003': (_) => const Screen_0003(),
    '0004': (_) => const Screen_0004(),
    '0005': (_) => const Screen_0005(),
    '0006': (_) => const Screen_0006(),
    '0007': (_) => const Screen_0007(),
    '0008': (_) => const Screen_0008(),
    '0009': (_) => const Screen_0009(),
    '0010': (_) => const Screen_0010(),
    '0011': (_) => const Screen_0011(),
    '0012': (_) => const Screen_0012(),
    '0013': (_) => const Screen_0013(),
  };

  static bool has(String id) => builders.containsKey(id);

  /// Build a screen widget by id, or `null` if unknown.
  static Widget? build(BuildContext context, String id) =>
      builders[id]?.call(context);
}
