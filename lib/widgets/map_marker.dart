import 'package:flutter/material.dart';
import 'dart:ui' as dart_ui;
import '../profile_page.dart';
import '../profile_page.dart'; // for EnduvoColors

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
      // ..shader = LinearGradient(
      //   begin: Alignment.topCenter,
      //   end: Alignment.bottomCenter,
      //   colors: [
      //     // const Color.fromARGB(255, 0, 0, 0),
      //     EnduvoColors.navy,
      //     EnduvoColors.navy,
      //   ],
      // ).createShader(Rect.fromLTWH(0, 0, size.width, bodyDiameter));
      ..color = EnduvoColors.navy.withOpacity(0.86);
    canvas.drawPath(pinPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _MapPinPainter oldDelegate) =>
      oldDelegate.bodyDiameter != bodyDiameter ||
      oldDelegate.tailHeight != tailHeight;
}

class MapPinMarker extends StatelessWidget {
  static const double bodyDiameter = 58; // total footprint incl. glow
  static const double tailHeight = 0;    // no tail anymore
  static const double _coreDiameter = 36;
  static const double iconSize = 20;

  final String activity;

  const MapPinMarker({
    super.key,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: bodyDiameter,
      height: bodyDiameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft outer glow — brand teal, heavily blurred, low opacity.
          Container(
            width: bodyDiameter,
            height: bodyDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  // EnduvoColors.teal.withOpacity(0.30),
                  // EnduvoColors.teal.withOpacity(0.0),
                  EnduvoColors.muted.withOpacity(0.30),
                  EnduvoColors.muted.withOpacity(0.0),
                ],
              ),
            ),
          ),
          // Core marker: white disc, soft shadow, thin brand ring.
          Container(
            width: _coreDiameter,
            height: _coreDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: EnduvoColors.navy.withOpacity(0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            // child: Icon(
            //   activity == "Bike"
            //       ? Icons.directions_bike_rounded
            //       : Icons.directions_run_rounded,
            //   size: iconSize,
            //   color: EnduvoColors.navy,
            // ),
            child: Icon(
              Icons.location_on_rounded,
              size: iconSize,
              color: EnduvoColors.navy,
            )
          ),
        ],
      ),
    );
  }
}