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
import 'package:shimmer/shimmer.dart';

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
  bool _initialLoading = true;
  bool _nextRunCardLoaded = false;

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
    setState(() {
      _initialLoading = true;
    });
    final userId = supabase.auth.currentUser!.id;

    try {
      // get upcoming joined posts (load all at once) 
      final result = await supabase
        .from('activity_participants')
        .select('''
          posts (*)
        ''')
        .eq('user_id', userId)
        .eq('status', 'joined')
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
        .eq('activity_participants.status', 'joined')
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
    } finally {
      setState(() {
        _initialLoading = false;
      });
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
        .eq('activity_participants.status', 'joined')
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
                                    opacity: 1,
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

  Widget buildShimmer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        period: const Duration(milliseconds: 1400),
        child: Container(
          height: 210,
          decoration: BoxDecoration(
            color: Colors.grey.shade200, // Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
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
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return Shimmer.fromColors(
                          baseColor: Colors.grey.shade200,
                          highlightColor: Colors.grey.shade100,
                          child: Container(color: Colors.grey.shade200),
                        );
                      },
                    )
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

  Widget _buildJoinMoreEventsCard() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade100,
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_repeat_rounded,
                  color: Colors.grey.shade800,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Tritt weiteren Events bei",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "Du hast schon einen Lauf – entdecke mehr in deiner Nähe.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingEmptyCard() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Weitere anstehende Events erscheinen hier",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryFallback() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade100,
              Colors.white,
            ],
          ),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // subtle background shape
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.03),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      size: 26,
                      color: Colors.grey.shade800,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Noch keine Aktivitäten",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Deine abgeschlossenen Läufe erscheinen hier zur Übersicht.",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoftEmptyState({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Text(
          //   title,
          //   style: TextStyle(
          //     fontSize: 15,
          //     fontWeight: FontWeight.w600,
          //     color: Colors.grey.shade800,
          //   ),
          // ),
          // const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        onRefresh: _refresh,
        child:
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (nextRun != null) ...[
                _buildNextRun(nextRun!),
                const SizedBox(height: 12),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    height: 210,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Background
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.grey.shade100,
                                  Colors.white,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Content (same structure as _buildNextRun)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 8),

                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.9),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.history_outlined,
                                  size: 30,
                                  color: Colors.grey.shade800,
                                ),
                              ),

                              const SizedBox(height: 18),

                              const Text(
                                "Keine anstehenden Events",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                "Tritt einem Lauf oder einer Radtour bei und dein nächstes Event erscheint hier.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildTopToggle(),

              if (!showPast)...[
                if (upcomingRuns.length > 1) ...[
                  // _buildSectionTitle("Anstehend"),
                  ...upcomingRuns.skip(1).map((p) => PostHistory(post: p)),
                ] else ...[
                  const SizedBox(height: 12),
                  _buildSoftEmptyState(
                    title: "Keine anstehenden Events",
                    subtitle: "Weitere anstehende Läufe erscheinen hier.",
                  )
                ]
              ] else ...[
                if (grouped.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildPastGrouped(grouped)
                ] else ...[
                  const SizedBox(height: 12),
                  _buildSoftEmptyState(
                    title: "Noch keine vergangenen Aktivitäten",
                    subtitle: "Abgeschlossene Läufe werden hier gesammelt.",
                  )
                ]
              ]
            ]
          )
      )
    );
  }
}