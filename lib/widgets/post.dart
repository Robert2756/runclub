import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/data_formatter.dart';
import 'package:characters/characters.dart';
import '../widgets/participant_stack.dart';
import '../widgets/map_pointer.dart';
import 'dart:ui';
import '../models/post.dart';
import '../profile_page.dart';
import '../participant_page.dart';
import '../activity_page.dart';
import 'post_placeholder.dart';
import '../services/data_formatter.dart';
import 'package:shimmer/shimmer.dart';
import 'user_avatar.dart';
import 'map_marker.dart';
import 'dart:ui' as dart_ui;
import 'package:cached_network_image/cached_network_image.dart';

final supabase = Supabase.instance.client;
final dataFormatter = DataFormatter();

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

// Two-point snap physics: always settles on the image (offset 0) or the
// map (maxScrollExtent), taking the fling velocity into account so a
// decisive swipe commits to the target even mid-drag.
class _CarouselSnapPhysics extends ScrollPhysics {
  const _CarouselSnapPhysics({super.parent});

  @override
  _CarouselSnapPhysics applyTo(ScrollPhysics? ancestor) {
    return _CarouselSnapPhysics(parent: buildParent(ancestor));
  }

  double _snapTarget(ScrollMetrics position, double velocity) {
    final max = position.maxScrollExtent;
    const velocityThreshold = 300.0;
    if (velocity > velocityThreshold) return max;
    if (velocity < -velocityThreshold) return 0.0;
    return position.pixels < max / 2 ? 0.0 : max;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final target = _snapTarget(position, velocity);
    final tolerance = toleranceFor(position);
    if ((position.pixels - target).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);
  }

  @override
  bool get allowImplicitScrolling => false;
}

class PostCard extends StatefulWidget {
  final Post post;
  final bool showImageMain;
  final ValueChanged<bool> onToggle; // parent is rebuild when calling
  final String usernameCreator;
  final String? avatarUrlCreator;
  final List participantIds;
  final void Function(String postId)? onPostDeleted;

  const PostCard({
    super.key,
    required this.post,
    required this.showImageMain,
    required this.onToggle,
    required this.usernameCreator,
    required this.avatarUrlCreator,
    required this.participantIds,
    this.onPostDeleted,
  });
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with RouteAware, AutomaticKeepAliveClientMixin {
  final dataFormatter = DataFormatter();
  bool _descExpanded = false;
  bool _joined = false;
  List<String> _participantAvatars = [];
  List<String> _participantIds = [];
  List<String> debugParticipants = [];
  bool isReady = false;
  final bullet = " •\u200B ";
  bool _imageLoaded = false;

  // Map reveal state: the map starts hidden behind a shimmer for a
  // short fixed window right after the card mounts, giving the tile
  // requests a moment to land in the background instead of the user
  // watching them pop in raw. After that first reveal, tiles are
  // cached (both by flutter_map and the OS image cache), so toggling
  // between image/map afterwards is effectively instant and doesn't
  // need to re-trigger this.
  bool _mapReady = false;
  Timer? _mapRevealTimer;
  bool _locationNoticeExpanded = false;

  // Image/map carousel state. The media box is always a 4:3 box; the
  // image is shown at 1:1 (so it doesn't fill the box width), and a
  // sliver of the map peeks in on the right as a swipe affordance.
  // Swiping snaps between "image" (offset 0) and "map" (max extent).
  final ScrollController _carouselController = ScrollController();
  bool _carouselShowingImage = true;
  bool _carouselInitialPositionApplied = false;

  String get _mapUrl {
    final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final retina = dpr >= 2 ? '@2x' : '';
    return 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}$retina.png?key=yH0AJynJV0qzbwHfR3q0';
        // return 'https://api.maptiler.com/maps/voyager/256/{z}/{x}/{y}$retina.png?key=yH0AJynJV0qzbwHfR3q0';
  }

