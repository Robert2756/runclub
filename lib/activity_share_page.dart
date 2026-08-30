// ─────────────────────────────────────────────────────────────────────────
// pubspec.yaml changes needed:
//
//   dependencies:
//     file_saver: ^0.2.14     # NEW — cross-platform save (Android/iOS/Web/
//                              # macOS/Windows/Linux). Replaces `gal`, which
//                              # only works on iOS/Android.
//     share_plus: ^10.0.0     # keep, just make sure it's a recent version —
//                              # cross-platform sharing (mobile share sheet,
//                              # Web Share API, desktop fallback).
//
//   You can remove `gal` and (if unused elsewhere) `path_provider`.
//
//   NOTE on file_saver: the enum casing (`MimeType.png` vs `MimeType.PNG`)
//   and the `saveFile` signature changed between 0.1.x and 0.2.x. If you're
//   pinned to an older version, adjust `_saveBytes()` below accordingly.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'widgets/map_marker.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import 'models/post.dart';
import 'services/data_formatter.dart';
import 'signin_page.dart' show EnduvoColors;

enum ShareStyle { image, map, transparent }

/// Checkerboard used only as an in-app hint that the "transparent" style
/// exports without a background — never rendered into the actual export.
class CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const square = 20.0;
    final light = Paint()..color = const Color(0xFFE9EBEF);
    final dark = Paint()..color = const Color(0xFFDDE0E5);

    for (double y = 0; y < size.height; y += square) {
      for (double x = 0; x < size.width; x += square) {
        final isDark = ((x / square + y / square) % 2 == 0);
        canvas.drawRect(Rect.fromLTWH(x, y, square, square), isDark ? light : dark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ActivityConfig {
  final String statLabel;
  final String Function(Post post) statValue;
  const ActivityConfig({required this.statLabel, required this.statValue});
}

class ActivitySharePage extends StatefulWidget {
  final Post post;
  final int participants;
  final String? profileName;

  const ActivitySharePage({
    super.key,
    required this.post,
    required this.participants,
    required this.profileName,
  });

  @override
  State<ActivitySharePage> createState() => _ActivitySharePageState();
}

class _ActivitySharePageState extends State<ActivitySharePage> {
  final GlobalKey _captureKey = GlobalKey();
  final GlobalKey _exportKey = GlobalKey();
  final dataFormatter = DataFormatter();
  OverlayEntry? _exportEntry;

  ShareStyle _style = ShareStyle.image;
  bool _showStats = true;

  bool _busy = false;
  String? _busyAction; // 'save' | 'share'

  final mapUrl =
      'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';

  // ── Capture ──────────────────────────────────────────────────────────

  Future<Uint8List?> _capture() async {
    if (_style == ShareStyle.transparent) {
      return _captureTransparent(stats: _showStats);
    }

    try {
      final boundary =
          _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // while (boundary.debugNeedsPaint) {
      //   await Future.delayed(const Duration(milliseconds: 20));
      // }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture failed: $e');
      return null;
    }
  }

  Future<Uint8List?> _captureTransparent({required bool stats}) async {
    try {
      const double dpr = 3.0;

      _exportEntry = OverlayEntry(
        builder: (_) => Positioned(
          // Far enough off-screen to be invisible, but within a range the
          // GPU still fully rasterizes. -10000 breaks on some devices;
          // -1500 stays within raster bounds.
          left: -1500,
          top: 0,
          child: Material(
            color: Colors.transparent,
            child: RepaintBoundary(
              key: _exportKey,
              child: IntrinsicHeight(
                child: IntrinsicWidth(
                  child: MediaQuery(
                    data: const MediaQueryData(
                      devicePixelRatio: dpr,
                      textScaler: TextScaler.noScaling,
                    ),
                    child: _uiLayer(stats: stats),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(_exportEntry!);

      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _exportKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // while (boundary.debugNeedsPaint) {
      //   await Future.delayed(const Duration(milliseconds: 16));
      // }

      final image = await boundary.toImage(pixelRatio: dpr);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      _exportEntry?.remove();
      _exportEntry = null;

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Transparent capture failed: $e');
      _exportEntry?.remove();
      _exportEntry = null;
      return null;
    }
  }

  // ── Save / Share (platform-independent) ────────────────────────────

  Future<void> _handleSave() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyAction = 'save';
    });

    try {
      final bytes = await _capture();
      if (bytes == null) throw Exception('capture returned null');
      await _saveBytes(bytes);
      if (!mounted) return;
      _showSnack('Gespeichert');
    } catch (e) {
      debugPrint('Save failed: $e');
      if (!mounted) return;
      _showSnack('Speichern fehlgeschlagen', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyAction = null;
        });
      }
    }
  }

  Future<void> _saveBytes(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/enduvo_activity_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    await file.writeAsBytes(bytes, flush: true);

    await Gal.putImage(file.path);
  }

  Future<void> _handleShare(BuildContext buttonContext) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyAction = 'share';
    });

    try {
      final bytes = await _capture();
      if (bytes == null) throw Exception('capture returned null');

      final file = XFile.fromData(
        bytes,
        name: 'enduvo_activity.png',
        mimeType: 'image/png',
      );

      final box = buttonContext.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await Share.shareXFiles(
            [file],
            text: 'Mit Enduvo unterwegs — ${widget.post.title}',
            sharePositionOrigin: origin,
          );

    } catch (e) {
      debugPrint('Share failed: $e');
      if (!mounted) return;
      _showSnack('Teilen fehlgeschlagen', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyAction = null;
        });
      }
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : EnduvoColors.text,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Card content ─────────────────────────────────────────────────────

  Widget _statChip({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      // decoration: BoxDecoration(
      //   color: Colors.white.withOpacity(0.10),
      //   borderRadius: BorderRadius.circular(11),
      //   border: Border.all(
      //     color: Colors.white.withOpacity(0.16),
      //   ),
      // ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.60),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _enduvoSignature() {
    return Opacity(
      opacity: 0.82,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(6),
            child:           Text(
            'ENDUVO',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),),
          Image.asset(
            'assets/EnduvoInAppLogo1152x1152-2.png',
            width: 20,
            height: 20,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _uiLayer({bool stats = false}) {
    final post = widget.post;

    final activityConfigs = {
      'Run': ActivityConfig(
        statLabel: 'Pace',
        statValue: (post) => post.pace != null ? dataFormatter.formatPace(post.pace!) : '-',
      ),
      'Bike': ActivityConfig(
        statLabel: 'Speed',
        statValue: (post) => post.speed != null ? '${post.speed} km/h' : '-',
      ),
    };
    final config = activityConfigs[post.activity];

    final date = dataFormatter.formatActivityDate(DateTime.parse(post.startsAt!));
    final time = dataFormatter.formatTime(DateTime.parse(post.startsAt!));

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                post.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${post.town ?? "Unbekannter Ort"} · $date · $time',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            if (stats &&
                (post.distance != null ||
                    post.pace != null ||
                    post.speed != null)) ...[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (post.distance != null)
                    _statChip(
                      label: 'Distanz',
                      value: post.distance! >= 1000
                          ? '${(post.distance! / 1000).toStringAsFixed(1)} km'
                          : '${post.distance!.round()} m',
                    ),

                  if (post.distance != null &&
                      (post.pace != null || post.speed != null))
                    // const SizedBox(height: 6),

                  if (post.pace != null || post.speed != null)
                    _statChip(
                      label: config?.statLabel ?? 'Pace',
                      value: config?.statValue(post) ?? '-',
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            const Spacer(),
            Align(
              alignment: Alignment.center,
              child: _enduvoSignature(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desaturatedBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.92, 0.04, 0.04, 0, 0,
            0.04, 0.92, 0.04, 0, 0,
            0.04, 0.04, 0.92, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Image.network(widget.post.imgurl!, fit: BoxFit.cover),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.72),
                Colors.black.withOpacity(0.18),
                Colors.black.withOpacity(0.32),
              ],
            ),
          ),
        ),
        Container(color: EnduvoColors.deepBlue.withOpacity(0.08)),
      ],
    );
  }

  Widget _checkerboardBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: CheckerPainter()),
        Container(color: Colors.black.withOpacity(0.10)),
      ],
    );
  }

  Widget _imageCard({bool transparentVisual = false, bool transparentExport = false, bool stats = false}) {
    return ClipRRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (transparentVisual)
            _checkerboardBackground()
          else if (transparentExport)
            const SizedBox.expand()
          else if (widget.post.imgurl != null)
            _desaturatedBackground()
          else
            Container(color: EnduvoColors.navy),
          _uiLayer(stats: stats),
        ],
      ),
    );
  }

  Widget _enduvoWatermark() {
    return Opacity(
      opacity: 0.72,
      child: Image.asset(
        'assets/EnduvoInAppLogo1152x1152-2.png',
        width: 34,
        height: 34,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _mapCard({bool stats = false}) {
    final lat = widget.post.latitude ?? 0;
    final lng = widget.post.longitude ?? 0;

    final location =
        (widget.post.latitude != null && widget.post.longitude != null)
            ? LatLng(widget.post.latitude!, widget.post.longitude!)
            : const LatLng(0.0, 0.0);

    return ClipRRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Map background ───────────────────────────────────────
          ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.92, 0.04, 0.04, 0, 0,
              0.04, 0.92, 0.04, 0, 0,
              0.04, 0.04, 0.92, 0, 0,
              0,    0,    0,    1, 0,
            ]),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 2,
                sigmaY: 2,
              ),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat, lng),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: mapUrl,
                  ),
                ],
              ),
            ),
          ),

          // ── Same visual treatment as image card ──────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.72),
                  Colors.black.withOpacity(0.18),
                  Colors.black.withOpacity(0.32),
                ],
              ),
            ),
          ),

          Container(
            color: EnduvoColors.deepBlue.withOpacity(0.08),
          ),

          // ── Text / stats / branding ──────────────────────────────
          _uiLayer(stats: stats),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    switch (_style) {
      case ShareStyle.image:
        return _imageCard(stats: _showStats);
      case ShareStyle.map:
        return _mapCard(stats: _showStats);
      case ShareStyle.transparent:
        return _imageCard(transparentVisual: true, stats: _showStats);
    }
  }

  // ── Chrome ───────────────────────────────────────────────────────────

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context, true),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EnduvoColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: const Icon(Icons.arrow_back_ios_new, size: 18, color: EnduvoColors.text),
      ),
    );
  }

  Widget _styleSegments() {
    return SegmentedButton<ShareStyle>(
      segments: const [
        ButtonSegment(value: ShareStyle.image, icon: Icon(Icons.photo_camera_outlined, size: 18)),
        ButtonSegment(value: ShareStyle.map, icon: Icon(Icons.map_outlined, size: 18)),
        ButtonSegment(value: ShareStyle.transparent, icon: Icon(Icons.layers_outlined, size: 18)),
      ],
      selected: {_style},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() => _style = s.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: EnduvoColors.muted,
        selectedBackgroundColor: EnduvoColors.text,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: EnduvoColors.border),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }

  Widget _statsToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showStats = !_showStats),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EnduvoColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.query_stats_rounded, size: 17, color: _showStats ? EnduvoColors.deepBlue : EnduvoColors.muted),
            const SizedBox(width: 6),
            Text(
              'Statistiken',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _showStats ? EnduvoColors.text : EnduvoColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: _showStats,
              onChanged: (v) => setState(() => _showStats = v),
              activeColor: EnduvoColors.deepBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool primary,
    required bool loading,
  }) {
    final child = loading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          );

    if (primary) {
      return ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: EnduvoColors.text,
          foregroundColor: Colors.white,
          disabledBackgroundColor: EnduvoColors.text.withOpacity(0.65),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: EnduvoColors.text,
        disabledForegroundColor: EnduvoColors.muted,
        side: const BorderSide(color: EnduvoColors.border, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnduvoColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  _buildBackButton(),
                  Expanded(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/EnduvoInAppLogo1152x1152-2.png',
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Aktivität teilen',
                          style: TextStyle(fontSize: 12.5, color: EnduvoColors.muted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 44), // balances the back button
                ],
              ),
            ),

            // ── Preview card ────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 30, offset: const Offset(0, 16)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: RepaintBoundary(
                          key: _captureKey,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                              key: ValueKey('$_style-$_showStats'),
                              child: _buildPreviewCard(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Style + stats controls ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _styleSegments()),
                  const SizedBox(width: 10),
                  _statsToggle(),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Actions ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: _actionButton(
                        label: 'Speichern',
                        icon: Icons.download_rounded,
                        onPressed: _handleSave,
                        primary: false,
                        loading: _busy && _busyAction == 'save',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Builder(
                      builder: (buttonContext) => SizedBox(
                        height: 52,
                        child: _actionButton(
                          label: 'Teilen',
                          icon: Icons.ios_share_rounded,
                          onPressed: () => _handleShare(buttonContext),
                          primary: true,
                          loading: _busy && _busyAction == 'share',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}