import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart';

final supabase = Supabase.instance.client;

class ParticipantsPage extends StatefulWidget {
  final String postId;

  const ParticipantsPage({
    super.key,
    required this.postId,
  });

  @override
  State<ParticipantsPage> createState() => _ParticipantsPageState();
}

class _ParticipantsPageState extends State<ParticipantsPage> {
  String? creatorId;
  String? participants;
  bool hasHistory = true;

Future<Map<String, dynamic>> fetchData() async {
  final res = await supabase
      .from('posts')
      .select('creator_id, activity_participants(user_id, profiles(id, username, avatar_url))')
      .eq('id', widget.postId)
      .single();

  return res;
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Participants")),
      body: FutureBuilder(
        future: fetchData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data as Map<String, dynamic>;

          final creatorId = data['creator_id'];
          final participants = data['activity_participants'] as List;

          if (participants.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  "No participants yet — be the first to join 🚀",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            itemCount: participants.length,
            itemBuilder: (context, index) {
              final profile = participants[index]['profiles'];
              final userId = participants[index]['user_id'];

              final isCreator = userId == creatorId;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(
                        profileId: userId,
                      ),
                    ),
                  );
                },
                child: Card(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: profile['avatar_url'] != null &&
                              profile['avatar_url'].toString().isNotEmpty
                          ? NetworkImage(profile['avatar_url'])
                          : const NetworkImage(
                              "https://www.gravatar.com/avatar/placeholder?s=200&d=mp",
                            ),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile['username'] ?? 'Unknown'),
                        if (hasHistory)
                          Text(
                            "2 gemeinsame Läufe • letzter vor 3 Wochen",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}