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
import 'chat_page.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'activity_share_page.dart';
import 'package:device_calendar/device_calendar.dart';
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
  bool get _canSeeExactLocation => _joined;
  List<String> participantAvatars = [];
  // List<String> debugParticipants = [
  //   'https://i.pravatar.cc/40?img=11',
  //   'https://i.pravatar.cc/40?img=7',
  //   'https://i.pravatar.cc/40?img=8',
  //   'https://i.pravatar.cc/40?img=9',
  //   'https://i.pravatar.cc/40?img=10',
  //   'https://i.pravatar.cc/40?img=10',];
  List<String> debugParticipants = [];
  String? _avatarUrl;
  String? _profileName;
  final dataFormatter = DataFormatter();
  final bullet = " •\u200B ";
  ActivityMode _mode = ActivityMode.details;
  final DraggableScrollableController _sheetController =
    DraggableScrollableController();
  
  int get count => participants.length;
  int? unreadCounter;
  Key _chatKey = UniqueKey(); // if key changes -> build ActivityChat new (as it is passed as key)
  Key _detailsKey = UniqueKey();

  final mapUrl = 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/backdrop/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/basic-v2-light/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/voyager-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  // final mapUrl = 'https://api.maptiler.com/maps/topo-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';

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
      // date: response['date'],
      // time: response['time'],
      latitude: (response['latitude'] as num?)?.toDouble(),
      longitude: response['longitude']?.toDouble(),
      town: response['town'],
      createdAt: response['created_at'],
      joinMode: response['join_mode'],
      userdistance: widget.userDistance,
      startsAt: response['starts_at']
    );

    final results = await Future.wait([
      supabase
          .from('activity_participants')
          .select('user_id')
          .eq('post_id', loadedPost.id)
          .eq('status', 'joined')
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

  Future<void> _reloadJoinState() async {
    final userId = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('activity_participants')
        .select('status')
        .eq('post_id', widget.postId)
        .eq('user_id', userId)
        .maybeSingle();

    final status = res?['status'];

    setState(() {
      _joined = status == "joined";
      _requested = status == "requested";
    });

    await _calculateUnread();
  }

  DateTime? parseDate(dynamic value) {
    if (value == null) return null;

    String s = value.toString().trim();

    // 1. Fix space → T
    s = s.replaceFirst(' ', 'T');

    // 2. Fix ONLY broken trailing +00 (not +00:00)
    s = s.replaceFirstMapped(
      RegExp(r'\+00$'),
      (_) => '+00:00',
    );

    // 3. Fix broken +00:00:00 → +00:00
    s = s.replaceFirst('+00:00:00', '+00:00');

    try {
      return DateTime.parse(s);
    } catch (_) {
      return null; // fail gracefully instead of crashing
    }
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
          .eq('post_id', post!.id) // filter for this post
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

  Future<void> showLeaveWarning() async {
    final leave = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aktivität verlassen?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Diese Aktion entfernt dich aus der Teilnehmerliste.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: Colors.black.withOpacity(0.65),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Abbrechen',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Verlassen',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (leave == true) {
      await toggleJoin();
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
            'status': "joined",
            'joined_at': DateTime.now().toIso8601String(),
          });
          await supabase.from('notifications').insert({
            'from_user': userId,
            'to_user': post!.creatorId,
            'post_id': post!.id,
            'created_at': DateTime.now().toIso8601String(),
            'type': 'join'
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
            _chatKey = UniqueKey();
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

  String? getStoragePathFromUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;

    final index = segments.indexOf('public');
    if (index == -1 || index + 2 >= segments.length) return null;

    // everything after /public/<bucket>/
    return segments.sublist(index + 2).join('/');
  }

  Future<void> _deleteActivity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aktivität löschen?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Diese Aktion kann nicht rückgängig gemacht werden.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: Colors.black.withOpacity(0.65),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Abbrechen',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Löschen',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    // delete messages
    await supabase
        .from('activity_messages')
        .delete()
        .eq('activity_id', post!.id);

    // delete participants
    await supabase
        .from('activity_participants')
        .delete()
        .eq('post_id', post!.id);
    
    // delete post notifications
    await supabase
      .from('notifications')
      .delete()
      .eq('post_id', post!.id);

    // delete post image
    final imageUrl = post?.imgurl;
    if (imageUrl != null) {
      final path = getStoragePathFromUrl(imageUrl);
      if (path != null) {
        await supabase.storage.from('PostImages').remove([path]);
      }
    }

    // delete db post row
    await supabase.from('posts').delete().eq('id', post!.id);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadActivity();
    _mode = ActivityMode.details;

  }

  Future<Calendar?> _pickCalendar(List<Calendar> calendars) async {
    return showModalBottomSheet<Calendar>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kalender auswählen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 12),

                ...calendars.map((c) {
                  final isWritable = (c.isReadOnly != true);

                  return Opacity(
                    opacity: isWritable ? 1 : 0.4,
                    child: GestureDetector(
                      onTap: isWritable
                          ? () => Navigator.pop(context, c)
                          : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isWritable ? Icons.event : Icons.lock,
                              size: 18,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                c.name ?? "Unbenannter Kalender",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addToCalendar() async {
    if (post == null || post!.startsAt == null) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final isParticipant = participants.contains(userId);

    if (!isParticipant) {
        final join = await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.6),
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aktivität beitreten',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Du musst Teil der Aktivität sein, um sie zum Kalender hinzuzufügen.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: Colors.black.withOpacity(0.65),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Abbrechen',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
        if (join != true) return;
      }

    final plugin = DeviceCalendarPlugin();

    // request permission
    var permResult = await plugin.requestPermissions();
    if (permResult.data != true) return;

    // get calendars and pick the default/first writable one
    final calendarsResult = await plugin.retrieveCalendars();
    final calendars = (calendarsResult.data ?? [])
    .whereType<Calendar>()
    .toList();

    if (calendars.isEmpty) {
      debugPrint("No calendars found");
      return;
    }
    final writable = calendars.where((c) => c.isReadOnly != true).toList();
    final selected = await _pickCalendar(writable.isNotEmpty ? writable : calendars);
    
    if (selected == null) return;
    final calendar = selected;
    debugPrint('Selected calendar: ${calendar.name} | id: ${calendar.id}');

    // confirm adding to calendar
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kalender hinzufügen?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Zu "${calendar.name}" hinzufügen?',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: Colors.black.withOpacity(0.65),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Abbrechen',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Hinzufügen',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirm != true) return;

    final start = DateTime.parse(post!.startsAt!).toLocal();
    final end = start.add(const Duration(hours: 1));

    final event = Event(
      calendar.id!,
      title: post!.title,
      description: post!.description ?? '',
      start: TZDateTime.from(start, local),
      end: TZDateTime.from(end, local),
      location: post!.town ?? '',
    );

    final result = await plugin.createOrUpdateEvent(event);

    if (mounted && result?.data != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zum Kalender hinzugefügt ✓')),
      );
    }
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

  Widget _buildLocationCard() {
    final locked = !_canSeeExactLocation;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // HEADER (light, no container)
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 18),
              const SizedBox(width: 8),

              const Text(
                "Treffpunkt",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),

              const Spacer(),

              Text(
                locked ? "nicht sichtbar" : "sichtbar",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // MAP PREVIEW (no card, just rounded clip)
          GestureDetector(
            onTap: locked
                ? null
                : () => openInMaps(post!.latitude!, post!.longitude!),
            child: AspectRatio(
              aspectRatio: 1 ,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(

                  height: 180,
                  child: Stack(
                    children: [
                      _buildMap(
                        initialZoom: locked ? 11 : 14,
                        showMarker: true,
                      ),

                      // soft gradient only for readability
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // bottom text only (no heavy overlay UI)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 10,
                        child: Text(
                          locked
                              ? (() {
                                  final distance = post!.userdistance != null
                                    ? (post!.userdistance! >= 1000
                                        ? "${(post!.userdistance! / 1000).round()} km entfernt"
                                        : "${post!.userdistance!.round()} m entfernt")
                                    : null;

                                  return distance != null ? "Sichtbar nach Beitritt · $distance" : "Sichtbar nach Beitritt";
                                })()
                              : (() {
                                  final town = post!.town ?? "Unbekannter Ort";

                                  final distance = post!.userdistance != null
                                      ? (post!.userdistance! >= 1000
                                          ? "${(post!.userdistance! / 1000).round()} km entfernt"
                                          : "${post!.userdistance!.round()} m entfernt")
                                      : null;

                                  return distance != null ? "$town · $distance" : town;
                                })(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thinSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(
        height: 1,
        color: Colors.black.withOpacity(0.06),
      ),
    );
  }

  Widget _buildDetails(ScrollController controller) {
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
              _thinSeparator(),
              const SizedBox(height: 20),
              _buildQuickStats(),
              const SizedBox(height: 20),
              _thinSeparator(),
              const SizedBox(height: 20),
              _buildParticipantsCard(),
              const SizedBox(height: 20),
              _thinSeparator(),
              const SizedBox(height: 20),
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

    return GestureDetector(
      onTap: () async {
        final wasChat = _mode == ActivityMode.chat;
        final goingToChat = target == ActivityMode.chat;

        if (goingToChat) {
          if (_joined) await markChatAsRead();

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActivityChatPage(
                post: post!,
                initialJoined: _joined,
                initialRequested: _requested,
                participantsCount: count,
              ),
            ),
          );

          if (mounted) {
            await _reloadJoinState();
          }

          return; // IMPORTANT: stop mode switching
        }

        setState(() {
          _mode = target;
        });
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

          const Spacer(),

          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: _showActivityOptions,
          ),
        ],
      ),
    );
  }

  Future<void> _showActivityOptions() async {
    final isOwner =
        post?.creatorId == supabase.auth.currentUser?.id;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text("Aktivität löschen"),
                  onTap: () => Navigator.pop(context, "delete"),
                ),

              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text("Teilen"),
                onTap: () => Navigator.pop(context, "share"),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    switch (action) {
      case "delete":
        await _deleteActivity();
        break;

      case "share":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivitySharePage(
              post: post!,
              participants: count,
              profileName: _profileName,
            ),
          ),
        );
        break;
    }
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
                _buildDetails(controller),
              ]
            )
          )
        ],
      ),
    );
  }

  Widget _buildFloatingJoinButton() {
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
                          ? Colors.grey.shade300
                          : _joined
                              ? Colors.grey.shade300
                              : Colors.black,
                        borderRadius: BorderRadius.circular(26),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(26),
                          onTap: (_loadingJoin || _requested) 
                            ? null
                            : (_joined
                              ? showLeaveWarning
                              : toggleJoin),
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
                                          // ? const Color(0xFF16A34A)
                                          ? Colors.white
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
                        post!.activity == "Run" 
                        ? "Lauf ${dataFormatter.activityRelativeTimeOnlyDays(DateTime.parse(post!.startsAt!))}"
                        : "Radfahrt ${dataFormatter.activityRelativeTimeOnlyDays(DateTime.parse(post!.startsAt!))}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        )
                      ),
                    ]
                  ),
                ),

                GestureDetector(
                  onTap: () => _addToCalendar(),
                  child: Text(
                    "Kalender hinzufügen",
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color.fromARGB(255, 179, 179, 179),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header (no container)
          Row(
            children: const [
              Icon(Icons.insights_outlined, size: 18),
              SizedBox(width: 8),
              Text(
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

          // stats grid
          Row(
            children: [
              Expanded(
                child: _stat("Tag",
                  post!.startsAt != null
                      ? dataFormatter.formatActivityDate(
                          DateTime.parse(post!.startsAt!))
                      : "-",
                ),
              ),
              Expanded(
                child: _stat("Zeit",
                  post!.startsAt != null
                      ? "${dataFormatter.formatTime(
                          DateTime.parse(post!.startsAt!))} Uhr"
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
                      ? "${dataFormatter.formatDistance(post!.distance!)} km"
                      : "-",
                ),
              ),
              Expanded(
                child: _stat(
                  config?.statLabel ?? "-",
                  config?.statValue(post!) ?? "-",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

    final visible = participantAvatars.take(5).toList();
    final double overlap = 22;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ParticipantsPage(postId: post!.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
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
                  const Icon(Icons.people, size: 18),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Wer dabei ist",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // AVATARS
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    count == 0
                        ? "Noch niemand dabei"
                        : "$count ${count == 1 ? "Person" : "Personen"}",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                SizedBox(
                  width: 120,
                  height: 36,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (hasParticipants)
                        for (int i = 0; i < visible.length; i++)
                          Positioned(
                            right: i * overlap,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundImage: NetworkImage(visible[i]),
                            ),
                          )
                      else
                        for (int i = 0; i < 3; i++)
                          Positioned(
                            right: i * overlap,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[300],
                              child: Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                    ],
                  ),
                )
              ],
            )
          ],
        )
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: post == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _buildHero(),

                DraggableScrollableSheet(
                  key: ValueKey(_mode),
                  controller: _sheetController,
                  initialChildSize: 0.60,
                  minChildSize: 0.60,
                  maxChildSize: 0.88,
                  snap: true,
                  snapSizes: [0.60, 0.88],
                  expand: true,
                  builder: (context, scrollController) {
                    return _buildContent(scrollController);
                  }
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