  // final mapUrl = 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.post.imgurl != null) {
      precacheImage(
        NetworkImage(widget.post.imgurl!),
        context,
      );
    }
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post.id != widget.post.id) {
      _imageLoaded = false;
      _participantIds = List<String>.from(widget.participantIds);
    }
  }

  void _scheduleMapReveal() {
    _mapRevealTimer?.cancel();
    _mapRevealTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _mapReady = true);
    });
  }

  Future<void> loadAll() async {
    try {
    final results = await Future.wait([
      supabase
          .from('activity_participants')
          .select('id')
          .eq('post_id', widget.post.id)
          .eq('user_id', supabase.auth.currentUser!.id)
          .maybeSingle() as Future<dynamic>,
    ]);
      final joinedRes = results[0];

      List<String> avatars = [];
      if (widget.participantIds.isNotEmpty) {
        final avatarRes = await supabase
            .from('profiles')
            .select('avatar_url, username')
            .filter('id', 'in', widget.participantIds);

        avatars = (avatarRes as List)
            .map((a) => a['avatar_url'] as String)
            .toList();
      }

      setState(() {
        _participantAvatars = [
          ...avatars,
          ...debugParticipants
        ];
        _participantIds = List<String>.from(widget.participantIds);
        _joined = joinedRes != null;
        isReady = true;
      });

    } catch (e) {
      debugPrint("loadAll error: $e");
    }
  }

  Future<void> _refreshParticipants() async {
    try {
      final userIds = await fetchParticipants(); // already filters status == 'joined'

      List<String> avatars = [];
      if (userIds.isNotEmpty) {
        final avatarRes = await supabase
            .from('profiles')
            .select('avatar_url')
            .filter('id', 'in', userIds);

        avatars = (avatarRes as List)
            .map((a) => a['avatar_url'] as String)
            .toList();
      }

      final joinedRes = await supabase
          .from('activity_participants')
          .select('id')
          .eq('post_id', widget.post.id)
          .eq('user_id', supabase.auth.currentUser!.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _participantIds = userIds;
        _participantAvatars = [
          ...avatars,
          ...debugParticipants,
        ];
        _joined = joinedRes != null;
      });
    } catch (e) {
      debugPrint('Error refreshing participants: $e');
    }
  }

  Future<List<String>> fetchParticipants() async {
    try {
      final response = await supabase
          .from ('activity_participants')
          .select ('user_id')
          .eq('post_id', widget.post.id)
          .eq('status', 'joined');

      final List<String> userIds = (response as List)
          .map((row) => row['user_id'] as String)
          .toList();

      return userIds;
    }
    catch (e) {
      debugPrint('Error fetching participants: $e');
      return [];
    }
  }

  Future<void> fetchParticipantAvatars() async {
    try {
      final userIds = await fetchParticipants();

      final response = await supabase
          .from('profiles')
          .select('avatar_url')
          .filter('id', 'in', userIds);

      final List<String> avatarUrls = (response as List)
          .map((row) => row['avatar_url'] as String)
          .toList();

      setState(() {
        _participantAvatars = [
          ...avatarUrls,
          ...debugParticipants
        ];
      });
    }
    catch (e) {
      debugPrint('Error fetching participant avatars: $e');
    }
  }

  String formatPostAge(dynamic createdAt) {
    if (createdAt == null) return "";

    DateTime created;
    if (createdAt is DateTime) {
      created = createdAt.toLocal();
    } else {
      created = DateTime.parse(createdAt.toString()).toLocal();
    }
    final diff = DateTime.now().difference(created);

    if (diff.inMinutes < 60) {
      final m = diff.inMinutes == 0 ? 1 : diff.inMinutes;
      return "Vor $m Minute${m > 1 ? "n" : ""}";
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return "Vor $h Stunde${h > 1 ? "n" : ""}";
    }

    final d = diff.inDays;
    return "Vor $d Tag${d > 1 ? "en" : ""}";
  }

  Widget _buildLocationNotice({bool show = true}) {
    if (!show) return const SizedBox.shrink();

    return Positioned(
      top: 14,
      right: 14,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _locationNoticeExpanded = !_locationNoticeExpanded;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: _locationNoticeExpanded ? 12 : 0,
            vertical: _locationNoticeExpanded ? 9 : 0,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _locationNoticeExpanded
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: Colors.black87,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Beitreten um genauen Treffpunkt zu sehen',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  )
                : const SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 17,
                      color: Colors.black87,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Builds the map view. When [asAspectRatioBox] is true the map wraps
  /// itself in a 4:3 AspectRatio box (used for map-only posts, which are
  /// unchanged). When false, the caller (the carousel) is responsible for
  /// sizing it via a fixed-size parent.
  Widget _buildMap({
    double initialZoom = 13,
    bool showMarker = true,
    bool showLocationMarker = true,
    bool asAspectRatioBox = true,
  }) {
    final location = (widget.post.latitude != null && widget.post.longitude != null)
        ? LatLng(widget.post.latitude!, widget.post.longitude!)
        : LatLng(0.0, 0.0);

    final content = Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: location,
            initialZoom: initialZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
          TileLayer(
            urlTemplate: _mapUrl,
            userAgentPackageName: 'com.robert.app',
            // maxNativeZoom: 20, // let MapTiler serve its sharpest available tile
            tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 250)),
          ),
            if (showMarker && widget.post.latitude != null && widget.post.longitude != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: location,
                    width: MapPinMarker.bodyDiameter,
                    height: MapPinMarker.bodyDiameter + MapPinMarker.tailHeight,
                    alignment: Alignment.topCenter,
                    child:
                    widget.post.activity == null
                    ? MapPinMarker(activity: "Run")
                    : widget.post.activity == "Run"
                      ? MapPinMarker(activity: "Run")
                      : MapPinMarker(activity: "Bike")
                  ),
                ],
              )
          ],
        ),
        if (showLocationMarker)
          _buildLocationNotice(),

        // Shimmer covers the map until the reveal window closes,
        // then fades out. IgnorePointer while showing so it doesn't
        // swallow taps meant for the map/card underneath.
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

    if (!asAspectRatioBox) return content;
    return AspectRatio(aspectRatio: 4 / 3, child: content);
  }

  Widget buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      period: const Duration(milliseconds: 1200),
      child: Container(
        color: Colors.grey.shade300,
      ),
    );
  }

  /// Builds the image view. When [asAspectRatioBox] is true it wraps
  /// itself in a 1:1 AspectRatio box. When false, the caller (the
  /// carousel) sizes it via a fixed-size parent. [renderWidth] lets the
  /// caller pass the actual on-screen width so the network cache size
  /// matches what's really displayed instead of the full device width.
  Widget _buildImage({bool asAspectRatioBox = true, double? renderWidth}) {
    final targetWidth = renderWidth ?? MediaQuery.of(context).size.width;
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: widget.post.imgurl!,
            fit: BoxFit.cover,
            memCacheWidth: (targetWidth * MediaQuery.of(context).devicePixelRatio).round(),
            filterQuality: FilterQuality.low,
            fadeInDuration: Duration.zero,      // you already have your own shimmer transition; avoid double-fade
            fadeOutDuration: Duration.zero,
            placeholder: (context, url) => const _ShimmerPlaceholder(),
            errorWidget: (context, url, error) {
              return Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined, size: 32, color: Colors.grey),
                ),
              );
            },
          ),
        ],
      ),
    );

    if (!asAspectRatioBox) return content;
    return AspectRatio(aspectRatio: 1 / 1, child: content);
  }

  Widget _buildChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color.fromARGB(61, 0, 0, 0)),
        const SizedBox(width: 4),
        Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _openActivity() async {
    final refreshPost = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) {
          return ActivityPage(
            postId: widget.post.id,
            userDistance: widget.post.userdistance,
          );
        },
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: Container(
              color: Colors.black,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );

    if (!mounted) return;

    await _refreshParticipants();
  }

  // Snaps the carousel to whichever side (image / map) is closer once a
  // scroll gesture ends, and notifies the parent so its state stays in
  // sync with what's actually showing.
  void _snapCarousel(double maxScrollExtent) {
    if (!_carouselController.hasClients || maxScrollExtent <= 0) return;
    final offset = _carouselController.offset.clamp(0.0, maxScrollExtent);
    final showingImage = offset < maxScrollExtent / 2;
    if (showingImage != _carouselShowingImage) {
      _carouselShowingImage = showingImage;
      widget.onToggle(showingImage);
    }
  }

  Widget _buildDot(double activeness) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 6 + 4 * activeness,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5 + 0.5 * activeness),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselIndicator(double maxScrollExtent) {
    return Positioned(
      bottom: 14,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _carouselController,
            builder: (context, _) {
              double t = 0;
              if (_carouselController.hasClients && maxScrollExtent > 0) {
                t = (_carouselController.offset / maxScrollExtent).clamp(0.0, 1.0);
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDot(1 - t),
                  const SizedBox(width: 6),
                  _buildDot(t),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Small fading chevron sitting right where the map starts to peek
  // through, hinting that there's more to swipe to. Fades out as soon
  // as the user starts dragging towards the map.
  Widget _buildCarouselHint(double imageWidth) {
    return Positioned(
      left: imageWidth - 28,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _carouselController,
          builder: (context, _) {
            double t = 0;
            if (_carouselController.hasClients &&
                _carouselController.position.hasContentDimensions &&
                _carouselController.position.maxScrollExtent > 0) {
              t = (_carouselController.offset /
                      _carouselController.position.maxScrollExtent)
                  .clamp(0.0, 1.0);
            }
            // Fade out within the first ~30% of the swipe instead of
            // over the whole gesture, so it doesn't appear to travel
            // along with the sliding content.
            final fadeProgress = (t / 0.3).clamp(0.0, 1.0);
            return Center(
              child: Opacity(
                opacity: (1 - fadeProgress) * 0.85,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

    // Mirror of _buildCarouselHint: sits just inside the map, hinting you
  // can swipe back to the image. Visible near the map side, fades out
  // quickly within the first ~30% of the swipe back towards the image.
  Widget _buildCarouselHintReverse(double imageWidth, double gap) {
    return Positioned(
      left: gap + 28,
      top: 0,
      bottom: 0,
      width: 26,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _carouselController,
          builder: (context, _) {
            double t = 0;
            if (_carouselController.hasClients &&
                _carouselController.position.hasContentDimensions &&
                _carouselController.position.maxScrollExtent > 0) {
              t = (_carouselController.offset /
                      _carouselController.position.maxScrollExtent)
                  .clamp(0.0, 1.0);
            }
            final distanceFromMapSide = 1 - t;
            final fadeProgress = (distanceFromMapSide / 0.3).clamp(0.0, 1.0);
            return Center(
              child: Opacity(
                opacity: (1 - fadeProgress) * 0.85,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The media section for posts with an image: a fixed 4:3 box holding
  /// a horizontally swipeable strip. The image renders at 1:1 (square),
  /// which leaves a sliver of the map peeking in on the right, with a
  /// thin white gap between them. Swiping snaps between the two states.
  Widget _buildImageMapCarousel() {
    const double gap = 12;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double boxHeight = constraints.maxHeight;
          final double boxWidth = constraints.maxWidth;
          final double imageWidth = boxHeight; // 1:1 square
          final double maxScrollExtent = imageWidth + gap;

          if (!_carouselInitialPositionApplied) {
            _carouselInitialPositionApplied = true;
            if (!widget.showImageMain) {
              _carouselShowingImage = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_carouselController.hasClients) return;
                _carouselController.jumpTo(maxScrollExtent);
              });
            }
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollEndNotification) {
                    _snapCarousel(maxScrollExtent);
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _carouselController,
                  scrollDirection: Axis.horizontal,
                  physics: const _CarouselSnapPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: imageWidth,
                        height: boxHeight,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(22),
                            bottomRight: Radius.circular(22),
                          ),
                          child: _buildImage(
                            asAspectRatioBox: false,
                            renderWidth: imageWidth,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: gap,
                        height: boxHeight,
                        child: const ColoredBox(color: Colors.transparent),
                      ),
                      SizedBox(
                        width: boxWidth,
                        height: boxHeight,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(22),
                            bottomLeft: Radius.circular(22),
                          ),
                          child: _buildMap(asAspectRatioBox: false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // _buildCarouselHint(imageWidth),
              // _buildCarouselHintReverse(imageWidth, gap),
              _buildCarouselIndicator(maxScrollExtent),
            ],
          );
        },
      ),
    );
  }

  // initial fetch when page is first opened
  @override
  void initState() {
    super.initState();
    _carouselShowingImage = widget.showImageMain;
    _participantIds = List<String>.from(widget.participantIds);
    loadAll();
    // Kick off the map's shimmer-to-reveal window once per card, right
    // away — regardless of whether the map or the image is the main
    // view right now, since the map is also rendered as part of the
    // carousel when the image is main.
    _scheduleMapReveal();
  }

  @override
  void dispose() {
    _mapRevealTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.white,
            child: InkWell(
              onTap: _openActivity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  15, // left
                  5, // top
                  15, // right
                  10, // bottom
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: profile iamge + title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfilePage(
                                profileId: widget.post.creatorId,
                              ),
                            ),
                          );
                        },
                        child: UserAvatar(
                          imageUrl: widget.avatarUrlCreator,
                          name: widget.usernameCreator,
                          userId: widget.post.creatorId,
                          radius: 20,
                        ),
                      ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.usernameCreator,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              (widget.post.town != null ? "${widget.post.town}" : "none") +
                              (widget.post.userdistance != null
                                  ? (widget.post.userdistance! >= 1000
                                      ? "$bullet${(widget.post.userdistance! / 1000).round()}\u00A0km entfernt"
                                      : "$bullet${widget.post.userdistance!.round()}\u00A0m entfernt")
                                  : "$bullet none"),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: widget.post.activity == "Run"
                            ? const Icon(
                                Icons.directions_run,
                                color: Colors.white,
                                size: 18,
                              )
                            : widget.post.activity == "Bike"
                              ? const Icon(
                                Icons.directions_bike,
                                color: Colors.white,
                                size: 18,
                                )
                              : null,
                        ),
                      ]
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.post.title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ((widget.post.startsAt != null)
                              ? dataFormatter.formatActivityDate(DateTime.parse(widget.post.startsAt!)) == "Heute" || dataFormatter.formatActivityDate(DateTime.parse(widget.post.startsAt!)) == "Morgen"
                                ? "${dataFormatter.formatActivityDate(DateTime.parse(widget.post.startsAt!))} $bullet ${dataFormatter.formatTime(DateTime.parse(widget.post.startsAt!))}"
                                : "${dataFormatter.formatActivityDate(DateTime.parse(widget.post.startsAt!))} $bullet ${dataFormatter.activityRelativeTime(DateTime.parse(widget.post.startsAt!))}"
                              : "none"),
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        )
                      ],
                    ),
                    const SizedBox(height:12),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ParticipantsPage(postId: widget.post.id),
                              ),
                            );
                          },
                          child: buildParticipantStack(_participantAvatars, (_participantIds.length + debugParticipants.length))
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _buildChip(Icons.route, widget.post.distance != null ? "${dataFormatter.formatDistance(widget.post.distance!)} km" : "-"),
                            const SizedBox(width: 8),
                            _buildChip(Icons.speed,
                              widget.post.activity == "Run" ?
                                widget.post.pace != null ? dataFormatter.formatPace(widget.post.pace!) : "-"
                                : widget.post.activity == "Bike" ?
                                  widget.post.speed != null ? "${widget.post.speed!.toString()} km/h" : "-"
                                  : "-"),
                          ],
                        ),
                        const SizedBox(width: 12),
                      ]
                    ),
                    const SizedBox(height:5),
                  ]
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(0),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                    color: Colors.black.withOpacity(0.06),
                  ),
                ],
              ),
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: widget.post.imgurl != null
                      // Image + map, swipeable, both inside a fixed 4:3 box.
                      ? _buildImageMapCarousel()
                      // No image -> only map, unchanged.
                      : _buildMap(),
                ),
              )
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              15, // left
              6, // top
              15, // right
              0, // bottom
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((widget.post.description ?? "").isNotEmpty) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final username = widget.usernameCreator;
                      final description = widget.post.description ?? "";
                      const usernameStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 15);
                      const descStyle = TextStyle(fontSize: 14);
                      const moreText = " … Mehr anzeigen";

                      final fullTextPainter = TextPainter(
                        text: TextSpan(
                          children: [
                            TextSpan(text: username, style: usernameStyle),
                            TextSpan(text: "\u00A0"),
                            TextSpan(text: description, style: descStyle),
                          ],
                        ),
                        maxLines: 2,
                        textDirection: TextDirection.ltr,
                      )..layout(maxWidth: constraints.maxWidth);

                      final exceedsTwoLines = fullTextPainter.didExceedMaxLines;

                      String visibleDescription = description;
                      if (!_descExpanded && exceedsTwoLines) {
                        final charList = description.characters;
                        int endIndex = charList.length;
                        int bestIndex = 0;

                        while (endIndex > 0) {
                          final tp = TextPainter(
                            text: TextSpan(
                              children: [
                                TextSpan(text: username, style: usernameStyle),
                                TextSpan(text: "\u00A0"),
                                TextSpan(
                                  text: charList.take(endIndex).toString(),
                                  style: descStyle,
                                ),
                                TextSpan(
                                  text: moreText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            textDirection: TextDirection.ltr,
                          )..layout(maxWidth: constraints.maxWidth);

                          if (!tp.didExceedMaxLines) {
                            bestIndex = endIndex;
                            break;
                          }

                          endIndex--;
                        }
                        visibleDescription = charList.take(bestIndex).toString();
                      }
                      return GestureDetector(
                        onTap: exceedsTwoLines
                            ? () => setState(() => _descExpanded = !_descExpanded)
                            : null,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: username, style: usernameStyle),
                              TextSpan(text: "\u00A0"),
                              TextSpan(
                                text: _descExpanded
                                    ? description
                                    : visibleDescription,
                                style: descStyle,
                              ),
                              if (!_descExpanded && exceedsTwoLines)
                                const TextSpan(
                                  text: moreText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: _descExpanded ? null : 2,
                          overflow: TextOverflow.clip,
                        ),
                      );
                    },
                  )
                ],
                const SizedBox(height: 6),
                Text(
                 formatPostAge(widget.post.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  )
                ),
              ]
            )
          )
        ]
      )
    );
  }
}
