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
import 'package:url_launcher/url_launcher.dart';
final supabase = Supabase.instance.client;

enum ActivityMode {
  details,
  chat,
}

class SheetPreview extends StatelessWidget {
  final DraggableScrollableController controller;
  final Widget child;

  const SheetPreview({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final size = controller.isAttached ? controller.size : 0.60;

        const min = 0.60;
        const max = 0.88;

        final t = ((size - min) / (max - min)).clamp(0.0, 1.0);
        final opacity = 1.0 - t;

        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
    );
  }
}

class ActivityConfig {
  final String statLabel;
  final String Function(Post post) statValue;

  const ActivityConfig({
    required this.statLabel,
    required this.statValue,
  });
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

class _ActivityPageState extends State<ActivityPage> with SingleTickerProviderStateMixin{
  Post? post;
  List<String> participants = [];
  bool loading = false;
  bool _joined = false;
  bool _requested = false;
  bool _loadingJoin = false;
  bool _mapPrimary = false;
  bool get _canSeeExactLocation => _joined;
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
  
  late final AnimationController _modeController;
  late final Animation<double> _chatOpacity;
  late final Animation<Offset> _chatSlide;
  bool get _isChat => _mode == ActivityMode.chat;
  int get count => participants.length;
  int? unreadCounter;
  Key _chatKey = UniqueKey(); // if key changes -> build ActivityChat new (as it is passed as key)
  Key _detailsKey = UniqueKey();
  bool get _isChatActive => _mode == ActivityMode.chat;

  final mapUrl = 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/backdrop/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/basic-v2-light/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/voyager-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/topo-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';

  // Future<void> checkJoined() async {
  //   try {
  //     final res = await supabase
  //         .from('activity_participants')
  //         .select('id')
  //         .eq('post_id', post!.id)
  //         .eq('user_id', supabase.auth.currentUser!.id)
  //         .maybeSingle();

