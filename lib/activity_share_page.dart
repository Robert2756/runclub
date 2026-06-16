import 'package:flutter/material.dart';
import 'models/post.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'services/data_formatter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

enum ShareStyle {
  image,
  map,
  transparent,
}

class CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const square = 20.0;

    final light = Paint()..color = const Color(0xFFE6E6E6);
    final dark  = Paint()..color = const Color(0xFFD2D2D2);

    for (double y = 0; y < size.height; y += square) {
      for (double x = 0; x < size.width; x += square) {
        final isDark = ((x / square + y / square) % 2 == 0);
        canvas.drawRect(
          Rect.fromLTWH(x, y, square, square),
          isDark ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ActivityConfig {
  final String statLabel;
  final String Function(Post post) statValue;

  const ActivityConfig({
    required this.statLabel,
    required this.statValue,
  });
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
  final dataFormatter = DataFormatter();
  final PageController _pageController = PageController();
  final GlobalKey _exportKey = GlobalKey();
  OverlayEntry? _exportEntry;
  final mapUrl = 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';

  // Future<Uint8List?> _capture() async {
  //   try {
  //     final boundary = await _showExportOverlay();

  //     if (boundary.debugNeedsPaint) {
  //       await Future.delayed(const Duration(milliseconds: 100));
  //     }

  //     final image = await boundary.toImage(
  //       pixelRatio: 3.0,
  //     );

  //     final byteData = await image.toByteData(
  //       format: ui.ImageByteFormat.png,
  //     );

  //     _exportEntry?.remove();
  //     _exportEntry = null;

  //     return byteData?.buffer.asUint8List();
  //   } catch (e) {
  //     debugPrint("Capture failed: $e");

  //     _exportEntry?.remove();
  //     _exportEntry = null;

  //     return null;
  //   }
  // }

  Future<Uint8List?> _capture() async {
    final page = _pageController.hasClients
        ? (_pageController.page ?? 0).round()
        : 0;

    if (page == 4 || page == 5) {
      return _captureTransparent(stats: page == 5);
    }

    // For all other pages: capture exactly what's on screen
    try {
      final boundary = _captureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      while (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 20));
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Capture failed: $e");
      return null;
    }
  }

  Future<Uint8List?> _captureTransparent({required bool stats}) async {
    try {
      const double dpr = 3.0;

      _exportEntry = OverlayEntry(
        builder: (_) => Positioned(
          // Just far enough off-screen to be invisible,
          // but within a range the GPU still rasterizes fully.
          // -10000 is the problem; -1500 stays within raster bounds on most devices.
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

      final boundary = _exportKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      while (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 16));
      }

      final image = await boundary.toImage(pixelRatio: dpr);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      _exportEntry?.remove();
      _exportEntry = null;

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Transparent capture failed: $e");
      _exportEntry?.remove();
      _exportEntry = null;
      return null;
    }
  }

  Future<void> _save() async {
    try {
      final bytes = await _capture();
      if (bytes == null) return;

      await Gal.putImageBytes(bytes);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gespeichert in der Galerie"),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Fehler beim Speichern"),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            child: Image.network(
              widget.post.imgurl!,
              fit: BoxFit.cover,
            ),
          ),
        ),

        // stronger readability layer
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.75),
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.2),
              ],
            ),
          ),
        ),

        // subtle RUNCLUB tint wash
        Container(
          color: const Color(0xFFB6A0FF).withOpacity(0.06),
        ),
      ],
    );
  }

  Widget _checkerboardBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: CheckerPainter()),

        Container(
          color: Colors.black.withOpacity(0.14),
        ),
      ],
    );
  }

  Widget _uiLayer({
    bool stats = false
  }) {
    final post = widget.post;

    final activityConfigs = {
      "Run": ActivityConfig(
        statLabel: "Pace",
        statValue: (post) => post.pace != null
            ? dataFormatter.formatPace(post.pace!)
            : "-",
      ),
      "Bike": ActivityConfig(
        statLabel: "Speed",
        statValue: (post) => post.speed != null
            ? "${post.speed} km/h"
            : "-",
      ),
    };
    final config = activityConfigs[post.activity];

    final date = dataFormatter.formatActivityDate(
      DateTime.parse(post.startsAt!),
    );

    final time = dataFormatter.formatTime(
      DateTime.parse(post.startsAt!),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          children: [

            Text(
              post.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              "${post.town ?? "Unknown location"} · $date · $time",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),

            // const SizedBox(height: 6),

            // Text(
            //   post.town ?? "Unknown location",
            //   textAlign: TextAlign.center,
            //   style: TextStyle(
            //     color: Colors.white.withOpacity(0.7),
            //     fontSize: 14,
            //     fontWeight: FontWeight.w600,
            //   ),
            // ),

            if (stats)
              Column(
                children: [
                  const SizedBox(height: 14),
                  Column(
                    children: [
                      if (post.distance != null) ...[
                        Text(
                          "DISTANZ",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          post.distance! >= 1000
                              ? "${(post.distance! / 1000).toStringAsFixed(1)} km"
                              : "${post.distance!.round()} m",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (post.distance != null && post.pace != null)
                        const SizedBox(height: 10),
                      if (post.pace != null) ...[
                        Text(
                          config?.statLabel.toUpperCase() ?? "PACE",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          config?.statValue(post) ?? "-",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4)
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${widget.profileName} | ",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    "RUNCLUB",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              )
          ],
        )
      ),
    );
  }

  Widget _imageCard({
    bool transparentVisual = false,
    bool transparentExport = false,
    bool stats = false,
  }) {

    return ClipRRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          /// BACKGROUND ONLY IF NOT TRANSPARENT
          if (transparentVisual)
            _checkerboardBackground()
          else if (transparentExport)
            SizedBox.expand()
          else if (widget.post.imgurl != null)
            _desaturatedBackground()
          else
            Container(color: Colors.black),

          /// UI ALWAYS ON TOP
          _uiLayer(stats: stats),
        ],
      ),
    );
  }

  Widget _mapCard({
    stats = false
  }) {
    final lat = widget.post.latitude ?? 0;
    final lng = widget.post.longitude ?? 0;

    final location = (widget.post.latitude != null && widget.post.longitude != null)
      ? LatLng(widget.post.latitude!, widget.post.longitude!)
      : LatLng(0.0, 0.0);

    return ClipRRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(lat, lng),
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(urlTemplate: mapUrl),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: location,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            widget.post.activity == "Bike"
                                ? Icons.directions_bike
                                : Icons.directions_run,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
            ],
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.65),
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.2),
                ],
              ),
            ),
          ),
          _uiLayer(stats: stats),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context, true),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
          ),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCard(int index) {
    switch (index) {
      case 0:
        return _imageCard();
      case 1:
        return _imageCard(stats: true);
      case 2:
        return _mapCard();
      case 3:
        return _mapCard(stats: true);
      case 4:
        return _imageCard(transparentVisual: true);
      case 5:
        return _imageCard(
          transparentVisual: true,
          stats: true
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildExportView() {
    final page = _pageController.hasClients
        ? (_pageController.page ?? 0).round()
        : 0;

    // Transparent styles: wrap tightly to content, not 1080x1080
    if (page == 4 || page == 5) {
      return _buildTransparentExportView(stats: page == 5);
    }

    return Material(
      color: Colors.transparent,
      child: Center(
        child: RepaintBoundary(
          key: _exportKey,
          child: SizedBox(
            width: 1080,
            height: 1080,
            child: _buildExportCard(page),
          ),
        ),
      ),
    );
  }

  Widget _buildExportCard(int index) {
    switch (index) {
      case 0:
        return _imageCard();
      case 1:
        return _imageCard(stats: true);
      case 2:
        return _mapCard();
      case 3:
        return _mapCard(stats: true);
      case 4:
        return _imageCard(transparentExport: true);
      case 5:
        return _imageCard(transparentExport: true, stats: true);
      default:
        return const SizedBox.shrink();
    }
  }

  Future<RenderRepaintBoundary> _showExportOverlay() async {
    _exportEntry = OverlayEntry(
      builder: (_) => _buildExportView(),
    );

    Overlay.of(context).insert(_exportEntry!);

    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 100));

    final boundary = _exportKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary;

    while (boundary.debugNeedsPaint) {
      await Future.delayed(const Duration(milliseconds: 20));
    }

    return boundary;
  }

  Widget _buildTransparentExportView({bool stats = false}) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: RepaintBoundary(
          key: _exportKey,
          child: IntrinsicHeight(
            child: IntrinsicWidth(
              child: _uiLayer(stats: stats),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _pageController.hasClients
        ? (_pageController.page ?? 0).round()
        : 0;

    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          /// =========================
          /// TOP AREA (Back Button)
          /// =========================
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildBackButton(),
                  ),
                ),

                /// =========================
                /// MAIN CONTENT (PageView)
                /// =========================
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (page == 2)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                  RepaintBoundary(
                                    key: _captureKey,
                                    child: PageView(
                                      controller: _pageController,
                                      onPageChanged: (_) => setState(() {}),
                                      children: [
                                        _buildCard(0),
                                        _buildCard(1),
                                        _buildCard(2),
                                        _buildCard(3),
                                        _buildCard(4),
                                        _buildCard(5),
                                      ],
                                    ),
                                  ),
                                ]
                              )
                            ]
                          )
                        ),

                        const SizedBox(height: 12),

                        /// =========================
                        /// PAGE INDICATOR
                        /// =========================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (i) {
                            final active = i == page;

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              child: Text(
                                "°",
                                style: TextStyle(
                                  color: active
                                      ? Colors.black.withOpacity(0.65)
                                      : Colors.black.withOpacity(0.2),
                                  fontSize: 18,
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                /// =========================
                /// BOTTOM ACTION
                /// =========================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text("Als Bild speichern"),
                    ),
                  ),
                ),
              ]
            )
          )
        ]
      )
    );
  }
}