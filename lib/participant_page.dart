import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart';
import 'services/data_formatter.dart';

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
  Map<String, dynamic> participantsStats = {};
  late Future<Map<String, dynamic>> _future;
  final dataFormatter = DataFormatter();

  @override
  void initState() {
    super.initState();
    debugPrint("Init");
    _future = fetchData();
  }

  Future<Map<String, dynamic>> fetchData() async {
    final now = DateTime.now().toUtc().toIso8601String();
    debugPrint("Fetch data");
    final post = await supabase
        .from('posts')
        .select('''
          creator_id,
          activity_participants(
            user_id,
            status,
            profiles(
              id,
              username,
              avatar_url
            )
          )
        ''')
        .eq('id', widget.postId)
        .single();

    debugPrint("PARTICIPANTS: $post");
    final participants =(post['activity_participants'] as List<dynamic>?) ?? [];
    final joinedParticipants = participants
    .where((p) => p['status'] == 'joined')
    .toList();
    final currentUserId = supabase.auth.currentUser!.id;

    Map<String, dynamic> statsMap = {};

    for (final participant in joinedParticipants) {
      final userId = participant['user_id'];

      // skip yourself
      if (userId == currentUserId) continue;

      final res = await supabase.rpc(
        'get_connection_stats',
        params: {
          'user_a': currentUserId,
          'user_b': userId,
        },
      );

      final stats = (res as List).isNotEmpty ? res[0] : null;

      statsMap[userId] = {
        'together_count': stats?['together_count'] ?? 0,
        'last_together': stats?['last_together'] != null
            ? DateTime.parse(stats['last_together'])
            : null,
      };
    }

    return {
      'creator_id': post['creator_id'],
      'participants': joinedParticipants,
      'stats': statsMap,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teilnehmer")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final participants = data['participants'] as List;
          final statsMap = data['stats'] as Map<String, dynamic>;

          if (participants.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  "Bisher keine Teilnehmer — sei der Erste!",
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

              final stats = statsMap[userId];
              final togetherCount =
                  stats?['together_count'] ?? 0;
              final lastTogether =
                  stats?['last_together'];

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
                        if (togetherCount != 0)
                          Text(
                            togetherCount > 1
                            ? "$togetherCount Aktivitäten zusammen • letzte vor ${dataFormatter.formatTimeAgo(lastTogether)}"
                            : "$togetherCount Aktivität zusammen vor ${dataFormatter.formatTimeAgo(lastTogether)}",
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