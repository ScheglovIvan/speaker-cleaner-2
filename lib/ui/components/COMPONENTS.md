# Design System — Shared Components

Every screen composes its UI from these widgets. They consume **only** the
divergent `design_tokens` through `lib/ui/theme/` (`AppColors`, `AppGradients`,
`AppDimens`) and the app `ThemeData` text theme. **Do not** hardcode colours,
fonts, gradients, radii or button/card styling in screens — those are frozen
here. See `manifest.json` for the machine-readable index.

Import once:

```dart
import '../../ui/components/components.dart';
```

## Tokens the components use

- **Colours** — `AppColors.*` (primary, accentTeal, accentOrange, channelPurple,
  success, danger, background, backgroundMuted, backgroundSplash, cardBlue,
  buttonBlue, textPrimary, textSecondary, separator).
- **Gradients** — `AppGradients.primaryCta` (blue→teal pill/hero gradient, from
  `design_tokens.gradient` + angle).
- **Radii** — `AppDimens.radiusSm/Md/Lg/Pill`, `screenPadding`.
- **Type** — Poppins (headings) / Manrope (body) via the theme text styles.
- `button_style: tonal`, `elevation_style: soft`.

## Widgets

### Structure
- **AppScaffold** — page shell: background + optional `AppTopBar` + screen
  padding + optional sticky `bottomBar` (CTA).
- **AppTopBar** — nav bar with title, back / close (X), trailing actions.
- **AppBottomBar** — the Clean / Modes / dB Level / Stereo tab bar.

### Actions
- **AppButton** — the pill button. `variant`: `gradient` (primary CTA),
  `tonal`, `solid`, `outlined`, `danger` (Stop). Optional leading `icon`,
  `loading`, `expand`.
- **AppIconButton** — circular icon button (back / close / crown).

### Surfaces & rows
- **AppCard** — rounded soft-shadow surface.
- **AppGradientCard** — gradient hero card (today's routine / featured).
- **AppListTile** — icon + title/subtitle + chevron row (settings, tips, modes).
- **AppSelectableRow** — single-select radio row (stereo channels, languages).
- **AppToggleRow** — row with a switch.
- **AppPlanDayRow** — 7-day plan row: `completed` / `current` / `locked`.
- **AppSectionHeader** — section title + optional action.

### Bits
- **AppChip** — small pill label (ratings, offer tags, filters).
- **AppBadge** — tiny status / PRO badge.
- **AppTextField** — themed input.
- **AppLoader** — indeterminate spinner or bar (+ status caption).
- **AppHeroIcon** — gradient tile with a functional glyph for hero placements.
  `AppHeroIcon.frame()` wraps illustration art.
- **AppIconMark** — the app's real launcher icon under the iOS rounded mask.
  Use it wherever the UI depicts the app itself (splash, loading, paywall hero,
  onboarding welcome).

### Feature visualizers
- **WaveformVisualizer** — animated mirrored bar waveform (Stereo / playback).
- **LevelGauge** — semicircular arc gauge with needle (dB Meter).

## Rules for screen tasks
1. Compose from the widgets above; never re-style them per screen.
2. Use `source/<id>.json` only for **layout** (placement/order/sizing) — the
   look is owned here.
3. Paraphrase all copy and use a consistent icon set that differs from the
   source (anti-clone). No source logo/wordmark — where the UI stands for the
   app itself, use `AppIconMark` (the real launcher icon).
4. No ad widgets or reserved ad strips.
