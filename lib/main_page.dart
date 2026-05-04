import 'package:flutter/material.dart';
import 'widgets/app_bottom_bar.dart';
import 'widgets/app_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feed_page.dart';
import 'search_page.dart';
import 'history_page.dart';
import 'profile_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'invite_inbox_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  String? _avatarUrl;
  final supabase = Supabase.instance.client;
  late final List<Widget> pages;
  final GlobalKey<FeedPageState> _feedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    fetchProfileImage();

    pages = [
      FeedPage(key: _feedKey, title: "Feed"),
      const HistoryPage(title: "History"),
    ];
  }

  // fetch profile image from database
  Future<void> fetchProfileImage() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      final response = await supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', userId)
          .single(); // fetch single row

      setState(() {
        _avatarUrl = response['avatar_url'] as String?;
      });
    } catch (e) {
      debugPrint('Error fetching profile image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: Text(
          "RunClub",
          style: GoogleFonts.bebasNeue(
            fontSize: 28,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SearchPage(title: "Find People"),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Einladungen',
            icon: Stack(
              children: [
                const Icon(Icons.mail_outline),

                // optional badge
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const InviteInboxSheet(),
              );
            },
          ),
          IconButton(
            tooltip: 'Profile',
            icon: _avatarUrl != null
              ? CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(_avatarUrl!),
                )
              : const Icon(Icons.person_outline),
            onPressed: () {
                Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(
                    profileId: supabase.auth.currentUser!.id,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages
      ),
      bottomNavigationBar: AppBottomBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (_currentIndex == index && index == 0) {
            _feedKey.currentState?.scrollToTop();
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
      ),
    );
  }
}