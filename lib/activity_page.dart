import 'package:flutter/material.dart';
import 'models/post.dart';
import 'widgets/post.dart';
import 'widgets/app_bar.dart';
import 'profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'widgets/map_pointer.dart';
import 'widgets/participant_stack.dart';
import 'services/data_formatter.dart';
import 'participant_page.dart';
import 'widgets/chat.dart';
final supabase = Supabase.instance.client;

enum ActivityMode {
  details,
  chat,
}

class ActivityPage extends StatefulWidget {
  final String postId;
  final int? userDistance;

  const ActivityPage({
    super.key,
    required this.postId,
    required this.userDistance,
  });

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  Post? post;
  List<String> participants = [];
  bool isJoined = false;
  bool loading = false;
  bool _joined = false;
  bool _loadingJoin = false;
  List<String> participantAvatars = [];
  List<String> debugParticipants = [
    'https://i.pravatar.cc/40?img=11',
    'https://i.pravatar.cc/40?img=7',
    'https://i.pravatar.cc/40?img=8',
    'https://i.pravatar.cc/40?img=9',
    'https://i.pravatar.cc/40?img=10'];
  String? _avatarUrl;
  String? _profileName;
  final dataFormatter = DataFormatter();
  final bullet = " •\u200B ";
  ActivityMode _mode = ActivityMode.details;
  static ActivityMode _lastMode = ActivityMode.details;
  final DraggableScrollableController _sheetController =
    DraggableScrollableController();

  final mapUrl = 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/basic-v2-light/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/voyager-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/topo-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';

  Future<void> checkJoined() async {
    try {
      final res = await supabase
          .from('activity_participants')
          .select('id')
          .eq('post_id', post!.id)
          .eq('user_id', supabase.auth.currentUser!.id)
          .maybeSingle();

      setState(() => _joined = res != null);
    } catch (e) {
      debugPrint('Error checking join status: $e');
    }
  }

