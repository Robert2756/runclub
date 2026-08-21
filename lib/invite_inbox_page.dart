import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'activity_page.dart';
import 'profile_page.dart';
import 'services/data_formatter.dart';
import 'dart:async';

final supabase = Supabase.instance.client;
final dataFormatter = DataFormatter();

class InviteInboxSheet extends StatefulWidget {
  final Future<void> Function()? onMarkedSeen;

  const InviteInboxSheet({
    super.key,
    this.onMarkedSeen,
  });

  @override
  State<InviteInboxSheet> createState() => _InviteInboxSheetState();
}

class _InviteInboxSheetState extends State<InviteInboxSheet>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  Map<String, bool> loadStatesAccepts = {};
  Map<String, bool> loadStatesDeletes = {};
  bool loadDelete = false;
  List<Map<String, dynamic>> notifications = [];
  String _filter = 'all';
  final List<String> _filters = [
    'all',
    'invite',
    'request',
    'chat',
    'join',
  ];
  bool _showFilters = false;
  RealtimeChannel? _chatMessagesChannel;
  Timer? _fetchDebounce;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    _subscribeToChatMessages();
  }

  @override
  void dispose() {
    _unsubscribeFromChatMessages();
    _fetchDebounce?.cancel();
    super.dispose();
  }

  void _subscribeToChatMessages() {
    final userId = supabase.auth.currentUser!.id;

    _chatMessagesChannel = supabase.channel('inbox-chat-$userId');
    _chatMessagesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activity_messages',
          callback: (payload) {
            debugPrint('>>> RAW payload received: ${payload.newRecord}');
            final senderId = payload.newRecord['user_id'];
            if (senderId == userId) return; // ignore own messages

            _debouncedFetch();
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Inbox chat realtime status: $status, error: $error');
        });
  }

  void _unsubscribeFromChatMessages() {
    _chatMessagesChannel?.unsubscribe();
    _chatMessagesChannel = null;
  }

  void _debouncedFetch() {
    _fetchDebounce?.cancel();
    _fetchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) fetchNotifications();
    });
  }

  Future<void> fetchNotifications() async {
    final userId = supabase.auth.currentUser!.id;

    final results = await Future.wait([
      supabase
          .from('notifications')
          .select('''
            *,
            posts!inner(*),
            profiles!notifications_from_user_fkey(
              username,
              avatar_url
            )
          ''')
          .eq('to_user', userId)
          .gt('posts.starts_at', DateTime.now().toIso8601String()),
      supabase.rpc('get_unread_chat_notifications'),
    ]);

    final normalNotifications =
        List<Map<String, dynamic>>.from(results[0] as List); // {id: x, from_user: x, to_user: x, post_id: x, created_at, type: x, is_seen: x, posts: {}, profiles: {}}
    
    final normalNotificationsNorm = normalNotifications.map((n) {
      return {
        'type': n['type'],
        'id': n['id'],
        'post_id': n['post_id'],
        'from_user': n['from_user'],
        'to_user': n['to_user'],
        'title': n['posts']?['title'],
        'username': n['profiles']?['username'],
        'starts_at': n['posts']?['starts_at'],
        'town': n['posts']?['town'],
        'avatar_url': n['profiles']?['avatar_url'],
        'is_seen': n['is_seen'],
        'created_at': n['created_at'],
        'notification_key': 'n_${n['id']}',
      };
    }).toList();
    // debugPrint("Normal notifications: $normalNotificationsNorm");

    final chatNotifications =
        List<Map<String, dynamic>>.from(results[1] as List); // {post_id: x, unread_count: x, latest_message: timestamptz}

    final chatNotificationsNorm = chatNotifications.map((c) {
      return {
        'type': 'chat',
        'post_id': c['post_id'],  // fetch complete post instead of post_id
        'title': c['title'],
        'image_url': c['image_url'],
        'unread_count': c['unread_count'],
        'created_at': c['latest_message'],
        'notification_key': 'chat_${c['post_id']}',
      };
    }).toList();
    // debugPrint("Chat notifications: $chatNotificationsNorm");

    // merge both into one notification scheme
    final merged = [...normalNotificationsNorm, ...chatNotificationsNorm];

    merged.sort((a, b) {
      final aTime = DateTime.parse(a['created_at']);
      final bTime = DateTime.parse(b['created_at']);
      return bTime.compareTo(aTime);
    });
    // debugPrint("Notifications: $merged");

    if (!mounted) return;
    setState(() {
      notifications = List<Map<String, dynamic>>.from(merged);
      loadStatesAccepts = {
        for (final n in notifications)
          n['notification_key']: false,
      };

      loadStatesDeletes = {
        for (final n in notifications)
          n['notification_key']: false,
      };
      loading = false;
    });
    await markAllSeen();
  }

  Future<void> markAllSeen() async {
    // debugPrint("Marking all notifications as seen...");
    final userId = supabase.auth.currentUser!.id;

    await supabase
        .from('notifications')
        .update({'is_seen': true})
        .eq('to_user', userId)
        .eq('is_seen', false);
    
    await widget.onMarkedSeen?.call();
  }

  Future<void> acceptRequest(Map<String, dynamic> request, int index) async {
    final key = request['notification_key'];
    setState(() {
      loadStatesAccepts[key] = true;
    });
    debugPrint("Update join state");
    // accept request
    try {
      await supabase
        .from('activity_participants')
        .update({
          'status': 'joined',
          'joined_at': DateTime.now().toIso8601String()
        })
        .eq('post_id', request['post_id'])
        .eq('user_id', request['from_user']);
      
      // insert accept notification
      await supabase.from('notifications').insert({
            'from_user': request['to_user'],
            'to_user': request['from_user'],
            'post_id': request['post_id'],
            'created_at': DateTime.now().toIso8601String(),
            'type': 'accept'
          });
      
      await deleteNotification(request, index);
    } catch (e) {
      debugPrint('Error accepting request: $e');
    } finally {
      await fetchNotifications();
      setState(() {
        loadStatesAccepts[key] = false;
      });
    }
  }

  Future<void> deleteRequest(Map<String, dynamic> request, int index) async {
    final key = request['notification_key'];
    setState(() {
      loadStatesDeletes[key] = true;
    });

    try {
      // delete from_user from activity participants table
      await supabase
        .from('activity_participants')
        .delete()
        .eq('post_id', request['post_id'])
        .eq('user_id', request['from_user']);
      
      await deleteNotification(request, index);

    } catch (e) {
      debugPrint('Error deleting from_user from activity: $e');
    } finally {
      await fetchNotifications();
      if (!mounted) return;
      setState(() {
        loadStatesDeletes[key] = false;
      });
    }
  }

  Future<void> deleteNotification(Map<String, dynamic> request, int index) async {
    final key = request['notification_key'];
    try {
      // delete request from notifications
      await supabase
        .from('notifications')
        .delete()
        .eq('id', request['id']);

    } catch (e) {
      debugPrint('Error deleting request: $e');
    } finally {
      await fetchNotifications();
      if (!mounted) return;
      setState(() {
        loadStatesDeletes[key] = false;
      });
    }
  }

  void _openActivity (Map<String, dynamic> notification) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityPage(
          postId: notification['post_id'],
          userDistance: null,
        ),
      ),
    );

    if (!mounted) return;

    // fetch new notification if coming back
    await fetchNotifications();

    if (changed == true) {
      Navigator.pop(context, true); // bubble upward
    }
  }

  String _groupLabel(DateTime createdAt) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final notifDay = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    final diff = today.difference(notifDay).inDays;

    if (diff == 0) return "Heute";
    if (diff == 1) return "Gestern";
    if (diff <= 7) return "Letzte 7 Tage";
    if (diff <= 30) return "Letzter Monat";

    return "Älter";
  }

  // ---------------- SAFE PLACEHOLDERS ----------------
  Widget _newDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.blueAccent,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _emptyTab(String text) {
    return Center(
      child: Text(
        text,
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildInviteCard(
    Map<String, dynamic> notification,
  ) {
    // final post = notification['posts'];
    // final fromUser = notification['profiles'];
    final isNew = notification['is_seen'] == false;
    final fromUserId = notification['from_user'];

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isNew
            ? Colors.blue.withOpacity(0.04)
            : Colors.transparent
      ),
      child: Row(
        children: [

          /// AVATAR
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    profileId: fromUserId,
                  ),
                ),
              );
            },
            child: CircleAvatar(
              radius: 26,
              backgroundImage: notification['avatar_url'] != null
                  ? NetworkImage(notification['avatar_url'])
                  : null,
              child: notification['avatar_url'] == null
                  ? const Icon(Icons.person, size: 16)
                  : null,
            ),
          ),

          const SizedBox(width: 12),

          /// TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13.5,
                    ),
                    children: [
                      TextSpan(
                        text: notification['username'] ?? 'Jemand',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(
                        text: ' hat dich eingeladen',
                      ),
                    ],
                  ),
                ),

                // const SizedBox(height: 2),

                // Text(
                //   post['title'] ?? '',
                //   maxLines: 1,
                //   overflow: TextOverflow.ellipsis,
                //   style: const TextStyle(
                //     color: Colors.black54,
                //     fontSize: 13,
                //   ),
                // ),

                const SizedBox(height: 2),

                Text(
                  "Lauf • "
                  "${dataFormatter.formatActivityDate(DateTime.parse(notification['starts_at']))}"
                  " • ${notification['town']}",
                  // "${post['starts_at'] != null
                  //     ? dataFormatter.formatActivityDate(
                  //         DateTime.parse(post['starts_at'])
                  //       )
                  //     : "-"}"
                  // " • "
                  
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          /// ACTION
          InkWell(
            onTap: () => _openActivity(notification),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Ansehen",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationShell({
    required Widget child,
    required bool isNew,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNew)
            Align(
              alignment: Alignment.topRight,
              child: _newDot(),
            ),

          child,
        ],
      ),
    );
  }

  Widget _buildRequestCard(
    Map<String, dynamic> notification,
    int index,
  ) {
    // final post = notification['posts'];
    // final user = notification['profiles'];
    final isNew = notification['is_seen'] == false;
    final postId = notification['post_id'];
    final fromUserId = notification['from_user'];
    final key = notification['notification_key'];


    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: isNew ? Colors.blue.withOpacity(0.04) : Colors.transparent,
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          /// AVATAR
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    profileId: fromUserId,
                  ),
                ),
              );
            },
            child: CircleAvatar(
              radius: 26,
              backgroundImage: notification['avatar_url'] != null
                  ? NetworkImage(notification['avatar_url'])
                  : null,
              child: notification['avatar_url'] == null
                  ? const Icon(Icons.person, size: 16)
                  : null,
            ),
          ),

          const SizedBox(width: 12),

          /// TEXT BLOCK
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// LINE 1: USER + ACTION (always full)
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13.5,
                    ),
                    children: [
                      TextSpan(
                        text: notification['username'] ?? 'Jemand',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: " möchte teilnehmen"),
                    ],
                  ),
                ),

                const SizedBox(height: 2),

                /// LINE 2: POST TITLE (truncated)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ActivityPage(
                                postId: postId,
                                userDistance: null,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          notification['title'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 22),
                  ],
                ),

                // const SizedBox(height: 1),

                // Text(
                //   notification['created_at'] != null ? "vor kurzem" : "",
                //   style: TextStyle(
                //     fontSize: 11,
                //     color: Colors.grey.shade500,
                //   ),
                // ),
              ],
            )
          ),

          /// ACTIONS (ICON STYLE)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// ACCEPT (MORE PRESENT)
              InkWell(
                onTap: loadStatesAccepts[key] ?? false
                    ? null
                    : () => acceptRequest(notification, index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: 65, // pick a value that fits "Annehmen"
                    child: Center(
                      child: loadStatesAccepts[key] ?? false
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Annehmen",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 5),
              /// REJECT (subtle icon)
              InkWell(
                onTap: loadStatesDeletes[key] ?? false
                    ? null
                    : () => deleteRequest(notification, index),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: loadStatesDeletes[key] ?? false
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey,
                        ),
                      )
                    : Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildJoinedCard(
    Map<String, dynamic> notification,
  ) {
    // final post = notification['posts'];
    // final user = notification['profiles'];
    final isNew = notification['is_seen'] == false;
    final fromUserId = notification['from_user'];

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: isNew ? Colors.blue.withOpacity(0.04) : Colors.transparent,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          
          /// AVATAR
          /// AVATAR
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    profileId: fromUserId,
                  ),
                ),
              );
            },
            child: CircleAvatar(
              radius: 26,
              backgroundImage: notification['avatar_url'] != null
                  ? NetworkImage(notification['avatar_url'])
                  : null,
              child: notification['avatar_url'] == null
                  ? const Icon(Icons.person, size: 16)
                  : null,
            ),
          ),

          const SizedBox(width: 12),

          /// TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                /// LINE 1
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13.5,
                    ),
                    children: [
                      TextSpan(
                        text: notification['username'] ?? 'Jemand',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: " ist beigetreten"),
                    ],
                  ),
                ),

                const SizedBox(height: 2),

                /// LINE 2
                Text(
                  notification['title'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          /// ICON (subtiler als ListTile trailing)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 18,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'Aktivität';
    final imageUrl = notification['image_url'];

    final unreadCount = notification['unread_count'] ?? 0;
    final isNew = unreadCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: isNew ? Colors.blue.withOpacity(0.04) : Colors.transparent,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          /// RECT IMAGE (KEY ELEMENT)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 56,
              height: 56,
              color: Colors.grey.shade200,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                    )
                  : const Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: Colors.grey,
                    ),
            ),
          ),

          const SizedBox(width: 12),

          /// TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  unreadCount == 1
                      ? "1 ungelesene Nachricht in $title"
                      : "$unreadCount ungelesene Nachrichten in $title",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 3),

                // Text(
                //   "Letzte Aktivität",
                //   style: TextStyle(
                //     fontSize: 12,
                //     color: Colors.grey.shade600,
                //   ),
                // ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          /// ACTION
          InkWell(
            onTap: () {
              _openActivity(notification);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Öffnen",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptCard(Map<String, dynamic> notification) {
    final isNew = notification['is_seen'] == false;
    final fromUserId = notification['from_user'];

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: isNew ? Colors.blue.withOpacity(0.04) : Colors.transparent,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// AVATAR
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    profileId: fromUserId,
                  ),
                ),
              );
            },
            child: CircleAvatar(
              radius: 26,
              backgroundImage: notification['avatar_url'] != null
                  ? NetworkImage(notification['avatar_url'])
                  : null,
              child: notification['avatar_url'] == null
                  ? const Icon(Icons.person, size: 16)
                  : null,
            ),
          ),

          const SizedBox(width: 12),

          /// TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13.5,
                    ),
                    children: [
                      TextSpan(
                        text: notification['username'] ?? 'Jemand',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' hat deine Anfrage angenommen'),
                    ],
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  notification['title'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          /// ACTION (same black CTA style as others)
          InkWell(
            onTap: () => _openActivity(notification),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Ansehen",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernFilterChip(String label, String value) {
    final selected = _filter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? Colors.black : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
    int index,
  ) {
    switch (notification['type']) {
      case 'invite':
        return _buildInviteCard(notification);

      case 'request':
        return _buildRequestCard(notification, index);

      case 'join':
        return _buildJoinedCard(notification);
      
      case 'chat':
        return _buildMessageCard(notification);
      
      case 'accept':
        return _buildAcceptCard(notification);

      // case 'participant_left':
      //   return _buildLeftCard(notification);

      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    return 
    SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Center(
                    child: Text(
                      "Benachrichtigungen",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: () {
                        setState(() {
                          _showFilters = !_showFilters;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _showFilters
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _modernFilterChip('Alle', 'all'),
                          _modernFilterChip('Einladungen', 'invite'),
                          _modernFilterChip('Anfragen', 'request'),
                          _modernFilterChip('Chat', 'chat'),
                          _modernFilterChip('Beigetreten', 'join'),
                          _modernFilterChip('Angenommen', 'accept'),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 6),
            
            Expanded(
              child: Builder(
                builder: (context) {
                  final List<Widget> items = [];
                  final List<Map<String, dynamic>> filteredNotifications =
                  _filter == 'all'
                      ? notifications
                      : notifications.where((n) => n['type'] == _filter).toList();

                  String? currentGroup;

                  for (int i = 0; i < filteredNotifications.length; i++) {
                    final notification = filteredNotifications[i];

                    final createdAt = DateTime.parse(
                      notification['created_at'],
                    );

                    final group = _groupLabel(createdAt);

                    if (group != currentGroup) {
                      currentGroup = group;

                      items.add(
                        _sectionHeader(group),
                      );
                    }

                    items.add(
                      _buildNotificationCard(
                        notification,
                        i,
                      ),
                    );
                  }

                  return ListView(
                    children: items,
                  );
                },
              ),
            )
          ],
        ),
      )
    );
  }
}