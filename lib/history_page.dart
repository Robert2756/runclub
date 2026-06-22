import 'package:flutter/material.dart';
import 'services/image_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/post_history.dart';
import 'models/post.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'activity_page.dart';
import 'dart:ui';

final supabase = Supabase.instance.client;
final imageService = ImageService();

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.title});
  final String title;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Map<String, List<Map<String, dynamic>>> groupedPosts = {};
  double? _userLat;
  double? _userLon;
  bool _locationEnabled = false;
  bool showPast = false;
  List<Post> upcomingRuns = [];
  List<Post> pastRuns = [];
  Post? nextRun;
  Map<String, bool> showImageMap = {};
  Map<int, Set<int>> grouped = {};
  Map<String, bool> monthExpanded = {};
  Map<String, List<Post>> monthPosts = {};
  Map<String, bool> monthLoaded = {};
  Map<String, bool> monthLoading = {};

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> fetchPosts({bool loadMore = false}) async {
    final userId = supabase.auth.currentUser!.id;

    try {
      // get upcoming joined posts (load all at once) 
      final result = await supabase
        .from('activity_participants')
        .select('''
          posts (*)
        ''')
        .eq('user_id', userId)
        .gte('posts.starts_at', DateTime.now().toIso8601String());

      final joinedUpcomingResult = result
        .map((e) => e['posts'])
        .where((p) => p != null)
        .toList();

      // convert to post objects
      final joinedUpcomingPosts = joinedUpcomingResult.map<Post>((postData) {
        return Post(
          id: postData['id'].toString(),
          title: postData['title'],
          creatorId: postData['creator_id'],
          imgurl: postData['image_url'],
          description: postData['description'],
          activity: postData['activity'],
          distance: postData['distance'],
          pace: postData['pace'],
          date: postData['date'],
          time: postData['time'],
          latitude: postData['latitude'],
          longitude: postData['longitude'],
          town: postData['town'],
          createdAt: postData['created_at'],
          startsAt: postData['starts_at']
        );
      }).toList();

      final joinedUpcomingPostsSorted = joinedUpcomingPosts
      .toList()
      ..sort((a, b) =>
          DateTime.parse(a.startsAt!).compareTo(DateTime.parse(b.startsAt!)));

      // fetch months and years that need to be loaded for the past runs
      final resultTimeStructure = await supabase
        .from('posts')
        .select('starts_at, activity_participants!inner(user_id)')
        .eq('activity_participants.user_id', userId)
        .lt('starts_at', DateTime.now().toIso8601String());
      
      Map<int, Set<int>> groupedCollect = {};
      for (final e in resultTimeStructure) {
        final dt = DateTime.parse(e['starts_at']);

        groupedCollect.putIfAbsent(dt.year, () => <int>{});
        groupedCollect[dt.year]!.add(dt.month);
      }

      // update state
      setState(() {
        upcomingRuns = joinedUpcomingPostsSorted;
        grouped = groupedCollect;
        nextRun = joinedUpcomingPostsSorted.isNotEmpty ? joinedUpcomingPostsSorted.first : null;
      });

    } catch (e) {
      debugPrint('Error fetching posts: $e');
    }
  }

  Future<void> _loadMonth(int year, int month) async {
    final key = "$year-$month";

    if (monthLoaded[key] == true || monthLoading[key] == true) return;

    setState(() {
      monthLoading[key] = true;
    });

    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    final userId = supabase.auth.currentUser!.id;

    final result = await supabase
        .from('posts')
        .select('''
          *,
          activity_participants!inner(user_id)
        ''')
        .eq('activity_participants.user_id', userId)
        .gte('starts_at', start.toIso8601String())
        .lte('starts_at', end.toIso8601String());

    final posts = result.map<Post>((e) {
      return Post(
        id: e['id'].toString(),
        title: e['title'],
        creatorId: e['creator_id'],
        imgurl: e['image_url'],
        description: e['description'],
        activity: e['activity'],
        distance: e['distance'],
        pace: e['pace'],
        date: e['date'],
        time: e['time'],
        latitude: e['latitude'],
        longitude: e['longitude'],
        town: e['town'],
        createdAt: e['created_at'],
        startsAt: e['starts_at'],
      );
    }).toList();

    setState(() {
      monthPosts[key] = posts;
      monthLoaded[key] = true;
      monthLoading[key] = false;
    });
  }

  Future<Position?> getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null; // user declined
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _userLat = position.latitude;
        _userLon = position.longitude;
      });
      return position;
    } catch (e) {
      debugPrint("Error getting user location: $e");
      return null;
    }
  }

  Future<void> _initUserLocation() async {
    try {
      final position = await getUserLocation();
      if (position != null) {
        _userLat = position.latitude;
        _userLon = position.longitude;
        _locationEnabled = true;
      }
    } catch (e) {
      debugPrint('User declined or location unavailable: $e');
      _locationEnabled = false;
    }
  }

  Widget _buildTopToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          _softToggle("Anstehend", !showPast),
          const SizedBox(width: 16),
          _softToggle("Vergangen", showPast),
        ],
      ),
    );
  }

  Widget _softToggle(String text, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() => showPast = (text == "Vergangen"));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? Colors.black : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: active ? 18 : 0,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastGrouped(Map<int, Set<int>> grouped) {
    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: years.map((year) {
        final months = grouped[year]!;

        final sortedMonths = months.toList()
          ..sort((a, b) => b.compareTo(a));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                "$year",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            ...sortedMonths.map((month) {
              final key = "$year-$month";
              final isExpanded = monthExpanded[key] ?? false;
              final isLoaded = monthLoaded[key] ?? false;

              return Column(
                children: [
                  ListTile(
                    dense: true,
                    title: Text(
                      DateFormat.MMMM('de_DE')
                          .format(DateTime(0, month)),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      isExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    onTap: () async {
                      setState(() {
                        monthExpanded[key] = !isExpanded;
                      });

                      if (!isLoaded) {
                        await _loadMonth(year, month);
                      }
                    },
                  ),

                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: monthLoading[key] == true
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : Column(
                            children: (monthPosts[key] ?? [])
                                .map(
                                  (p) => Opacity(
                                    opacity: 0.75,
                                    child: PostHistory(post: p),
                                  ),
                                )
                                .toList(),
                          ),
                    secondChild: const SizedBox.shrink(),
                  ),
                ],
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildNextRun(Post post) {
    final dateTime = DateTime.parse("${post.date} ${post.time}");
    final diff = dateTime.difference(DateTime.now());

    String countdown;
    if (diff.inHours < 1) {
      countdown = "in ${diff.inMinutes} Minuten";
    } else if (diff.inHours < 24) {
      countdown = "in ${diff.inHours} Stunden";
    } else {
      countdown = "in ${diff.inDays} Tagen";
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background image
            if (post.imgurl != null)
              Positioned.fill(
                child: Transform.scale(
                  scale: 1.4,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: 70,
                      sigmaY: 70,
                    ),
                    child: Image.network(
                      post.imgurl!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

            // Dark overlay
            // Positioned.fill(
            //   child: Container(
            //     decoration: BoxDecoration(
            //       gradient: LinearGradient(
            //         begin: Alignment.topLeft,
            //         end: Alignment.bottomRight,
            //         colors: [
            //           Colors.black.withOpacity(0.35),
            //           Colors.black.withOpacity(0.55),
            //         ],
            //       ),
            //     ),
            //   ),
            // ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.activity == "Bike"
                        ? "Nächste Radfahrt"
                        : "Nächster Lauf",
                    style: const TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "${post.town ?? ""} • "
                    "${DateFormat('EEEE, HH:mm', 'de_DE').format(dateTime)}",
                    style: const TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    countdown,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActivityPage(
                              postId: post.id,
                              userDistance: post.userdistance,
                            ),
                          ),
                        );
                      },
                      child: const Text("Ansehen"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
    );
  }

  Widget _buildPastSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Toggle row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () {
              setState(() => showPast = !showPast);
            },
            child: Row(
              children: [
                Text(
                  "Past Runs",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  showPast
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                  color: Colors.grey[700],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Collapsible content
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: showPast
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Column(
            children: pastRuns.map((p) {
              return Opacity(
                opacity: 0.75, // 👈 subtle visual downgrade
                child: PostHistory(post: p),
              );
            }).toList(),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    await fetchPosts();
  }

  @override
  void initState() {
    super.initState();
    fetchPosts();
    _initUserLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        onRefresh: _refresh,
        child:
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (nextRun != null && upcomingRuns.isEmpty) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.directions_run, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text("Keine anstehenden Läufe"),
                        const SizedBox(height: 6),
                        const Text("Tritt einem Lauf über dein Feed bei"),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                if (nextRun != null) ...[
                  _buildNextRun(nextRun!),
                  const SizedBox(height: 12),
                ],
                _buildTopToggle(),

                if (!showPast)...[
                  if (upcomingRuns.length > 1) ...[
                    // _buildSectionTitle("Anstehend"),
                    ...upcomingRuns.skip(1).map((p) => PostHistory(post: p)),
                  ],
                ] else ...[
                  if (grouped.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildPastGrouped(grouped)
                  ],
                ]
              ]
            ],
          )
      )
    );
  }
}