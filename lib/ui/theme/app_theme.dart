import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// Builds the app-wide light [ThemeData] from the divergent design tokens.
///
/// Typography uses the divergent substitute families (Poppins for display /
/// headings, Manrope for body) applied through `google_fonts` so every screen
/// inherits them without bundling the source app's `.ttf` files.
class AppTheme {
  AppTheme._();

  /// `design_tokens.button_style`.
  static const String buttonStyle = 'tonal';

  /// `design_tokens.elevation_style`.
  static const String elevationStyle = 'soft';

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accentTeal,
      onSecondary: Colors.white,
      tertiary: AppColors.accentOrange,
      onTertiary: AppColors.textPrimary,
      error: AppColors.danger,
      onError: AppColors.textPrimary,
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.cardBlue,
      outlineVariant: AppColors.separator,
    );

    // Poppins for the display/heading family; Manrope for body copy.
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );
    final poppins = GoogleFonts.poppinsTextTheme(base.textTheme);
    final textTheme = poppins.copyWith(
      bodyLarge: GoogleFonts.manrope(textStyle: poppins.bodyLarge),
      bodyMedium: GoogleFonts.manrope(textStyle: poppins.bodyMedium),
      bodySmall: GoogleFonts.manrope(textStyle: poppins.bodySmall),
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
    );
    final pillShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
    );

    return base.copyWith(
      textTheme: textTheme,
      // Smooth, consistent iOS-style push/pop transitions on every platform
      // (including the web-preview build) for a cohesive native feel.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
      primaryColor: AppColors.primary,
      dividerColor: AppColors.separator,
      dividerTheme: const DividerThemeData(
        color: AppColors.separator,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: AppDimens.softElevation,
        shadowColor: AppColors.textPrimary.withValues(alpha: 0.08),
        shape: cardShape,
        margin: EdgeInsets.zero,
      ),
      // `button_style: tonal` -> filled tonal look by default.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cardBlue,
          foregroundColor: AppColors.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: pillShape,
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: AppDimens.softElevation,
          shadowColor: AppColors.primary.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: pillShape,
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: pillShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          borderSide: const BorderSide(color: AppColors.separator),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.background,
        indicatorColor: AppColors.cardBlue,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: AppColors.textPrimary,
      ),
    );
  }
}
