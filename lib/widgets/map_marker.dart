import 'package:flutter/material.dart';
import 'dart:ui' as dart_ui;
import '../profile_page.dart';

class _MapPinPainter extends CustomPainter {
  final double bodyDiameter;
  final double tailHeight;

  const _MapPinPainter({this.bodyDiameter = 40, this.tailHeight = 6});

  @override
  void paint(Canvas canvas, Size size) {
    final r = bodyDiameter / 2;
    final cx = size.width / 2;
    final cy = r;
    final tipY = size.height; // pin tip == exact bottom pixel, by construction

    // Small tail: narrow, and starts exactly at the circle's bottom
    // edge (cy + r) rather than inside it — no overlap, no seam.
    final tailHalfWidth = r * 0.34;
    final tailStartY = cy + r * 0.85;

    final ovalPath = dart_ui.Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    final tailPath = dart_ui.Path()
      ..moveTo(cx - tailHalfWidth, tailStartY)
      ..lineTo(cx, tipY)
      ..lineTo(cx + tailHalfWidth, tailStartY)
      ..close();

    // True geometric union — avoids nonzero-fill winding cancellation
    // between the two subpaths (which was the source of the gap).
    final pinPath = dart_ui.Path.combine(
      dart_ui.PathOperation.union,
      ovalPath,
      tailPath,
    );

    // Manual shadow: the exact same silhouette, blurred, offset only
    // vertically. No simulated light source, so it can never drift
    // sideways relative to the shape above it — unlike drawShadow().
    canvas.save();
    canvas.translate(0, 2.5);
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = Colors.black.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();

    // Body fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          // const Color.fromARGB(255, 0, 0, 0),
          EnduvoColors.navy,
          EnduvoColors.navy,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, bodyDiameter));
    canvas.drawPath(pinPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _MapPinPainter oldDelegate) =>
      oldDelegate.bodyDiameter != bodyDiameter ||
      oldDelegate.tailHeight != tailHeight;
}

class MapPinMarker extends StatelessWidget {
  static const double bodyDiameter = 40;
  static const double tailHeight = 3;
  static const double iconSize = 18;

  const MapPinMarker();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: bodyDiameter,
      height: bodyDiameter + tailHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: const Size(bodyDiameter, bodyDiameter + tailHeight),
            painter: const _MapPinPainter(
              bodyDiameter: bodyDiameter,
              tailHeight: tailHeight,
            ),
          ),
          Positioned(
            top: (bodyDiameter - iconSize) / 2,
            left: (bodyDiameter - iconSize) / 2,
            child: const Icon(
              Icons.directions_bike,
              size: iconSize,
              color: Color.fromARGB(255, 255, 255, 255),
            ),
          ),
        ],
      ),
    );
  }
}