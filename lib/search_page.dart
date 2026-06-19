import 'package:flutter/material.dart';
import 'services/image_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/app_bar.dart';
import 'profile_page.dart';

final supabase = Supabase.instance.client;
final imageService = ImageService();

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.title});
  final String title;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController controller = TextEditingController();
  List<Map<String, dynamic>> results = [];
  bool loading = false;

  Future<void> search(String query) async {
    if (query.isEmpty) {
      setState(() => results = []);
      return;
    }

    setState(() => loading = true);

    final response = await supabase
        .from('profiles')
        .select('id, username, avatar_url')
        .ilike('username', '%$query%')
        .limit(20);

    setState(() {
      results = List<Map<String, dynamic>>.from(response);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: controller,
              onChanged: search,
              decoration: InputDecoration(
                hintText: "User suchen...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (loading)
            const LinearProgressIndicator(),

          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final user = results[index];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    backgroundImage: user['avatar_url'] != null
                        ? NetworkImage(user['avatar_url'])
                        : null,
                    child: user['avatar_url'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(user['username'] ?? 'Unknown'),
                  onTap: () {
                    // open profile
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePage(
                          profileId: user['id'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}