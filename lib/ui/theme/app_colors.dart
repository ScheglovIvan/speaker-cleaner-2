import 'package:flutter/material.dart';

/// App palette — a light, modern-minimalist AQUA family (cyan / teal / green /
/// blue-green) that fits a speaker-cleaning utility.
///
/// Every widget pulls its colours from here (or the [ThemeData] built on top of
/// it), so re-tinting the whole app happens in this one file. The previous
/// red-dominant palette has been fully removed.
class AppColors {
  AppColors._();

  /// Dominant tint for icons, selected states, links and readable accents.
  /// Deep teal — passes AA as body text on light surfaces.
  static const Color primary = Color(0xFF0F766E);

  /// Cyan end of the primary CTA gradient (and a secondary accent).
  static const Color accentTeal = Color(0xFF0E7490);

  /// Bright blue-green accent used in loaders / bubble icons / badges.
  static const Color accentOrange = Color(0xFF0D9488);

  /// Bars in the Stereo waveform visualizer (mint).
  static const Color channelPurple = Color(0xFF2DD4BF);

  /// Completed cleaning-plan day check / "Premium active" / calm-level accent.
  static const Color success = Color(0xFF059669);

  /// Stop / destructive / "loud level" accent. A warm amber (never red) so it
  /// stands apart from the aqua family for genuine alert semantics.
  static const Color danger = Color(0xFFD97706);

  /// Primary page background.
  static const Color background = Color(0xFFFFFFFF);

  /// Secondary / muted surface background (very light aqua).
  static const Color backgroundMuted = Color(0xFFEFF9F8);

  /// Splash / loading / paywall background (light aqua wash).
  static const Color backgroundSplash = Color(0xFFDFF3F1);

  /// Light card / tile fill (light aqua).
  static const Color cardBlue = Color(0xFFE0F2F0);

  /// Solid button / tint variant (matches [primary]).
  static const Color buttonBlue = Color(0xFF0F766E);

  /// Headings and body text (very dark teal-slate).
  static const Color textPrimary = Color(0xFF0B2E2B);

  /// Muted subtitles / captions (readable muted teal-grey).
  static const Color textSecondary = Color(0xFF4C716E);

  /// Hairline separators (light aqua).
  static const Color separator = Color(0xFFD5EAE7);
}
