import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/models.dart';

class FeederVisual extends StatelessWidget {
  const FeederVisual({super.key, required this.feeder, this.size = 104});
  final Feeder feeder;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = feeder.status == 'ok'
        ? p.succes
        : feeder.status == 'low'
            ? p.alerte
            : p.danger;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: feeder.levelPct.clamp(0, 100).toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, level, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _FeederPainter(level: level, fillColor: color, borderColor: p.bordure),
          child: Center(
            child: Text(
              '${level.toStringAsFixed(0)}%',
              style: TextStyle(
                color: level > 58 ? Colors.white : p.texte,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeederPainter extends CustomPainter {
  const _FeederPainter({required this.level, required this.fillColor, required this.borderColor});
  final double level;
  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final front = Rect.fromLTWH(w * 0.20, h * 0.28, w * 0.62, h * 0.58);
    final side = Path()
      ..moveTo(front.right, front.top)
      ..lineTo(w * 0.88, h * 0.35)
      ..lineTo(w * 0.88, h * 0.80)
      ..lineTo(front.right, front.bottom)
      ..close();
    final top = Path()
      ..moveTo(front.left, front.top)
      ..lineTo(w * 0.32, h * 0.16)
      ..lineTo(w * 0.82, h * 0.23)
      ..lineTo(w * 0.88, h * 0.35)
      ..lineTo(front.right, front.top)
      ..close();

    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(front, Paint()..color = const Color(0xFFF8FBFF));
    canvas.drawRect(front, border);
    canvas.drawPath(side, Paint()..color = const Color(0xFFDCE8F7));
    canvas.drawPath(side, border);
    canvas.drawPath(top, Paint()..color = const Color(0xFFEAF2FC));
    canvas.drawPath(top, border);

    final fillH = front.height * (level / 100);
    final fillRect = Rect.fromLTWH(front.left, front.bottom - fillH, front.width, fillH);
    canvas.drawRect(fillRect, Paint()..color = fillColor.withValues(alpha: 0.88));
  }

  @override
  bool shouldRepaint(covariant _FeederPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor;
}
