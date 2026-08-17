import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/data_formatter.dart';
// import 'package:characters/characters.dart';
import '../widgets/participant_stack.dart';
import '../widgets/map_pointer.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../activity_page.dart';
import '../models/post.dart';
import 'package:shimmer/shimmer.dart';
final supabase = Supabase.instance.client;

class PostHistory extends StatefulWidget {
  final Post post;

  const PostHistory({
    super.key,
    required this.post,
  });
  @override
  State<PostHistory> createState() => _PostHistoryState();
}

class _PostHistoryState extends State<PostHistory> with RouteAware, AutomaticKeepAliveClientMixin {
  String? _avatarUrl;
  String? _profileName;
  Map<String, bool> showImageMap = {};
  final dataFormatter = DataFormatter();
  // bool _descExpanded = false;
  // bool _joined = false;
  // bool _loadingJoin = false;
  List<String> _participantAvatars = [];
  List<String> debugParticipants = [
    'https://i.pravatar.cc/40?img=11',
    'https://i.pravatar.cc/40?img=7',
    'https://i.pravatar.cc/40?img=8',
    'https://i.pravatar.cc/40?img=9',
    'https://i.pravatar.cc/40?img=10'];
  final bullet = " •\u200B ";
  bool _imageLoaded = false;

  // final mapUrl = 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/basic-v2-light/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/voyager-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/topo-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';

  String get mapUrl {
    return 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  }

  bool get isPast {
    final dt = DateTime.tryParse("${widget.post.date} ${widget.post.time}") ?? DateTime.now();
    return dt.isBefore(DateTime.now());
  }

  Future<void> fetchProfile() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('avatar_url, username')
          .eq('id', widget.post.creatorId)
          .single();

      setState(() {
        _avatarUrl = response['avatar_url'] as String?;
        _profileName = response['username'] as String?;
      });
    } catch (e) {
      debugPrint('Error fetching profile image on post');
    }
  }

  Future<List<String>> fetchParticipants() async {
    try {
      final response = await supabase
          .from ('activity_participants')
          .select ('user_id')
          .eq('post_id', widget.post.id); // filter for this post

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

  Widget _buildMap({double initialZoom = 12, bool showMarker = true}) {
    if (widget.post.latitude == null || widget.post.longitude == null) {
      return Container(
        width: 70,
        height: 70,
        color: Colors.grey.shade100,
      );
    }

    final location = LatLng(
      widget.post.latitude!,
      widget.post.longitude!,
    );

    return FlutterMap(
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
      ],
    );
  }

  // initial fetch when page is first opened
  @override
  void initState() {
    super.initState();
    fetchProfile(); // fetch avatar from Supabase on page load
    fetchParticipantAvatars();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityPage(
              postId: widget.post.id,
              userDistance: widget.post.userdistance,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              // LEFT: small visual (optional image/map)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: widget.post.imgurl != null
                      ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            widget.post.imgurl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              final isLoading = progress != null;

                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  child,

                                  if (isLoading)
                                    Shimmer.fromColors(
                                      baseColor: Colors.grey.shade300,
                                      highlightColor: Colors.grey.shade100,
                                      child: Container(color: Colors.grey.shade300),
                                    ),
                                ],
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                        ],
                      )
                      : _buildMap(initialZoom: 10),
                ),
              ),

              const SizedBox(width: 12),

              // RIGHT: content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TITLE
                    Text(
                      widget.post.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isPast ? Colors.grey[700] : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // DATE
                    Text(
                      widget.post.startsAt != null
                          ? "${dataFormatter.formatActivityDate(
                                DateTime.parse(widget.post.startsAt!).toLocal(),
                              )} • ${dataFormatter.formatTime(
                                DateTime.parse(widget.post.startsAt!).toLocal(),
                              )} Uhr"
                          : "—",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // META ROW
                    Row(
                      children: [
                        // if(widget.post.distance != null) ...[
                        //   _meta("${dataFormatter.formatDistance(widget.post.distance ?? 0)} km"),
                        // ],
                        // if(widget.post.pace != null) ...[
                        //   const SizedBox(width: 8),
                        //   _meta(dataFormatter.formatPace(widget.post.pace ?? 0)),
                        // ],
                        const Spacer(),

                        if (widget.post.creatorId == supabase.auth.currentUser!.id)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPast ? Colors.grey.shade200 : Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Erstellt",
                              style: TextStyle(
                                fontSize: 10,
                                color: isPast ? Colors.black87 : Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: Colors.grey[600],
      ),
    );
  }
}