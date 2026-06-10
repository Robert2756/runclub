import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'activity_page.dart';
import 'profile_page.dart';
import 'services/data_formatter.dart';

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
  List<bool> loadStatesAccepts = [];
  List<bool> loadStatesDeletes = [];
  bool loadDelete = false;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    final userId = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('notifications')
        .select('''
          *,
          posts(*),
          profiles!notifications_from_user_fkey(
            username,
            avatar_url
          )
        ''')
        .eq('to_user', userId)
        .order('created_at', ascending: false);

    setState(() {
      notifications = List<Map<String, dynamic>>.from(res);
      loadStatesAccepts =
          List.filled(notifications.length, false);
      loadStatesDeletes =
          List.filled(notifications.length, false);
      loading = false;
    });
    await markAllSeen();
  }

  Future<void> markAllSeen() async {
    debugPrint("Marking all notifications as seen...");
    final userId = supabase.auth.currentUser!.id;

    await supabase
        .from('notifications')
        .update({'is_seen': true})
        .eq('to_user', userId)
        .eq('is_seen', false);
    
    await widget.onMarkedSeen?.call();
  }

  Future<void> acceptRequest(Map<String, dynamic> request, int index) async {
    setState(() {
      loadStatesAccepts[index] = true;
    });
    debugPrint("Request id: ${request['id']}");
    final user = supabase.auth.currentUser!.id;
    debugPrint("User: $user");
    debugPrint("to_user: ${request['to_user']}");
    // accept request
    try {
      await supabase
        .from('activity_participants')
        .update({
          'status': 'joined',
        })
        .eq('post_id', request['post_id'])
        .eq('user_id', request['from_user']);
      
      await deleteNotification(request, index);
    } catch (e) {
      debugPrint('Error accepting request: $e');
    } finally {
      await fetchNotifications();
      setState(() {
        loadStatesAccepts[index] = false;
      });
    }
  }

  Future<void> deleteRequest(Map<String, dynamic> request, int index) async {
    setState(() {
      loadStatesDeletes[index] = true;
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
      setState(() {
        loadStatesDeletes[index] = false;
      });
    }
  }

  Future<void> deleteNotification(Map<String, dynamic> request, int index) async {
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
      setState(() {
        loadStatesDeletes[index] = false;
      });
    }
  }

  void _openActivity(Map<String, dynamic> invite) {
    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityPage(
          postId: invite['posts']['id'],
          userDistance: null,
        ),
      ),
    );
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
    final post = notification['posts'];
    final fromUser = notification['profiles'];
    final isNew = notification['is_seen'] == false;

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
          CircleAvatar(
            radius: 26,
            backgroundImage: fromUser?['avatar_url'] != null
                ? NetworkImage(fromUser['avatar_url'])
                : null,
            child: fromUser?['avatar_url'] == null
                ? const Icon(Icons.person, size: 16)
                : null,
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
                        text: fromUser?['username'] ?? 'Jemand',
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
                  "${dataFormatter.formatActivityDate(DateTime.parse(post['starts_at']))}"
                  " • ${post['town']}",
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
    debugPrint("Request notification: $notification");
    final post = notification['posts'];
    final user = notification['profiles'];
    final isNew = notification['is_seen'] == false;
    final postId = notification['post_id'];
    final fromUserId = notification['from_user'];

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
              backgroundImage: user?['avatar_url'] != null
                  ? NetworkImage(user['avatar_url'])
                  : null,
              child: user?['avatar_url'] == null
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
                        text: user?['username'] ?? 'Jemand',
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
                          post['title'] ?? '',
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
                onTap: loadStatesAccepts[index]
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
                      child: loadStatesAccepts[index]
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
                onTap: loadStatesDeletes[index]
                    ? null
                    : () => deleteRequest(notification, index),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: loadStatesDeletes[index]
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
    final post = notification['posts'];
    final user = notification['profiles'];
    final isNew = notification['is_seen'] == false;

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
          CircleAvatar(
            radius: 26,
            backgroundImage: user?['avatar_url'] != null
                ? NetworkImage(user['avatar_url'])
                : null,
            child: user?['avatar_url'] == null
                ? const Icon(Icons.person, size: 16)
                : null,
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
                        text: user?['username'] ?? 'Jemand',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: " ist beigetreten"),
                    ],
                  ),
                ),

                const SizedBox(height: 2),

                /// LINE 2
                Text(
                  post['title'] ?? '',
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
    final post = notification['posts'];
    final user = notification['profiles'];
    final isNew = notification['is_seen'] == false;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: isNew ? Colors.blue.withOpacity(0.04) : Colors.transparent,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: user?['avatar_url'] != null
                ? NetworkImage(user['avatar_url'])
                : null,
            child: user?['avatar_url'] == null
                ? const Icon(Icons.person, size: 16)
                : null,
          ),

          const SizedBox(width: 12),

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
                        text: user?['username'] ?? 'Jemand',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: " hat eine Nachricht gesendet"),
                    ],
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  post?['title'] != null
                      ? "in ${post['title']}"
                      : "in einer Aktivität",
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

          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityPage(
                    postId: post['id'],
                    userDistance: null,
                  ),
                ),
              );
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
      
      case 'message':
        return _buildMessageCard(notification);

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

            const Text(
              "Benachrichtigungen",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),
            
            Expanded(
              child: Builder(
                builder: (context) {
                  final List<Widget> items = [];

                  String? currentGroup;

                  for (int i = 0; i < notifications.length; i++) {
                    final notification = notifications[i];

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