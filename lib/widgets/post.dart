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
        _joined = joinedRes != null;
        isReady = true;
      });

    } catch (e) {
      debugPrint("loadAll error: $e");
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

  Widget _buildMap({double initialZoom = 13, bool showMarker = true, bool showLocationMarker = true}) {
    final location = (widget.post.latitude != null && widget.post.longitude != null)
        ? LatLng(widget.post.latitude!, widget.post.longitude!)
        : LatLng(0.0, 0.0);

    return AspectRatio(
      aspectRatio: widget.post.imgurl != null ? 1 / 1 : 4 / 3,
      child: Stack(
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
      ),
    );
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

  Widget _buildImage() {
    return AspectRatio(
      aspectRatio: 1 / 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.post.imgurl!,
              fit: BoxFit.cover,
              cacheWidth: (MediaQuery.of(context).size.width *
                      MediaQuery.of(context).devicePixelRatio)
                  .round(),
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              loadingBuilder: (context, child, progress) {
                final loading = progress != null;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    child,

                    if (loading)
                      const _ShimmerPlaceholder(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
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

  // Widget _buildChip(IconData icon, String label) {
  //   return Row(
  //     mainAxisSize: MainAxisSize.min,
  //     children: [
  //       Icon(
  //         icon,
  //         size: 18,
  //         color: Colors.grey.shade600,
  //       ),
  //       const SizedBox(width: 5),
  //       Text(
  //         label,
  //         style: TextStyle(
  //           fontSize: 13,
  //           fontWeight: FontWeight.w600,
  //           color: Colors.grey.shade700,
  //         ),
  //       ),
  //     ],
  //   );
  // }

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
  }

  // initial fetch when page is first opened
  @override
  void initState() {
    super.initState();
    loadAll();
    // Kick off the map's shimmer-to-reveal window once per card, right
    // away — regardless of whether the map or the image is the main
    // view right now, since the map is also rendered as the small
    // corner preview when the image is main.
    _scheduleMapReveal();
  }

  @override
  void dispose() {
    _mapRevealTimer?.cancel();
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
                          child: buildParticipantStack(_participantAvatars, (widget.participantIds.length + debugParticipants.length))
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
                      ? Stack(
                          children: [
                            // Main media
                            widget.showImageMain
                              ? _buildImage()
                              : _buildMap(), 
                            // Small floating preview
                            Positioned(
                              bottom: 14,
                              left: 14,
                              child: GestureDetector(
                                onTap: () {
                                  widget.onToggle(!widget.showImageMain);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: SizedBox(
                                      width: 76,
                                      height: 76,
                                      child: widget.showImageMain
                                            ? IgnorePointer(
                                                child: _buildMap(
                                                  initialZoom: 10,
                                                  showMarker: false,
                                                  showLocationMarker: false,
                                                ),
                                              )
                                          : Image.network(
                                              widget.post.imgurl!,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      // No image -> only map
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
