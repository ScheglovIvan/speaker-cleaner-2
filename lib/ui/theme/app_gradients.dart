import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Reusable [LinearGradient]s derived from `design_tokens.gradient.*`.
///
/// The token `angle` is a CSS-style angle in degrees (0 = to top,
/// 90 = to right, 135 = to bottom-right). [_alignmentsForAngle] converts it
/// into Flutter [Alignment] begin/end pairs so the gradients render the same
/// direction the tokens describe.
class AppGradients {
  AppGradients._();

  /// `design_tokens.gradient.primary` (angle 135, teal -> cyan).
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.accentTeal],
    stops: [0.0, 1.0],
  );

  /// Primary call-to-action pill gradient (teal -> cyan accent, 135deg).
  ///
  /// Screen CTAs (Start Cleaning, Start Free Trial, Start Today's Routine)
  /// compose from this so the pill styling stays frozen in the design system.
  static final LinearGradient primaryCta = fromAngle(
    135,
    const [
      _Stop(AppColors.primary, 0.0),
      _Stop(AppColors.accentTeal, 1.0),
    ],
  );

  /// Build a [LinearGradient] from a token angle (degrees) + colour stops.
  static LinearGradient fromAngle(double angleDeg, List<_Stop> stops) {
    final (begin, end) = _alignmentsForAngle(angleDeg);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [for (final s in stops) s.color],
      stops: [for (final s in stops) s.pos],
    );
  }

  static (Alignment, Alignment) _alignmentsForAngle(double angleDeg) {
    // CSS gradient angle: 0deg points up; increases clockwise.
    final rad = angleDeg * math.pi / 180.0;
    final dx = math.sin(rad);
    final dy = -math.cos(rad);
    return (Alignment(-dx, -dy), Alignment(dx, dy));
  }
}

/// A single gradient stop (colour + position 0..1).
class _Stop {
  const _Stop(this.color, this.pos);
  final Color color;
  final double pos;
}
