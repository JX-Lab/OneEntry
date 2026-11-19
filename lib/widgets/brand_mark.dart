import 'dart:math' as math;

import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 112, this.monochrome = false});

  final double size;
  final bool monochrome;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '一笔：多条轨迹相交的标志',
    image: true,
    child: CustomPaint(
      size: Size.square(size),
      painter: _BrandMarkPainter(monochrome: monochrome),
    ),
  );
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.monochrome});

  final bool monochrome;

  static const List<(Offset, double, Color)> _rings = <(Offset, double, Color)>[
    (Offset(398, 398), -12, Color(0xFFF8F6FF)),
    (Offset(626, 398), 12, Color(0xFFB9F1EA)),
    (Offset(398, 626), 12, Color(0xFFFFD8CE)),
    (Offset(626, 626), -12, Color(0xFFD9CEFF)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = math.min(size.width, size.height) / 1024;
    canvas.save();
    canvas.scale(scale, scale);
    for (final (Offset center, double degrees, Color color) in _rings) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(degrees * math.pi / 180);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: 360, height: 276),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 54
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = monochrome ? Colors.white : color,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      oldDelegate.monochrome != monochrome;
}
