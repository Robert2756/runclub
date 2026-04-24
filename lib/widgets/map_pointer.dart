import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class RunMarkerPainter extends CustomPainter {
  final Color color;

  /// optional scale factor for the pointer (default 1.0)
  final double scale;

  const RunMarkerPainter({this.color = const Color.fromARGB(255, 223, 186, 255), this.scale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final path = ui.Path();

    final r = size.width / 2 * scale; // radius scales with size
    final cx = size.width / 2;
    final cy = r;

    // pointer size relative to circle radius
    final pointerWidth = r * 0.4;
    final pointerHeight = r * 0.3;

    // draw circle
    path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    // draw pointer triangle at bottom
    path.moveTo(cx - pointerWidth / 2, cy * 2);       // left
    path.lineTo(cx, cy * 2 + pointerHeight);          // tip
    path.lineTo(cx + pointerWidth / 2, cy * 2);       // right
    path.close();

    // draw shadow
    canvas.drawPath(path, shadow);
    // draw main shape
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}