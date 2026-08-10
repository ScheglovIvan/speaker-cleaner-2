import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A semicircular arc gauge used for the dB Meter (and any level readout).
///
/// [value] is 0..1 of the sweep; [label]/[unit] render in the centre. The arc
/// is drawn with the primary tint over a soft track; the needle marks [value].
class LevelGauge extends StatelessWidget {
  const LevelGauge({
    super.key,
    required this.value,
    this.label,
    this.unit,
    this.size = 220,
    this.color,
  });

  /// Fill fraction, 0..1.
  final double value;

  /// Big centre number (e.g. "62").
  final String? label;

  /// Small centre caption (e.g. "dB").
  final String? unit;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final double v = value.clamp(0.0, 1.0).toDouble();

    return SizedBox(
      width: size,
      height: size * 0.62,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ExcludeSemantics(
            child: CustomPaint(
              size: Size(size, size * 0.62),
              painter: _GaugePainter(
                value: v,
                color: color ?? AppColors.primary,
                track: AppColors.separator,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: size * 0.06),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                if (unit != null)
                  Text(
                    unit!,
                    style: text.labelLarge
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;
  final Color track;

  static const double _start = math.pi; // 180° (left)
  static const double _sweep = math.pi; // 180° half circle

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.08;
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, _start, _sweep, false, trackPaint);

    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _start,
        endAngle: _start + _sweep,
        colors: [color.withValues(alpha: 0.6), color],
      ).createShader(rect);
    canvas.drawArc(rect, _start, _sweep * value, false, valuePaint);

    // Needle marking the current value.
    final angle = _start + _sweep * value;
    final needleEnd = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = stroke * 0.35
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, stroke * 0.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color || old.track != track;
}
