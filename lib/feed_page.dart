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
import 'dart:math';
import 'widgets/loader.dart';
import 'services/location_picker.dart';
final supabase = Supabase.instance.client;
final imageService = ImageService();

// Brand palette, pulled from the Enduvo logo gradient.
class EnduvoColors {
  static const navy = Color(0xFF0A2647);
  static const deepBlue = Color(0xFF12406B);
  static const teal = Color(0xFF2E9DC0);
  static const gold = Color(0xFFF6C567);
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);
  static const muted = Color(0xFF6B7280);
  static const text = Color(0xFF111827);
}

class EmptyFeedState extends StatelessWidget {
  final String locationLabel;
  final VoidCallback onCreateActivity;
  final VoidCallback onChangeLocation;

  const EmptyFeedState({
    super.key,
    required this.locationLabel,
    required this.onCreateActivity,
    required this.onChangeLocation,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 500;

        return Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: 28,
              vertical: compact ? 12 : 16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Keine Aktivitäten in $locationLabel",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: EnduvoColors.text,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "Starte einfach selbst eine.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  SizedBox(height: compact ? 16 : 18),

                  SizedBox(
                    height: 42,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onCreateActivity,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        "Aktivität erstellen",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EnduvoColors.text,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: onChangeLocation,
                    style: TextButton.styleFrom(
                      foregroundColor: EnduvoColors.deepBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                    child: const Text(
                      "Standort ändern",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}




enum FeedStatus {
  idle,
  loadingInitial,
  refreshing,
  loadingMore,
  applyCandidates,
  exhausted,
}
class FeedPage extends StatefulWidget {
  const FeedPage({super.key, required this.title});
  final String title;
  @override
  State<FeedPage> createState() => FeedPageState();
}

class FeedPageState extends State<FeedPage> {
  Set<String> seenPostIds = {};
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> candidatePool = [];
  List<Map<String, dynamic>> additionalPostData = [];
  Map<String, bool> showImageMap = {};

  LocationSource _locationSource = LocationSource.gps;
  String _locationLabel = 'Suchen...';
  
  double? _userLat;
  double? _userLon;
  bool _locationEnabled = false;
  Map<String, bool> postTextLoaded = {};
  List<int> placeholderList = List.generate(5, (index) => index); // 5 skeleton posts
  final ScrollController _scrollController = ScrollController();
  int _dbOffset = 0;
  // paging state
  final batch_size = 4;
  final candidate_size = 20;
  final fetch_size = 40;
  bool _hasMore = true; // more posts to load?
  int _refreshVersion = 0;
  FeedStatus _status = FeedStatus.loadingInitial;
  Post? _pinnedPost;

  // radius filtering
  double _radiusMeters = 2000; // start small: 2km
  final double _maxRadiusMeters = 100000; // 50km cap
  final double _radiusStepFactor = 2.5; // exponential expansion

  @override
  void initState() {
    super.initState();
    _initFeed();
  }

  Future<void> _initFeed() async {
    final saved = await LocationPrefs.load();
    if (saved != null && saved.source == LocationSource.manual) {
      _userLat = saved.lat;
      _userLon = saved.lon;
      _locationEnabled = true;
      _locationSource = LocationSource.manual;
      _locationLabel = saved.name;
    } else {
      await _initUserLocation();
      _locationSource = LocationSource.gps;
      _locationLabel = 'Standort'; // reverse-geocode later if you want the real city name
    }
    await fetchCandidates();
  }

  Future<void> _refreshFeed() async {
    _refreshVersion++;
    if (_status == FeedStatus.refreshing) return;

    setState(() {
      _status = FeedStatus.refreshing;
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    setState(() {
      _hasMore = true;
      posts.clear();
      candidatePool.clear();
      _dbOffset = 0;
      _radiusMeters = 2000; // start small: 2km
      seenPostIds.clear();
      showImageMap.clear();
      postTextLoaded.clear();
    });

    await _initFeed();

    setState(() {
      _status = FeedStatus.idle;
    });
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

  Future<void> fetchCandidates() async {
    final currentVersion = _refreshVersion; // capture current refresh version
    if (!_hasMore) return;

    setState(() {
      _status = FeedStatus.loadingMore;
    });

    try {
      // fallback if no location
      if (!_locationEnabled || _userLat == null || _userLon == null) {
        final data = await supabase
            .from('posts')
            .select()
            .order('created_at', ascending: false)
            .range(_dbOffset, _dbOffset + candidate_size - 1);
        if (currentVersion != _refreshVersion) return; // return if user refreshed feed

        if (data.isEmpty) {
          _hasMore = false;
          _status = FeedStatus.exhausted;
          return;
        }

        candidatePool.addAll(List<Map<String, dynamic>>.from(data));
        _dbOffset += candidate_size;

      } else {
        final lat = _userLat;
        final lon = _userLon;

        if (lat == null || lon == null) {
          debugPrint('Location enabled but coordinates are missing');
          return;
        }

        final latDelta = _radiusMeters / 111320.0;
        final lonDelta =
            _radiusMeters / (111320.0 * cos(lat * pi / 180));

        final minLat = lat - latDelta;
        final maxLat = lat + latDelta;
        final minLon = lon - lonDelta;
        final maxLon = lon + lonDelta;

        // fetch post
        final data = await supabase
            .from('posts')
            .select()
            .gte('latitude', minLat)
            .lte('latitude', maxLat)
            .gte('longitude', minLon)
            .lte('longitude', maxLon)
            .gte('starts_at', DateTime.now().toIso8601String())
            .limit(fetch_size);

        // filter seen posts out
        final prefilteredCandidates = List<Map<String, dynamic>>.from(data);
        final filteredCandidates = prefilteredCandidates.where((p) =>
          !seenPostIds.contains(p['id'])
        );

        if (currentVersion != _refreshVersion) return; // return if user refreshed feed
        if (filteredCandidates.length < candidate_size) {
          if (_radiusMeters >= _maxRadiusMeters) { // max radius reached -> take posts anyway
            candidatePool.addAll(filteredCandidates);
            _hasMore = false;
          }
          else { // expand radius 
            _expandRadius();
            return;
          }
        }
        else {
          candidatePool.addAll(filteredCandidates);
        }
      }

      await rankCandidates();
      await _applyPosts();

    } catch (e) {
      debugPrint('Error fetching candidates: $e');
    } finally {}
  }

  Future<void> rankCandidates() async {
    final distance = Distance();
    final now = DateTime.now();

    const double d0 = 15000; // point where score has fallen to about 37% of its original value
    const double t0 = 168;   // hours until event
    const double f0 = 168;    // hours for freshness

    for (var post in candidatePool) {
      double distanceScore = 1.0;
      double timeScore = 1.0;
      double freshnessScore = 1.0;

      if (_locationEnabled && _userLat != null && _userLon != null) {
        final distanceMeters = distance.as(
          LengthUnit.Meter,
          LatLng(_userLat!, _userLon!),
          LatLng(post['latitude'], post['longitude']),
        );

        post['user_distance'] = distanceMeters.round();

        distanceScore = exp(-distanceMeters / d0);
      }

      // event time importance (planned activity relevance)
      if (post['starts_at'] != null) {
        final eventTime = DateTime.parse(post['starts_at']);
        final hoursDiff =
            eventTime.difference(now).inMinutes.abs() / 60.0;

        timeScore = exp(-hoursDiff / t0);
      }

      // creation freshness
      if (post['created_at'] != null) {
        final createdAt = DateTime.parse(post['created_at']);
        final ageHours =
            now.difference(createdAt).inMinutes / 60.0;

        freshnessScore = exp(-ageHours / f0);
      }

      post['score'] =
        0.55 * timeScore +
        0.45 * distanceScore;
        // 0.10 * freshnessScore;
    }
    candidatePool.sort((a, b) => b['score'].compareTo(a['score']));
  }

  void _expandRadius() {
    if (_radiusMeters >= _maxRadiusMeters) {
      _hasMore = false;
      return;
    }

    _radiusMeters = (_radiusMeters * _radiusStepFactor)
        .clamp(2000, _maxRadiusMeters);

    // reset candidates
    _dbOffset = 0;
    candidatePool.clear();
    fetchCandidates();
  }

  Future<void> _applyPosts() async {
    // if (candidatePool.isEmpty) return;
    if (_pinnedPost != null) {
      candidatePool.removeWhere(
        (p) => p['id'].toString() == _pinnedPost!.id.toString(),
      );
    }

    if (candidatePool.isEmpty && posts.isEmpty && !_hasMore) {
      setState(() {
        _status = FeedStatus.exhausted;
      });
      return;
    }

    setState(() {
      _status = FeedStatus.applyCandidates;
    });
    const batchSize = 4;

    // await Future.delayed(const Duration(seconds: 2)); // 👈 debug delay

    if (candidatePool.length < 8 && _hasMore && _status == FeedStatus.idle) {
      Future.microtask(() => fetchCandidates());
    }

    // take batch from candidates and remove from candidates
    final take = min(batchSize, candidatePool.length);
    final newPosts = candidatePool.sublist(0, take);
    candidatePool.removeRange(0, take);

    // add to seen post IDs
    for (final post in newPosts) {
      seenPostIds.add(post['id'].toString());
    }

    // if there is a pinned post apply on top, empty after
    if (_pinnedPost != null) {
      final pinnedMap = {
        'id': _pinnedPost!.id,
        'title': _pinnedPost!.title,
        'creator_id': _pinnedPost!.creatorId,
        'image_url': _pinnedPost!.imgurl,
        'description': _pinnedPost!.description,
        'activity': _pinnedPost!.activity,
        'distance': _pinnedPost!.distance,
        'pace': _pinnedPost!.pace,
        'latitude': _pinnedPost!.latitude,
        'longitude': _pinnedPost!.longitude,
        'town': _pinnedPost!.town,
        'created_at': _pinnedPost!.createdAt,
        'starts_at': _pinnedPost!.startsAt,
      };

      pinnedMap['user_distance'] = _computeDistanceMeters(pinnedMap);
      newPosts.insert(0, pinnedMap);
      _pinnedPost = null;
    }

    // fetch additional information
    for (var post in newPosts) {
      showImageMap.putIfAbsent(
        post['id'].toString(),
        () => (post["showImageMain"] as bool?) ?? true,
      );

      postTextLoaded.putIfAbsent(
        post['id'].toString(),
        () => false,
      );

      // fetch additional information
      final additionalPostData = await Future.wait([
        supabase
            .from('profiles')
            .select('avatar_url, username')
            .eq('id', post['creator_id'])
            .single() as Future<dynamic>,
        supabase
            .from('activity_participants')
            .select('user_id')
            .eq('post_id', post['id']) 
            .eq('status', 'joined') as Future<dynamic>
      ]);

      // add to post
      post['username'] = additionalPostData[0]['username'];
      post['avatar_url'] = additionalPostData[0]['avatar_url'];
      post['participant_ids'] = (additionalPostData[1] as List).map((p) => p['user_id']).toList();
    }

    setState(() {
      posts.addAll(newPosts);
      _status = candidatePool.isEmpty && !_hasMore
          ? FeedStatus.exhausted
          : FeedStatus.idle;
    });
  }

  int? _computeDistanceMeters(Map<String, dynamic> post) {
    if (!_locationEnabled || _userLat == null || _userLon == null) {
      return null;
    }

    final distance = Distance();

    final meters = distance.as(
      LengthUnit.Meter,
      LatLng(_userLat!, _userLon!),
      LatLng(post['latitude'], post['longitude']),
    );

    return meters.round();
  }

  Future<void> uploadPostImage(File? compressedImage, String path) async {
    if (compressedImage == null) return;

    await supabase.storage.from('PostImages').upload(
      path,
      compressedImage,
      fileOptions: FileOptions(upsert: true),
    );
  }

  Future<void> _openLocationPicker() async {
    final result = await showModalBottomSheet<LocationPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocationPickerSheet(),
    );
    if (result == null) return;

    await LocationPrefs.save(
      lat: result.lat, lon: result.lon, name: result.name, source: result.source,
    );

    setState(() {
      _userLat = result.lat;
      _userLon = result.lon;
      _locationEnabled = true;
      _locationSource = result.source;
      _locationLabel = result.name;
    });

    await _refreshFeed();
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

            final hasPinned = _pinnedPost != null;
            final baseCount = posts.length;
            final totalBottomPadding = standardSpacing + bottomBarHeight + fabSpacing + bottomSafeArea;

            return Column(
              children: [
                // Location selector ABOVE the list
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LocationChip(
                      label: _locationLabel,
                      source: _locationSource,
                      onTap: _openLocationPicker,
                    ),
                  ),
                ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (_status == FeedStatus.idle &&
                          scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                        _applyPosts(); // load next batch
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
                        cacheExtent: 400,
                        padding: EdgeInsets.fromLTRB(
                          standardSpacing, // left
                          standardSpacingTop, // top
                          standardSpacing, // right
                          totalBottomPadding, // bottom
                        ),
                        itemCount: posts.isEmpty
                          ? 1 // ALWAYS exactly one item during initial state
                          : baseCount + (hasPinned ? 1 : 0) + (_status == FeedStatus.exhausted ? 1 : 0) + (_status == FeedStatus.loadingMore || _status == FeedStatus.applyCandidates ? 1 : 0), // add extra item for pagination loader or feed exhausted message
                        itemBuilder: (context, index) {
                          /// 1. INITIAL LOADING STATE
                          if (_status == FeedStatus.loadingInitial && _status != FeedStatus.refreshing ) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: FeedRefreshSpinner(),
                                  ),
                                ) //PostPlaceholder(),
                            );
                          }

                          /// 2. PAGINATION LOADER (only AFTER posts exist)
                          final isFooter = index >= posts.length;

                          if (isFooter) {
                            if (_status == FeedStatus.loadingMore ||
                                _status == FeedStatus.applyCandidates) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: FeedRefreshSpinner()),
                              );
                            }
                          }

                          if (posts.isEmpty && _status == FeedStatus.exhausted) {
                            return EmptyFeedState(
                              locationLabel: _locationLabel,
                              onCreateActivity: () async {
                                final newPostPinned = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreatePostPageV2(),
                                  ),
                                );

                                if (newPostPinned != null) {
                                  setState(() {
                                    _hasMore = true;
                                    _status = FeedStatus.loadingInitial;

                                    posts.clear();
                                    candidatePool.clear();
                                    seenPostIds.clear();

                                    _dbOffset = 0;
                                    _radiusMeters = 2000;

                                    _pinnedPost = newPostPinned as Post;
                                  });

                                  await _refreshFeed();
                                }
                              },
                              onChangeLocation: _openLocationPicker,
                            );
                          }

                          if (index < posts.length) {
                            final post = posts[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                children: [
                                  RepaintBoundary(
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
                                        speed: post['speed'],
                                        date: post['date'],
                                        time: post['time'],
                                        latitude: post['latitude'],
                                        longitude: post['longitude'],
                                        town: post['town'],
                                        createdAt: post['created_at'],
                                        userdistance: post['user_distance'],
                                        startsAt: post['starts_at'],
                                      ),
                                      usernameCreator: post['username'],
                                      avatarUrlCreator: post['avatar_url'],
                                      participantIds: post["participant_ids"],
                                      showImageMain: showImageMap[post['id'].toString()] ?? true,
                                      onToggle: (val) {
                                        setState(() {
                                          showImageMap[post['id'].toString()] = val;
                                        });
                                      },
                                      onPostDeleted: (id) async{
                                        await _refreshFeed();
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Color(0x0A000000),
                                    ),
                                  ),
                                ],
                              )
                            );
                          }
                        }
                      )
                    )
                  )
                )
              ]
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(4.0),
        child: SizedBox(
          width: 58,
          height: 58,
          child: FloatingActionButton(
            onPressed: () async {
              final newPostPinned = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreatePostPageV2(),
                ),
              );
              if (newPostPinned != null) {
                // pin newly created post
                setState(() {
                  _hasMore = true;
                  _status = FeedStatus.loadingInitial;

                  posts.clear();
                  candidatePool.clear();
                  seenPostIds.clear();

                  _dbOffset = 0;
                  _radiusMeters = 2000;

                  _pinnedPost = newPostPinned as Post;
                });
          
                await _refreshFeed();
              }
            },
            backgroundColor: EnduvoColors.navy, // Colors.black,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add, size: 24),
          ),
        ),
      ),
    );
  }
}