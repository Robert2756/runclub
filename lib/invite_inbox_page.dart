import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'activity_page.dart';

final supabase = Supabase.instance.client;

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
  List<Map<String, dynamic>> invites = [];
  List<Map<String, dynamic>> requests = [];
  late TabController _tabController;

  bool _invitesLoaded = false;
  bool _requestsLoaded = false;

  bool _invitesSeenMarked = false;
  bool _requestsSeenMarked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    fetchInvites();
    fetchRequests();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;

      if (_tabController.index == 1) {
        _tryMarkRequestsSeen();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _markAsSeenInvites() async {
    debugPrint("Marking invites as seen...");
    final userId = supabase.auth.currentUser!.id;

    await supabase
        .from('notifications')
        .update({'is_seen': true})
        .eq('to_user', userId)
        .eq('type', 'invite')
        .eq('is_seen', false);

    await widget.onMarkedSeen?.call();
  }

  Future<void> _markAsSeenRequests() async {
    debugPrint("Marking requests as seen...");
    final userId = supabase.auth.currentUser!.id;

    await supabase
        .from('notifications')
        .update({'is_seen': true})
        .eq('to_user', userId)
        .eq('type', 'request')
        .eq('is_seen', false);
    
    await widget.onMarkedSeen?.call();
  }

  void _tryMarkInvitesSeen() {
    debugPrint("Trying to mark invites seen: invitesLoaded=$_invitesLoaded, invitesSeenMarked=$_invitesSeenMarked");
    if (!_invitesLoaded || _invitesSeenMarked) return;
    if (!mounted) return;

    _invitesSeenMarked = true;
    _markAsSeenInvites();
  }

  void _tryMarkRequestsSeen() {
    debugPrint("Trying to mark requests seen: requestsLoaded=$_requestsLoaded, requestsSeenMarked=$_requestsSeenMarked, currentTab=${_tabController.index}");
    if (!_requestsLoaded || _requestsSeenMarked) return;
    if (_tabController.index != 1) return;
    debugPrint("Current tab: ${_tabController.index}");

    _requestsSeenMarked = true;
    _markAsSeenRequests();
  }

  Future<void> fetchInvites() async {
    final userId = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('notifications')
        .select('''
          *,
          posts(id, title, date, time, town),
          profiles!notifications_from_user_fkey(
            username,
            avatar_url
          )
        ''')
        .eq('to_user', userId)
        .eq('type', 'invite')
        .order('created_at', ascending: false);

    setState(() {
      debugPrint("Invites: $res");
      invites = List<Map<String, dynamic>>.from(res);
      loading = false;
      _invitesLoaded = true;
    });
    _tryMarkInvitesSeen();
  }

  Future <void> fetchRequests() async {
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
      .eq('type', 'request')
      .order('created_at', ascending: false);

    setState(() {
      requests = List<Map<String, dynamic>>.from(res);
      loading = false;
      loadStatesAccepts = List.filled(requests.length, false);
      loadStatesDeletes = List.filled(requests.length, false);
      _requestsLoaded = true;
    });
    _tryMarkRequestsSeen();
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
      await fetchRequests();
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
      await fetchRequests();
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
      await fetchRequests();
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

  Widget _buildRequests() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (requests.isEmpty) {
      return _emptyTab("Keine neuen Anfragen");
    }

    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        final post = request['posts'];
        final fromUser = request['profiles'];
        final isNew = request['is_seen'] == false;

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: fromUser?['avatar_url'] != null
                        ? NetworkImage(fromUser['avatar_url'])
                        : null,
                    child: fromUser?['avatar_url'] == null
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            "${fromUser?['username'] ?? 'Jemand'} möchte an deiner Aktivität teilnehmen",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        if (isNew) ...[
                          const SizedBox(width: 6),
                          _newDot(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                post['title'] ?? "Run",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                "${post['town']} • ${post['date']}",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (loadStatesAccepts[index] && !loadStatesDeletes[index])
                          ? null
                          : () => acceptRequest(request, index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      child: loadStatesAccepts[index]
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Annehmen"),
                    ),
                  ),

                  const SizedBox(width: 12), // spacing between buttons

                  Expanded(
                    child: ElevatedButton(
                      onPressed: (loadStatesDeletes[index] && !loadStatesAccepts[index])
                          ? null
                          : () => deleteRequest(request, index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 255, 255, 255),
                        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                        child: (loadStatesDeletes[index] && !loadStatesAccepts[index])
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Löschen"),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvites() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (invites.isEmpty) {
      return _emptyTab("Keine neuen Einladungen");
    }

    return ListView.builder(
      itemCount: invites.length,
      itemBuilder: (context, index) {
        final invite = invites[index];
        final post = invite['posts'];
        final fromUser = invite['profiles'];
        final isNew = invite['is_seen'] == false;

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
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage:
                        fromUser?['avatar_url'] != null
                            ? NetworkImage(fromUser['avatar_url'])
                            : null,
                    child: fromUser?['avatar_url'] == null
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            "${fromUser?['username'] ?? 'Jemand'} hat dich eingeladen",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        if (isNew) ...[
                          const SizedBox(width: 6),
                          _newDot(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                post['title'] ?? "Run",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                "${post['town']} • ${post['date']}",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _openActivity(invite),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Zur Aktivität"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
            "Inbox",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            tabs: const [
              Tab(text: "Einladungen"),
              // Tab(text: "Chat"),
              Tab(text: "Anfragen"),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 420,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInvites(),         
                _buildRequests(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}