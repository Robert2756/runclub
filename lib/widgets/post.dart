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

final supabase = Supabase.instance.client;
final dataFormatter = DataFormatter();

class PostCard extends StatefulWidget {
  final Post post;
  final bool showImageMain;
  final ValueChanged<bool> onToggle; // parent is rebuild when calling 
  final String usernameCreator;
  final String avatarUrlCreator;
  final List participantIds;

  const PostCard({
    super.key,
    required this.post,
    required this.showImageMain,
    required this.onToggle,
    required this.usernameCreator,
    required this.avatarUrlCreator,
    required this.participantIds,
  });
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with RouteAware, AutomaticKeepAliveClientMixin {
  final dataFormatter = DataFormatter();
  bool _descExpanded = false;
  bool _joined = false;
  List<String> _participantAvatars = [];
  List<String> debugParticipants = [
    'https://i.pravatar.cc/40?img=11',
    'https://i.pravatar.cc/40?img=7',
    'https://i.pravatar.cc/40?img=8',
    'https://i.pravatar.cc/40?img=9',
    'https://i.pravatar.cc/40?img=10'];
  bool isReady = false;
  final bullet = " •\u200B ";

  final mapUrl = 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/basic-v2-light/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/voyager-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/topo-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';

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
            .select('avatar_url')
            .filter('id', 'in', widget.participantIds);

        avatars = (avatarRes as List)
            .map((a) => a['avatar_url'] as String)
            .toList();
      }

      setState(() {
        _participantAvatars = [
          ...avatars, // at to beginning
          ...debugParticipants // DEBUGGING
        ];
        _joined = joinedRes != null;
        isReady = true;
      });

    } catch (e) {
      debugPrint("loadAll error: $e");
    }
  }

  Future<List<String>> fetchParticipants() async {
    debugPrint("FEEEEEEETCH");
    try {
      final response = await supabase
          .from ('activity_participants')
          .select ('user_id')
          .eq('post_id', widget.post.id) // filter for this post
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
      // if (userIds.isEmpty) return;

      final response = await supabase
          .from('profiles')
          .select('avatar_url')
          .filter('id', 'in', userIds);

      final List<String> avatarUrls = (response as List)
          .map((row) => row['avatar_url'] as String)
          .toList();

      setState(() {
        _participantAvatars = [
          ...avatarUrls, // at to beginning
          ...debugParticipants // DEBUGGING
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

  Widget _buildMap({double initialZoom = 12, bool showMarker = true}) {
    final location = (widget.post.latitude != null && widget.post.longitude != null)
        ? LatLng(widget.post.latitude!, widget.post.longitude!)
        : LatLng(0.0, 0.0);

    return AspectRatio(
      aspectRatio: widget.post.imgurl != null ? 1 / 1 : 4 / 3,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: location,
          initialZoom: initialZoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: mapUrl,
            userAgentPackageName: 'com.robert.app',
          ),
          if (showMarker && widget.post.latitude != null && widget.post.longitude != null)
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
    );
  }

  Widget _buildImage() {
    return AspectRatio(
      aspectRatio: 1 / 1, // 4 / 3, // 1 / 1,
      child: Image.network(
        widget.post.imgurl!,
        fit: BoxFit.cover,
      )
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color.fromARGB(61, 0, 0, 0)), // Colors.black87
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
              color: Colors.black, // <- makes the transition feel dark
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );

    if (!mounted) return;
    debugPrint("returned from ActivityPage: $refreshPost");
    if (refreshPost == true) {
      await fetchParticipantAvatars();
    }
  }

  // initial fetch when page is first opened
  @override
  void initState() {
    super.initState();
    loadAll();
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
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(widget.avatarUrlCreator)
                        ),
                      ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.usernameCreator,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 17,
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
                    // Text(
                    //   widget.post.description!,
                    //   style: TextStyle(
                    //     fontSize: 13,
                    //     fontWeight: FontWeight.w400,
                    //     color: Colors.grey[850],
                    //     height: 1.2, // tighter line spacing
                    //   ),
                    // ),
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
                            _buildChip(Icons.speed, widget.post.pace != null ? dataFormatter.formatPace(widget.post.pace!) : "-"),
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
          // const SizedBox(height: 5),
          // post has image
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: widget.post.imgurl != null
                    ? Stack(
                        children: [
                          // Main media
                          GestureDetector(
                            onTap: () {
                              widget.onToggle(!widget.showImageMain);
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: widget.showImageMain
                                  ? _buildImage()
                                  : _buildMap(),
                            ),
                          ),

                          // Small floating preview
                          Positioned(
                            bottom: 14,
                            left: 14,
                            child: GestureDetector(
                              onTap: () {
                                widget.onToggle(!widget.showImageMain);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(3),
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

                      // Step 1: Detect if text + "Mehr anzeigen" exceeds 2 lines
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

                      // Step 2: If it does, calculate visible substring so "Mehr anzeigen" fits
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
                      // Step 3: Build RichText
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