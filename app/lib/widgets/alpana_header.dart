import 'package:flutter/material.dart';

/// Traditional Bengali Alpana decorative header and motif widget.
/// Renders intricate kalka (paisley), padma (lotus), and sacred diya motifs.
class AlpanaHeader extends StatelessWidget {
  final double height;
  final String? title;
  final String? subtitle;
  final Widget? child;

  const AlpanaHeader({
    super.key,
    this.height = 110,
    this.title,
    this.subtitle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFB71C1C), // Deep Sindoor Crimson
            Color(0xFF880E14), // Royal Pujo Night Maroon
            Color(0xFF0D0D1E), // Deep Midnight Sky
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Background Custom Alpana Motif Painter
          Positioned.fill(
            child: CustomPaint(
              painter: AlpanaPainter(),
            ),
          ),

          // Content
          if (child != null)
            child!
          else if (title != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪷 ', style: TextStyle(fontSize: 16)),
                        Text(
                          title!,
                          style: const TextStyle(
                            color: Color(0xFFFFF8E7), // Rice-paste ivory
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(color: Color(0xFFFFB300), blurRadius: 10),
                            ],
                          ),
                        ),
                        const Text(' 🪷', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFD54F), // Warm Marigold
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for authentic Bengali Alpana curves and flourishes
class AlpanaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final whitePaint = Paint()
      ..color = const Color(0xFFFFF8E7).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final goldPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // Draw central top arched decorative wave
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Top border festoon scallops
    final scallopCount = (w / 40).ceil();
    final scallopWidth = w / scallopCount;
    for (int i = 0; i < scallopCount; i++) {
      final startX = i * scallopWidth;
      final midX = startX + scallopWidth / 2;
      final endX = (i + 1) * scallopWidth;
      path.moveTo(startX, 0);
      path.quadraticBezierTo(midX, 16, endX, 0);
    }
    canvas.drawPath(path, whitePaint);

    // Corner decorative kalka (paisley flourishes) on Left
    _drawAlpanaPaisley(canvas, const Offset(36, 45), 24, true, goldPaint, whitePaint, fillPaint);
    // Corner decorative kalka on Right
    _drawAlpanaPaisley(canvas, Offset(w - 36, 45), 24, false, goldPaint, whitePaint, fillPaint);

    // Decorative dotted motifs along the lower edge
    final dotCount = (w / 28).floor();
    final dotSpacing = w / (dotCount + 1);
    for (int i = 1; i <= dotCount; i++) {
      final cx = i * dotSpacing;
      final isAccent = i % 4 == 0;
      canvas.drawCircle(
        Offset(cx, h - 10),
        isAccent ? 2.5 : 1.4,
        isAccent ? goldPaint : whitePaint,
      );
    }
  }

  void _drawAlpanaPaisley(
    Canvas canvas,
    Offset center,
    double radius,
    bool isLeft,
    Paint goldPaint,
    Paint whitePaint,
    Paint fillPaint,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (!isLeft) canvas.scale(-1, 1);

    // Lotus petal / Paisley shape
    final p = Path();
    p.moveTo(0, radius);
    p.cubicTo(-radius * 0.8, radius * 0.4, -radius * 0.9, -radius * 0.5, 0, -radius);
    p.cubicTo(radius * 0.9, -radius * 0.5, radius * 0.8, radius * 0.4, 0, radius);
    p.close();

    canvas.drawPath(p, fillPaint);
    canvas.drawPath(p, goldPaint);

    // Inner petal
    final inner = Path();
    inner.moveTo(0, radius * 0.6);
    inner.cubicTo(-radius * 0.4, radius * 0.2, -radius * 0.4, -radius * 0.3, 0, -radius * 0.6);
    inner.cubicTo(radius * 0.4, -radius * 0.3, radius * 0.4, radius * 0.2, 0, radius * 0.6);
    inner.close();
    canvas.drawPath(inner, whitePaint);

    // Small glowing diya circle
    canvas.drawCircle(Offset(0, -radius * 0.1), 3.0, goldPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small decorative divider with traditional floral / diya accents
class AlpanaDivider extends StatelessWidget {
  final double width;
  const AlpanaDivider({super.key, this.width = 180});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFFFFB300)],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('🪷 ✦ 🪔 ✦ 🪷', style: TextStyle(fontSize: 10, color: Color(0xFFFFD54F))),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFB300), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