  //     setState(() => _joined = res != null);
  //   } catch (e) {
  //     debugPrint('Error checking join status: $e');
  //   }
  // }

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
      speed: response['speed'],
      date: response['date'],
      time: response['time'],
      latitude: (response['latitude'] as num?)?.toDouble(),
      longitude: response['longitude']?.toDouble(),
      town: response['town'],
      createdAt: response['created_at'],
      joinMode: response['join_mode'],
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
          .select('status')
          .eq('post_id', loadedPost.id)
          .eq('user_id', supabase.auth.currentUser!.id)
          .maybeSingle()
          .then((value) => value),
    ]);

    final participantsRes = results[0] as List;
    final joinedRes = (results[1] as Map<String, dynamic>?)?["status"] == "joined";
    final requestedRes = (results[1] as Map<String, dynamic>?)?["status"] == "requested";

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
    debugPrint("Fetching worked");
    setState(() {
      post = loadedPost;
      participants = userIds;
      _joined = joinedRes;
      _requested = requestedRes;
      participantAvatars = [
        ...avatarUrls,
        ...debugParticipants,
      ];
      _avatarUrl = responseProfile['avatar_url'] as String?;
      _profileName = responseProfile['username'] as String?;
    });

    // count unread messages from user for this activity
    await _calculateUnread();
  }

  Future<void> _calculateUnread() async {
    if (!_joined || _requested) {return;}

    final userId = supabase.auth.currentUser!.id;
    final res = await supabase
        .from('activity_participants')
        .select('last_read_at')
        .eq('post_id', post!.id)
        .eq('user_id', userId)
        .maybeSingle();

    final lastReadAt = res?['last_read_at'];

    final count = await supabase
        .from('activity_messages')
        .select('message_id')
        .eq('activity_id', post!.id)
        .neq('user_id', userId)
        .gt('created_at', lastReadAt ?? '1970-01-01')
        .count();

    setState(() {
      debugPrint("last read: $lastReadAt");
      debugPrint("Counter: ${count.count}");
      unreadCounter = count.count;
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
    if (_loadingJoin) return;
    setState(() => _loadingJoin = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      if (!_joined && !_requested) {
        if (post!.joinMode == "Instant") {
          // activity join mode "Instant"
          await supabase.from('activity_participants').insert({
            'post_id': post!.id,
            'user_id': userId,
            'last_read_at': null,
            'status': "joined"
          });
          setState(() {
            _joined = true;
            participants.add(userId);
            _chatKey = UniqueKey();
          });
          await _calculateUnread();
          fetchParticipantAvatars();
        } else if (post!.joinMode == "Request") {
          // activity join mode "Request"
          await supabase.from('activity_participants').insert({
            'post_id': post!.id,
            'user_id': userId,
            'last_read_at': null,
            'status': "requested"
          });
          // notify creator
          await supabase.from('notifications').insert({
            'from_user': supabase.auth.currentUser!.id,
            'to_user': post!.creatorId,
            'post_id': post!.id,
            'created_at': DateTime.now().toIso8601String(),
            'type': 'request'
          });
          setState(() {
            _requested = true;
          });
        }
      } else if (_joined && !_requested){
        // LEAVE
        await supabase
            .from('activity_participants')
            .delete()
            .eq('post_id', post!.id)
            .eq('user_id', userId);

        setState(() {
          _joined = false;
          participants.remove(userId);
          _chatKey = UniqueKey();
        });
        await _calculateUnread();
        fetchParticipantAvatars();
      }
    } catch (e) {
      debugPrint('Error toggling join: $e');
    } finally {
      setState(() => _loadingJoin = false);
    }
  }

  @override
  void dispose() {
    _modeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadActivity();
    _mode = ActivityMode.details;

    _modeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _chatOpacity = CurvedAnimation(
      parent: _modeController,
      curve: Curves.easeOut,
    );

    _chatSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _modeController, curve: Curves.easeOut),
    );

  }

  Widget _buildLocationHeader() {
    final isUnlocked = _canSeeExactLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // TITLE ROW
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: Colors.grey,
            ),
            const SizedBox(width: 6),

            Expanded(
              child: Text(
                isUnlocked
                    ? (post!.town ?? "Standort")
                    : "Standort wird nach Beitritt freigeschaltet",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isUnlocked ? Colors.black : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // SECONDARY INFO
        Text(
          isUnlocked
              ? "Exakter Treffpunkt sichtbar"
              : "Grobe Region sichtbar",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMap({double initialZoom = 13, bool showMarker = true}) {
    final location = (post!.latitude != null && post!.longitude != null)
        ? LatLng(post!.latitude!, post!.longitude!)
        : LatLng(0.0, 0.0);

    return FlutterMap(
      key: ValueKey(_joined),
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
                      post!.activity == "Bike"
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
    );
  }

  Widget _buildHero() {
    final size = MediaQuery.of(context).size;
    final heroHeight = size.height * 0.45; // feels modern (airbnb-ish)

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

  Future<void> openInMaps(double lat, double lng) async {
    final url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _blurredLocationField() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.blue.withOpacity(0.25),
            Colors.blue.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 40,
            spreadRadius: 15,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.blur_on,
          color: Colors.white70,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildBlurredLocationMarker() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.withOpacity(0.15),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.25),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.location_on_outlined,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final locked = !_canSeeExactLocation;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // =========================
          // HEADER (same system as others)
          // =========================
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200)
                  ),
                  child: const Icon(
                    Icons.place_outlined,
                    color: Colors.black,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Treffpunkt",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locked
                            ? "Wird nach Beitritt freigeschaltet"
                            : "Exakter Standort sichtbar",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // =========================
          // MAP
          // =========================
          SizedBox(
            height: 220,
            child: Stack(
              children: [

                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  child: _buildMap(
                    initialZoom: locked ? 11 : 14,
                    showMarker: true,
                  ),
                ),

                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // TOP RIGHT BUTTON
                Positioned(
                  top: 14,
                  right: 14,
                  child: GestureDetector(
                    onTap: locked
                        ? null
                        : () => openInMaps(
                              post!.latitude!,
                              post!.longitude!,
                            ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: locked
                            ? Colors.black.withOpacity(0.25)
                            : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.navigation_outlined,
                            size: 16,
                            color: locked ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Maps",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: locked ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // BOTTOM TEXT
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post!.town ?? "Location",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locked
                          ? "Join to unlock meetup point"
                          : (post!.userdistance != null
                            ? (post!.userdistance! >= 1000
                                ? "${(post!.userdistance! / 1000).round()}\u00A0km entfernt"
                                : "${post!.userdistance!.round()}\u00A0m entfernt")
                            : "none"),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Colors.black,
              ),

              const SizedBox(width: 8),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),

          if (subtitle != null) ...[
            // const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDetails(ScrollController controller) {
    final sheetT = (_sheetController.isAttached
      ? _sheetController.size
      : 0.60);
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            75 + MediaQuery.of(context).padding.bottom,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeader(),
              _buildDescription(),
              const SizedBox(height: 20),
              _buildQuickStats(),
              const SizedBox(height: 14),
              _buildParticipantsCard(),
              const SizedBox(height: 14),
              if (post!.latitude != null && post!.longitude != null)
                // const SizedBox(height: 12),
                _buildLocationCard()
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> markChatAsRead() async {
    final userId = supabase.auth.currentUser!.id;
    print("Now: ${DateTime.now().toIso8601String()}");

    await supabase
        .from('activity_participants')
        .update({
          'last_read_at': DateTime.now().toIso8601String(),
        })
        .eq('post_id', post!.id)
        .eq('user_id', userId);
    
    setState(()
    {
      unreadCounter = 0;
    });
  }

  Widget _tab(
    String label,
    ActivityMode target) {
    final active = _mode == target;

    debugPrint("UnreadMessages: $unreadCounter");

    return GestureDetector(
      onTap: () async {

        final wasChat = _mode == ActivityMode.chat;
        final goingToChat = target == ActivityMode.chat;

        setState(() {
          _mode = target;
          _lastMode = target;
        });

        if (goingToChat && !wasChat) {
          _modeController.forward();
          if (_joined) await markChatAsRead();
        } else {
          _modeController.reverse();
        }

        _sheetController.animateTo(
          target == ActivityMode.chat ? 0.88 : 0.60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ======================
          // TAB BODY
          // ======================
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
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

          // ======================
          // FLOATING BADGE
          // ======================
          if ((unreadCounter ?? 0) > 0 && !active && _joined)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    (unreadCounter ?? 0) > 9 ? "9+" : "$unreadCounter",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 10),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
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
          _sheetHandle(),
          _modeSwitch(),
          const SizedBox(height: 8),

          Expanded(
            child: Stack(
              children: [
                // -----------------------
                // DETAILS LAYER
                // -----------------------
                IgnorePointer(
                  ignoring: _isChat,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isChat ? 0 : 1,
                    child: Transform.translate(
                      offset: Offset(0, _isChat ? -10 : 0),
                      child: _buildDetails(controller),
                    ),
                  ),
                ),

                // -----------------------
                // CHAT LAYER
                // -----------------------
                IgnorePointer(
                  ignoring: !_isChat,
                  child: SlideTransition(
                    position: _chatSlide,
                    child: FadeTransition(
                      opacity: _chatOpacity,
                      child: ActivityChat(
                        key: _chatKey, 
                        activityId: post!.id,
                        initialJoined: _joined,
                        initialRequested: _requested,
                        onJoinChanged: (v) async {
                          setState(() => _joined = v);
                          await fetchParticipantAvatars();
                          setState(() {
                            _chatKey = UniqueKey();
                          });
                        },
                        onRequestedChanged: (v) async {
                          setState(() => _requested = v);
                        },
                        isActive: _isChatActive,
                        onActiveRead: markChatAsRead,
                        markUnread: markChatAsRead,
                        joinMode: post!.joinMode,
                      )
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _animateWhenReady(double target, {bool animate = true}) async {
    debugPrint("🟣 ANIMATE REQUESTED | attached=${_sheetController.isAttached}");
    debugPrint("🎯 target=$target animate=$animate");
    int attempts = 0;
    while (!_sheetController.isAttached) {
      attempts++;
      debugPrint("⏳ waiting for attachment... attempt $attempts");
      await Future.delayed(const Duration(milliseconds: 16));
    }

    if (animate) {
      _sheetController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      debugPrint("✅ animation done");
    } else {
      _sheetController.jumpTo(target);
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_mode != ActivityMode.details) return;
    if (!_sheetController.isAttached) return;

    final delta =
        -details.primaryDelta! / MediaQuery.of(context).size.height;

    final newSize = (_sheetController.size + delta).clamp(0.60, 0.88);

    _sheetController.jumpTo(newSize);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_mode != ActivityMode.details) return; // 🚨 IMPORTANT
    if (!_sheetController.isAttached) return;

    final velocity = details.primaryVelocity ?? 0;
    final current = _sheetController.size;

    double target;

    if (velocity < -200) {
      target = 0.88;
    } else if (velocity > 200) {
      target = 0.60;
    } else {
      target = (current - 0.60).abs() < (current - 0.88).abs()
          ? 0.60
          : 0.88;
    }

    _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _activityIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildFloatingJoinButton() {
    if (_mode == ActivityMode.chat) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _sheetController,
      builder: (context, _) {
        final size = _sheetController.isAttached
            ? _sheetController.size
            : 0.60;

        final t = ((size - 0.70) / 0.18).clamp(0.0, 1.0);

        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: t < 0.05,
            child: Opacity(
              opacity: t,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),

                  border: Border(
                    top: BorderSide(
                      color: Colors.black.withOpacity(0.08),
                      width: 1,
                    ),
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 28,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: Material(
                      color: (_loadingJoin || _requested)
                          ? const Color(0xFFE8F5EE)
                          : _joined
                              ? Colors.grey.shade300
                              : Colors.black,
                        borderRadius: BorderRadius.circular(26),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(26),
                          onTap: (_loadingJoin || _requested) ? null : toggleJoin,
                          child: Center(
                            child: _loadingJoin
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    (post!.joinMode == "Instant")
                                      ? _joined 
                                        ? "Beigetreten"
                                        : "Beitreten"
                                      : (post!.joinMode == "Request")
                                        ? _joined 
                                          ? "Beigetreten"
                                          : _requested
                                            ? "Angefragt"
                                            : "Anfragen"
                                        : "",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _joined
                                          ? const Color(0xFF16A34A)
                                          : Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                CircleAvatar(
                  radius: 20,
                  backgroundImage: _avatarUrl != null
                      ? NetworkImage(_avatarUrl!)
                      : const NetworkImage(
                          "https://media.istockphoto.com/id/2221502929/de/vektor/flache-abbildung-in-graustufen-avatar-benutzerprofil-personensymbol-geschlechtsneutrale.jpg",
                        ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profileName ?? "Username",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                      formatPostAge(post!.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        )
                      ),
                    ]
                  ),
                ),

                if ({
                  "Run": Icons.directions_run,
                  "Bike": Icons.directions_bike,
                }.containsKey(post!.activity))
                  _activityIcon({
                    "Run": Icons.directions_run,
                    "Bike": Icons.directions_bike,
                  }[post!.activity]!),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            post!.title,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
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
    final config = activityConfigs[post!.activity];
    return Container(
      padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(26),

          border: Border.all(
            color: Colors.grey.shade200,
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      child: Column(
        children: [
          // HEADER
          Row(
            children: [

              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)
                ),
                child: const Icon(
                  Icons.insights_outlined,
                  color: Colors.black,
                  size: 14,
                ),
              ),

              const SizedBox(width: 12),

              const Text(
                "Aktivitätsdetails",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
                    Row(
            children: [
              Expanded(
                child: _stat(
                  "Tag",
                  (post!.date != null && post!.time != null)
                      ? dataFormatter.formatActivityDate(DateTime.parse("${post!.date}T${post!.time!}"))
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _stat(
                  "Distanz",
                  post!.distance != null
                      ? dataFormatter.formatDistance(post!.distance!)
                      : "-",
                ),
              ),
              Expanded(
                child: _stat(
                  config?.statLabel ?? "-",
                  config?.statValue(post!) ?? "-",
                ),
              ),
            ]
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
            fontSize: 9,
            letterSpacing: 0.8,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsCard() {
    final hasParticipants = participantAvatars.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ParticipantsPage(postId: post!.id),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // =========================
            // HEADER
            // =========================
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.black,
                    size: 14,
                  ),
                ),

                const SizedBox(width: 10),

                // 👇 IMPORTANT: Flexible instead of Expanded
                Flexible(
                  fit: FlexFit.loose,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Wer dabei ist",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        count == 0
                            ? "Noch niemand dabei"
                            : "$count ${count == 1 ? "Person" : "Personen"}",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 35),

                // 👇 AVATARS (fixed width, no competition with text)
                if (hasParticipants)
                  SizedBox(
                    width: 120, // 👈 KEY FIX: reserve space explicitly
                    height: 32,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (int i = 0; i < participantAvatars.take(5).length; i++)
                          Positioned(
                            left: i * 18,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage(participantAvatars[i]),
                            ),
                          ),

                        if (count > 5)
                          Positioned(
                            left: 5 * 18,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  "+${count - 5}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  const SizedBox(width: 120),

                const SizedBox(width: 6),

                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription() {
    if ((post!.description ?? "").isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const Text(
          //   "Beschreibung",
          //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          // ),
          // const SizedBox(height: 8),

          Text(
            post!.description!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.4,
            ),
          ),
        ],
      )
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
    final screenHeight = MediaQuery.of(context).size.height;

    // final sheetSize = _sheetController.isAttached
    //     ? _sheetController.size
    //     : (_mode == ActivityMode.chat ? 0.88 : 0.60);

    final sheetSize = _sheetController.isAttached
      ? _sheetController.size
      : 0.60; // always neutral baseline

    final sheetHeight = screenHeight * sheetSize;
    final sheetTopY = screenHeight - sheetHeight;

    // final t = ((sheetSize - 0.60) / (0.88 - 0.60)).clamp(0.0, 1.0);
    // final previewOpacity = 1.0 - t;

    return Scaffold(
      body: post == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _buildHero(),

                // // 👉 FLOATING PREVIEW LAYER (important)
                // if (post!.latitude != null && post!.longitude != null)
                //   Positioned(
                //     top: sheetTopY - 95,
                //     right: 16,
                //     child: _mode == ActivityMode.chat
                //         ? const SizedBox()
                //         : SheetPreview(
                //             controller: _sheetController,
                //             child: GestureDetector(
                //               onTap: () {
                //                 setState(() {
                //                   _mapPrimary = !_mapPrimary;
                //                 });
                //               },
                //               child: Container(
                //                 width: 80,
                //                 height: 80,
                //                 decoration: BoxDecoration(
                //                   borderRadius: BorderRadius.circular(16),
                //                   boxShadow: [
                //                     BoxShadow(
                //                       blurRadius: 12,
                //                       color: Colors.black.withOpacity(0.25),
                //                     ),
                //                   ],
                //                 ),
                //                 child: ClipRRect(
                //                   borderRadius: BorderRadius.circular(16),
                //                   child: _mapPrimary
                //                       ? _buildMap()
                //                       : Image.network(post!.imgurl!),
                //                 ),
                //               ),
                //             ),
                //           ),
                //   ),

                DraggableScrollableSheet(
                  // key: ValueKey(_mode),
                  controller: _sheetController,
                  initialChildSize: _mode == ActivityMode.chat ? 0.88 : 0.60,
                  minChildSize: _mode == ActivityMode.chat ? 0.88 : 0.60,
                  maxChildSize: 0.88,
                  // snap: true,
                  // snapSizes: [0.60, 0.88],
                  // expand: true,
                  builder: (context, scrollController) {
                    return _buildContent(scrollController);
                  },
                ),

                _buildFloatingJoinButton(),

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