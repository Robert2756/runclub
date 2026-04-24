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

  // final mapUrl = 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  final mapUrl = 'https://api.maptiler.com/maps/basic-v2-light/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/voyager-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/topo-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';

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

  Widget _buildMap({double initialZoom = 13, bool showMarker = true}) {
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
                if (widget.post.latitude != null && widget.post.longitude != null)
                  Marker(
                    point: LatLng(widget.post.latitude!, widget.post.longitude!),
                    width: 42,
                    height: 46,
                    alignment: Alignment.topCenter,
                    child: CustomPaint(
                      painter: RunMarkerPainter(),
                      child: const SizedBox(
                        width: 42,
                        height: 46,
                        child: Center(
                          child: Icon(
                            Icons.directions_run,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
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

    final isPast = widget.post.group != "Upcoming";

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
            color: isPast ? Colors.grey[100] : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPast ? Colors.grey.shade300 : Colors.grey.shade200,
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
                      ? Image.network(widget.post.imgurl!, fit: BoxFit.cover)
                      : _buildMap(initialZoom: 12),
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
                      "${DateFormat('EEE, d MMM', 'de_DE').format(DateTime.parse(widget.post.date!))}"
                      "${widget.post.time != null ? " • ${widget.post.time!.substring(0,5)}" : ""}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),

                    const SizedBox(height: 6),

                    // META ROW
                    Row(
                      children: [
                        _meta("${dataFormatter.formatDistance(widget.post.distance ?? 0)} km"),
                        const SizedBox(width: 8),
                        _meta(dataFormatter.formatPace(widget.post.pace ?? 0)),
                        const Spacer(),

                        if (!isPast)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "Joined",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
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
        fontSize: 12,
        color: Colors.grey[700],
        fontWeight: FontWeight.w500,
      ),
    );
  }
}