  Future<void> loadActivity() async {
    final response = await supabase
        .from('posts')
        .select()
        .eq('id', widget.postId)
        .single();

    final loadedPost = Post(
      id: response['id'].toString(),
      title: response['title'],
      creatorId: response['creator_id'],
      imgurl: response['image_url'],
      description: response['description'],
      activity: response['activity'],
      distance: response['distance'],
      pace: response['pace'],
      date: response['date'],
      time: response['time'],
      latitude: (response['latitude'] as num?)?.toDouble(),
      longitude: response['longitude']?.toDouble(),
      town: response['town'],
      createdAt: response['created_at'],
      userdistance: widget.userDistance
    );

    final results = await Future.wait([
      supabase
          .from('activity_participants')
          .select('user_id')
          .eq('post_id', loadedPost.id)
          .then((value) => value),

      supabase
          .from('activity_participants')
          .select('id')
          .eq('post_id', loadedPost.id)
          .eq('user_id', supabase.auth.currentUser!.id)
          .maybeSingle()
          .then((value) => value),
    ]);

    final participantsRes = results[0] as List;
    final joinedRes = results[1];

    final userIds = participantsRes
        .map((e) => e['user_id'].toString())
        .toList();

    // 👇 fetch avatars AFTER you have participants
    final avatarsRes = userIds.isEmpty
        ? []
        : await supabase
            .from('profiles')
            .select('avatar_url')
            .filter('id', 'in', userIds);

    final avatarUrls = (avatarsRes)
        .map((e) => e['avatar_url'] as String)
        .toList();
    
    final responseProfile = await supabase
      .from('profiles')
      .select('avatar_url, username')
      .eq('id', loadedPost.creatorId)
      .single();

    // ✅ ONE setState → no flicker
    setState(() {
      post = loadedPost;
      participants = userIds;
      _joined = joinedRes != null;
      participantAvatars = [
        ...avatarUrls,
        ...debugParticipants,
      ];
      _avatarUrl = responseProfile['avatar_url'] as String?;
      _profileName = responseProfile['username'] as String?;
    });
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
        participantAvatars = [
          ...avatarUrls, // at to beginning
          ...debugParticipants // DEBUGGING
        ];
      });
    }
    catch (e) {
      debugPrint('Error fetching participant avatars: $e');
    }
  }

  Future<List<String>> fetchParticipants() async {
    try {
      final response = await supabase
          .from ('activity_participants')
          .select ('user_id')
          .eq('post_id', post!.id); // filter for this post

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

  Future<void> toggleJoin() async {
    if (_loadingJoin) return; // prevent multiple taps
    setState(() => _loadingJoin = true);

    try {
      if (!_joined) {
        // join activity
        await supabase.from('activity_participants').insert({
          'post_id': post!.id,
          'user_id': supabase.auth.currentUser!.id,
        });
      } else {
        // optionally leave activity
        await supabase.from('activity_participants')
            .delete()
            .eq('post_id', post!.id)
            .eq('user_id', supabase.auth.currentUser!.id);
      }

      // toggle joined state -> update button UI immediately
      setState(() => _joined = !_joined);

      // imediately refresh participant avatars after joining/leaving
      await fetchParticipantAvatars();

    } catch (e) {
      debugPrint('Error toggling join: $e');
      // optionally show a SnackBar or toast
    } finally {
      setState(() => _loadingJoin = false);
    }
  }

  @override
  void initState() {
    super.initState();
    loadActivity();
    _mode = _lastMode;
    // fetchProfileImage();
  }

  Widget _buildMap({double initialZoom = 13, bool showMarker = true}) {
    final location = (post!.latitude != null && post!.longitude != null)
        ? LatLng(post!.latitude!, post!.longitude!)
        : LatLng(0.0, 0.0);

    return AspectRatio(
      aspectRatio: post!.imgurl != null ? 1 / 1 : 4 / 3,
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
          if (showMarker && post!.latitude != null && post!.longitude != null)
            MarkerLayer(
              markers: [
                if (post!.latitude != null && post!.longitude != null)
                  Marker(
                    point: LatLng(post!.latitude!, post!.longitude!),
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

  Widget _buildHero() {
    final size = MediaQuery.of(context).size;
    final heroHeight = size.height * 0.40; // feels modern (airbnb-ish)

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // background
          post!.imgurl != null
              ? Image.network(
                  post!.imgurl!,
                  fit: BoxFit.cover,
                )
              : _buildMap(initialZoom: 13),

          // gradient overlay (stronger bottom readability)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildDetails(ScrollController controller) {
  //   return ListView(
  //     controller: controller,
  //     physics: _mode == ActivityMode.chat
  //       ? const NeverScrollableScrollPhysics()
  //       : const ClampingScrollPhysics(),
  //     padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
  //     children: [
  //       _buildHeader(),
  //       _buildQuickStats(),
  //       const SizedBox(height: 22),
  //       _buildParticipants(),
  //       const SizedBox(height: 16),
  //       _buildDescription(),
  //       const SizedBox(height: 40),
  //     ],
  //   );
  // }

  Widget _buildDetails(ScrollController controller) {
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeader(),
              _buildQuickStats(),
              const SizedBox(height: 22),
              _buildParticipants(),
              const SizedBox(height: 16),
              _buildDescription(),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _tab(String label, ActivityMode target) {
    final active = _mode == target;
    return GestureDetector(
      // onTap: () => setState(() => _mode = target),
      onTap: () {
        setState(() {
          _mode = target;
          _lastMode = target;
        });

        _sheetController.animateTo(
          target == ActivityMode.chat ? 0.88 : 0.70,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _modeSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _tab("Details", ActivityMode.details),
          const SizedBox(width: 8),
          _tab("Chat", ActivityMode.chat),
        ],
      ),
    );
  }

  Widget _buildContent(ScrollController controller) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // 🧭 drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // 🔀 MODE SWITCH (NEW)
          _modeSwitch(),

          const SizedBox(height: 8),

          // 📦 DYNAMIC CONTENT AREA
          Expanded(
            child: _mode == ActivityMode.details
                ? _buildDetails(controller)
                : ActivityChat(
                    activityId: post!.id,
                  ),
          ),
        ],
      ),
    );
  }

  // Widget _buildChat(ScrollController controller) {
  //   return Column(
  //     children: [
  //       Expanded(
  //         child: ListView(
  //           controller: controller,
  //           padding: const EdgeInsets.all(12),
  //           children: const [
  //             // _ChatMessage("Alex: bringing water 👍"),
  //             // _ChatMessage("Mia: 5 min late ⏱"),
  //             // _ChatMessage("Jonas: meet at entrance"),
  //           ],
  //         ),
  //       ),
  //       // _chatInput(),
  //     ],
  //   );
  // }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
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
                      profileId: post!.creatorId,
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 20,
                backgroundImage: _avatarUrl != null
                    ? NetworkImage(_avatarUrl!)
                    : const NetworkImage(
                        "https://media.istockphoto.com/id/2221502929/de/vektor/flache-abbildung-in-graustufen-avatar-benutzerprofil-personensymbol-geschlechtsneutrale.jpg",
                      ),
              ),
            ),
              const SizedBox(width: 8),
              Text(
                _profileName ?? "Username",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_run,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ]
          ),
          const SizedBox(height: 10),
          Text(
            post!.title,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  (post!.town != null ? "${post!.town}" : "none") +
                  (post!.userdistance != null
                      ? (post!.userdistance! >= 1000
                          ? "$bullet${(post!.userdistance! / 1000).round()}\u00A0km"
                          : "$bullet${post!.userdistance!.round()}\u00A0m")
                      : "$bullet none"),
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
        ]
      )
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _stat(
                  "Distanz",
                  post!.distance != null
                      ? "${dataFormatter.formatDistance(post!.distance!)} km"
                      : "-",
                ),
              ),
              Expanded(
                child: _stat(
                  "Pace",
                  post!.pace != null
                      ? dataFormatter.formatPace(post!.pace!)
                      : "-",
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _stat(
                  "Wochentag",
                  (post!.date != null && post!.time != null)
                      ? dataFormatter.formatWeekday(post!.date!, post!.time!)
                      : "-",
                )
              ),
              Expanded(
                child: _stat(
                  "Uhrzeit",
                  (post!.date != null && post!.time != null)
                      ? "${dataFormatter.formatTime(post!.date!, post!.time!)}Uhr"
                      : "—",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget _stat(String label, String value) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         label,
  //         style: TextStyle(fontSize: 12, color: Colors.grey[600]),
  //       ),
  //       const SizedBox(height: 2),
  //       Text(
  //         value,
  //         style: const TextStyle(
  //           fontSize: 14,
  //           fontWeight: FontWeight.w600,
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.8,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipants() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Going",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParticipantsPage(postId: post!.id),
                  ),
                );
              },
              child: Row(
                children: [
                  buildParticipantStack(participantAvatars),
                  const SizedBox(width: 10),
                  Text(
                    "${participants.length} joined",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ]
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                // navigate to full list
              },
              child: ElevatedButton(
                onPressed: _loadingJoin ? null : toggleJoin, // disable button while loading
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: _joined ? Colors.green : Colors.black,
                ),
                child: _loadingJoin
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _joined ? "Joined" : "Join",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              )
            )
          ],
        ),
      ],
    );
  }

  Widget _buildDescription() {
    if ((post!.description ?? "").isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Beschreibung",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),

        Text(
          post!.description!,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[800],
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: post == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _buildHero(),

                DraggableScrollableSheet(
                  // key: ValueKey(_mode),
                  initialChildSize: _mode == ActivityMode.chat ? 0.88 : 0.64,
                  minChildSize: _mode == ActivityMode.chat ? 0.88 : 0.64,
                  maxChildSize: 0.88,
                  builder: (context, scrollController) {
                    return _buildContent(scrollController);
                  },
                ),

                // 🔥 GLOBAL BACK BUTTON (always on top)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 12,
                  child: _buildBackButton(),
                ),
              ],
            ),
    );
  }
}