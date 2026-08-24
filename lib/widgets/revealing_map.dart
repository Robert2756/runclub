import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';
import 'map_marker.dart';

const List<double> _mutedMapFilter = [
  1.08, -0.04, -0.02, 0, -1,
 -0.03,  1.07, -0.03, 0, -2,
 -0.02, -0.04,  1.08, 0,  0,
  0,     0,      0,    1,  0,
];

class _ShimmerPlaceholder extends StatelessWidget {
  const _ShimmerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        period: const Duration(milliseconds: 1400),
        child: Container(color: Colors.grey.shade200),
      ),
    );
  }
}

class _TrackingTileProvider extends NetworkTileProvider {
  _TrackingTileProvider({required this.onPendingCountChanged});

  final ValueChanged<int> onPendingCountChanged;
  int _pending = 0;

  void _increment() {
    _pending++;
    onPendingCountChanged(_pending);
  }

  void _decrement() {
    _pending = (_pending - 1).clamp(0, 1 << 30);
    onPendingCountChanged(_pending);
  }

  void _track(ImageProvider provider, TileCoordinates coords) {
    _increment();
    bool settled = false;

    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;

    void settle(String reason) {
      if (settled) return;
      settled = true;
      _decrement();
      stream.removeListener(listener);
    }

    listener = ImageStreamListener(
      (image, synchronousCall) => settle('loaded, sync=$synchronousCall'),
      onError: (error, stackTrace) => settle('error'),
    );

    stream.addListener(listener);
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final provider = super.getImage(coordinates, options);
    _track(provider, coordinates);
    return provider;
  }

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) {
    final provider =
        super.getImageWithCancelLoadingSupport(coordinates, options, cancelLoading);
    _track(provider, coordinates);
    return provider;
  }
}

/// Shared "muted map + shimmer-until-tiles-arrive + vignette" reveal used
/// by both PostCard and ActivityPage. Give it a fresh [Key] (e.g. tied to
/// join state or post id) whenever you want the reveal to replay — its
/// tile-tracking state lives entirely inside this widget's State.
class RevealingMap extends StatefulWidget {
  final LatLng location;
  final double initialZoom;
  final bool showMarker;
  final String? activity;
  final String mapUrl;

  // NEW — optional, only used by interactive callers like the create page
  final MapController? mapController;
  final InteractionOptions interactionOptions;
  final VoidCallback? onMapReady;
  final void Function(MapCamera camera, bool hasGesture)? onPositionChanged;
  final Widget? centerPin; // fixed overlay pin (doesn't move with a LatLng)

  const RevealingMap({
    super.key,
    required this.location,
    required this.initialZoom,
    required this.showMarker,
    required this.activity,
    required this.mapUrl,
    this.mapController,
    this.interactionOptions = const InteractionOptions(flags: InteractiveFlag.none),
    this.onMapReady,
    this.onPositionChanged,
    this.centerPin,
  });

  @override
  State<RevealingMap> createState() => _RevealingMapState();
}

class _RevealingMapState extends State<RevealingMap> {
  bool _mapReady = false;
  int _pendingTiles = 0;

  late final MapController _internalController = MapController();
  MapController get _controller => widget.mapController ?? _internalController;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  late final _TrackingTileProvider _tileProvider = _TrackingTileProvider(
    onPendingCountChanged: (pending) {
      _safeSetState(() => _pendingTiles = pending);
      if (pending == 0 && mounted && !_mapReady) {
        _safeSetState(() => _mapReady = true);
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(_mutedMapFilter),
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.location,
              initialZoom: widget.initialZoom,
              interactionOptions: widget.interactionOptions,
              onMapReady: widget.onMapReady,
              onPositionChanged: widget.onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: widget.mapUrl,
                tileProvider: _tileProvider,
                userAgentPackageName: 'com.robert.app',
                tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 250)),
                keepBuffer: 0,
                panBuffer: 0,
              ),
              if (widget.showMarker)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.location,
                      width: MapPinMarker.bodyDiameter,
                      height: MapPinMarker.bodyDiameter,
                      alignment: Alignment.center,
                      child: MapPinMarker(
                        activity: widget.activity == "Bike" ? "Bike" : "Run",
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // top-right vignette
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: _mapReady ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeIn,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 0.45,
                    colors: [Colors.black.withOpacity(0.06), Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),

        // bottom vignette
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: _mapReady ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeIn,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Colors.black.withOpacity(0.28), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ),

        if (widget.centerPin != null)
          IgnorePointer(child: Center(child: widget.centerPin)),

        IgnorePointer(
          ignoring: _mapReady,
          child: AnimatedOpacity(
            opacity: _mapReady ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: const _ShimmerPlaceholder(),
          ),
        ),
      ],
    );
  }
}