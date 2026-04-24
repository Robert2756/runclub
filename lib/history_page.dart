import 'package:flutter/material.dart';
import 'services/image_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/post_history.dart';
import 'models/post.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'activity_page.dart';

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
      // get joined post ids
      final result = await supabase
          .from('activity_participants')
          .select('post_id')
          .eq('user_id', userId);
      final ids = result.map((e) => e['post_id']).toList();
    
      // fetch joined posts
      final joinedPosts = ids.isEmpty
          ? []
          : await supabase
              .from('posts')
              .select()
              .inFilter('id', ids);
      
      // fetch created posts
      final createdPosts = await supabase
        .from('posts')
        .select()
        .eq('creator_id', userId);

      // merge raw data
      final allRawPosts = [
        ...createdPosts,
        ...joinedPosts,
      ];

      // convert to post objects
      final allPosts = allRawPosts .map<Post>((postData) {
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
        );
      }).toList();

      // remove duplicates (user joined own post)
      final uniquePosts = {
        for (var post in allPosts) post.id: post
      }.values.toList();

      debugPrint(
        "Unique post IDs: ${uniquePosts.map((p) => p.id).toList()} ${uniquePosts.map((p) => p.title).toList()}",
      );

      // split by time
      final now = DateTime.now();

      final upcoming = uniquePosts
        .where((p) => DateTime.parse(p.date!).isAfter(now))
        .toList()
      ..sort((a, b) =>
          DateTime.parse(a.date!).compareTo(DateTime.parse(b.date!)));

      final past = uniquePosts
          .where((p) => DateTime.parse(p.date!).isBefore(now))
          .toList();
      
      debugPrint(
        "Unique post IDs: ${past.map((p) => p.title).toList()}",
      );

      // update state
      setState(() {
        upcomingRuns = upcoming;
        pastRuns = past;
        nextRun = upcoming.isNotEmpty ? upcoming.first : null;
      });

    } catch (e) {
      debugPrint('Error fetching posts: $e');
    }
  }

  Future<Position?> getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint("Location permission denied");
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
      debugPrint("User lat: ${position?.latitude}, lon: ${position?.longitude}");
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

  Widget _buildNextRun(Post post) {
    final dateTime = DateTime.parse("${post.date} ${post.time}");
    final diff = dateTime.difference(DateTime.now());

    String countdown;
    if (diff.inHours < 1) {
      countdown = "in ${diff.inMinutes} min";
    } else if (diff.inHours < 24) {
      countdown = "in ${diff.inHours} h";
    } else {
      countdown = "in ${diff.inDays} days";
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.black, Colors.grey],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Next Run",
                style: TextStyle(color: Colors.white70)),

            const SizedBox(height: 6),

            Text(post.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                )),

            const SizedBox(height: 6),

            Text(
              "${post.town ?? ""} • ${post.distance ?? "-"} km",
              style: const TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 6),

            Text(
              DateFormat('EEEE, HH:mm', 'de_DE').format(dateTime),
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

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
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
                    child: const Text("Open Run"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
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
        onRefresh: _refresh,
        child:
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (nextRun != null) ...[
                _buildNextRun(nextRun!),
                const SizedBox(height: 12),
              ],

              if (nextRun == null && upcomingRuns.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.directions_run, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text("No runs yet"),
                        const SizedBox(height: 6),
                        const Text("Join a run from the feed"),
                      ],
                    ),
                  ),
                ),

              if (upcomingRuns.length > 1) ...[
                _buildSectionTitle("Upcoming"),
                ...upcomingRuns.skip(1).map((p) => PostHistory(post: p)),
              ],

              if (pastRuns.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildPastSection(),
              ],
            ],
          )
      )
    );
  }
}