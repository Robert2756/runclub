import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'activity_page.dart';

final supabase = Supabase.instance.client;

class InviteInboxSheet extends StatefulWidget {
  const InviteInboxSheet({super.key});

  @override
  State<InviteInboxSheet> createState() => _InviteInboxSheetState();
}

class _InviteInboxSheetState extends State<InviteInboxSheet>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  List<Map<String, dynamic>> invites = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchInvites();
  }

  Future<void> fetchInvites() async {
    final userId = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('invites')
        .select('''
          *,
          posts(title, date, time, town),
          profiles!invites_from_user_fkey(
            username,
            avatar_url
          )
        ''')
        .eq('to_user', userId)
        .order('created_at', ascending: false);

    setState(() {
      invites = List<Map<String, dynamic>>.from(res);
      loading = false;
    });
  }

  void _openActivity(Map<String, dynamic> invite) {
    Navigator.pop(context);

    final post = invite['posts'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityPage(
          postId: post['id'].toString(),
          userDistance: null,
        ),
      ),
    );
  }

  // ---------------- SAFE PLACEHOLDERS ----------------

  Widget _emptyTab(String text) {
    return Center(
      child: Text(
        text,
        style: TextStyle(color: Colors.grey[600]),
      ),
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
                    child: Text(
                      "${fromUser?['username'] ?? 'Jemand'} hat dich eingeladen",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
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
                _buildInvites(),          // ✅ your working UI
                // _emptyTab("Noch keine Chat-Updates"),
                _emptyTab("Noch keine Anfragen"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}