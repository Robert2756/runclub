import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/post.dart';
import 'services/image_service.dart';
import 'dart:io';
import 'newpost_page.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'widgets/post_placeholder.dart';
import 'models/post.dart';
final supabase = Supabase.instance.client;
final imageService = ImageService();

class FeedPage extends StatefulWidget {
  const FeedPage({super.key, required this.title});
  final String title;
  @override
  State<FeedPage> createState() => FeedPageState();
}

class FeedPageState extends State<FeedPage> {
  List<Map<String, dynamic>> posts = [];
  Map<String, bool> showImageMap = {};
  double? _userLat;
  double? _userLon;
  bool _locationEnabled = false;
  Map<String, bool> postTextLoaded = {};
  List<int> placeholderList = List.generate(5, (index) => index); // 5 skeleton posts
  bool _feedInitializing = true;
  final ScrollController _scrollController = ScrollController();
  bool isRefreshing = false;

  // paging state
  int _page = 0; // current page
  bool _isLoading = false; // prevents double fetch
  bool _hasMore = true; // more posts to load?

  @override
  void initState() {
    super.initState();
    _initFeed();
  }

  Future<void> _initFeed() async {
    await _initUserLocation(); // wait for user location or skip if denied
    await fetchPosts(); // fetch posts based on user location
  }

  Future<void> _refreshFeed() async {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (isRefreshing) return;
    isRefreshing = true;

    setState(() {
      _page = 0;
      _hasMore = true;
      posts.clear();
      _feedInitializing = true;
    });
    await _initFeed();
    isRefreshing = false;
  }

  void scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
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

  Future<void> fetchPosts({bool loadMore = false}) async {
    if (_isLoading || !_hasMore) return; // prevent multiple or unnecessary execution
    if (isRefreshing && loadMore) return; // prevent pagination
    _isLoading = true;

    final int limit = 4; // posts per page
    final from = _page * limit;
    final to = from + limit -1;

    try {
      debugPrint('from: $from and to: $to for page $_page');

      final data = await supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .range(from, to); // fetch the range
      debugPrint('Fetched posts: $data');

      if (data.isEmpty){
        setState((){
          _hasMore = false; // no more posts to load
        });
        return;
      }

      final newPosts = List<Map<String, dynamic>>.from(data);
      final Distance distance = Distance();

      for (var post in newPosts) {
        // initialize show image state for each post
        showImageMap.putIfAbsent(post['id'].toString(), () => post["showImageMain"]);
        // track if post text loaded
        postTextLoaded.putIfAbsent(post['id'].toString(), () => false);
        // compute distance only if location is enabled
        if (_locationEnabled && _userLat != null && _userLon != null) {
          final km = distance.as(
            LengthUnit.Meter,
            LatLng(_userLat!, _userLon!),
            LatLng(post['latitude'], post['longitude']),
          );
          final int kmRounded = km.round();
          post['user_distance'] = kmRounded;
          postTextLoaded[post['id']] = true; // finished preprocessing the post
        } else {
          post['user_distance'] = null; // optional: show "-" in UI
        }
      }
      // add posts to list and update UI
      setState(() {
        if (loadMore) {
          posts.addAll(newPosts);
        } else {
          posts = newPosts;
        }
        _page += 1;
        _feedInitializing = false;
      });
    } catch (e) {
      debugPrint('Error fetching posts: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _feedInitializing = false;
      });
    }
  }

  Future<void> uploadPostImage(File? compressedImage, String path) async {
    if (compressedImage == null) return;

    await supabase.storage.from('PostImages').upload(
      path,
      compressedImage,
      fileOptions: FileOptions(upsert: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Builder(
          builder: (context) {
            final bottomSafeArea = MediaQuery.of(context).padding.bottom;
            const standardSpacing = 0.0;
            const standardSpacingTop = 8.0;
            const bottomBarHeight = 50.0; // height of AppBottomBar
            const fabSpacing = 16.0; // extra spacing for FAB

            final totalBottomPadding = standardSpacing + bottomBarHeight + fabSpacing + bottomSafeArea;

            return NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                // check if near the bottom and not already loading
                if (!_isLoading &&
                    !isRefreshing &&
                    _hasMore &&
                    scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                  fetchPosts(loadMore: true); // load next batch
                }
                return false; // return false to allow the scroll to continue
              },
              child: RefreshIndicator(
                color: Colors.black,
                backgroundColor: Colors.white,
                strokeWidth: 2.0,
                onRefresh: _refreshFeed,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  cacheExtent: 1000,
                  padding: EdgeInsets.fromLTRB(
                    standardSpacing, // left
                    standardSpacingTop, // top
                    standardSpacing, // right
                    totalBottomPadding, // bottom
                  ),
                  itemCount: posts.isEmpty
                    ? 1 // ALWAYS exactly one item during initial state
                    : posts.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    /// 1. INITIAL LOADING STATE
                    if (posts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: PostPlaceholder(),
                      );
                    }

                    /// 2. PAGINATION LOADER (only AFTER posts exist)
                    if (index >= posts.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: PostPlaceholder(),
                        ),
                      );
                    }

                    // 3. Safe access
                    final post = posts[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: PostCard(
                        key: ValueKey(post['id'].toString()),
                        post: Post(
                          id: post['id'].toString(),
                          title: post['title'],
                          creatorId: post['creator_id'],
                          imgurl: post['image_url'],
                          description: post['description'],
                          activity: post['activity'],
                          distance: post['distance'],
                          pace: post['pace'],
                          date: post['date'],
                          time: post['time'],
                          latitude: post['latitude'],
                          longitude: post['longitude'],
                          town: post['town'],
                          createdAt: post['created_at'],
                          userdistance: post['user_distance'],
                          startsAt: post['starts_at'],
                        ),
                        showImageMain: showImageMap[post['id'].toString()] ?? true,
                        onToggle: (val) {
                          setState(() {
                            showImageMap[post['id'].toString()] = val;
                          });
                        },
                      ),
                    );
                  }
                )
              )
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreatePostPageV2(),
              ),
            );
              if (result == true) {
                // refresh paging state of feed
                _page = 0;
                _hasMore = true;
                posts = [];
                fetchPosts(loadMore: true);
              }
            },
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add, size: 24),
          ),
        ),
      ),
    );
  }
}