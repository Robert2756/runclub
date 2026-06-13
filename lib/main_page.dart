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

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _notificationCount = 0;
  String? _avatarUrl;
  final supabase = Supabase.instance.client;
  late final List<Widget> pages;
  final GlobalKey<FeedPageState> _feedKey = GlobalKey();
  late final RealtimeChannel _notificationChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    fetchProfileImage();
    fetchNotificationCount();

    final userId = supabase.auth.currentUser!.id;

    _notificationChannel = supabase
        .channel('notifications-$userId')

        // social notifications
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_user',
            value: userId,
          ),
          callback: (payload) {
            fetchNotificationCount();
          },
        )

        // chat messages
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'activity_participants',
          callback: (_) {
            fetchNotificationCount();
          },
        )

        .subscribe();

    pages = [
      FeedPage(key: _feedKey, title: "Feed"),
      const HistoryPage(title: "History"),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    supabase.removeChannel(_notificationChannel);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchNotificationCount();
    }
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

  // fetch number of notifications (invitations or requests)
  Future<void> fetchNotificationCount() async {
    debugPrint("Fetch notification count!");
    try {
      final res = await supabase.rpc('get_total_unread_notifications');

      setState(() {
        _notificationCount = (res as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      debugPrint('Error fetching unified notification count: $e');
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
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.mail_outline),

                if (_notificationCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _notificationCount > 99 ? '99+' : '$_notificationCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async{
              final userId = supabase.auth.currentUser!.id;
              await supabase
                  .from('notifications')
                  .update({'is_seen': true})
                  .eq('to_user', userId)
                  .eq('is_seen', false);
              if (!mounted) return;

              final changed = await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => InviteInboxSheet(),
              );

              if (changed == true) {
                fetchNotificationCount();
              }
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