/// Barrel export for the shared design-system components.
///
/// Import this single file in screen code:
/// `import '../../ui/components/components.dart';`
///
/// Every widget here consumes ONLY the divergent `design_tokens` (via
/// `lib/ui/theme/`) — screens must not invent new colours, fonts, gradients or
/// button/card styling. See `manifest.json` / `COMPONENTS.md`.
library;

export 'app_badge.dart';
export 'app_bottom_bar.dart';
export 'app_button.dart';
export 'app_card.dart';
export 'app_chip.dart';
export 'app_hero_icon.dart';
export 'app_icon_button.dart';
export 'app_list_tile.dart';
export 'app_loader.dart';
export 'app_plan_day_row.dart';
export 'app_scaffold.dart';
export 'app_section_header.dart';
export 'app_selectable_row.dart';
export 'app_text_field.dart';
export 'app_top_bar.dart';
export 'level_gauge.dart';
export 'waveform_visualizer.dart';
