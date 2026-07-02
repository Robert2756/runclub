import 'package:flutter/material.dart';
import 'package:run_club/settings_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/app_bar.dart';
import 'dart:io';
import 'services/image_service.dart';
import 'widgets/profile_socialproof.dart';
import 'widgets/run_card.dart';
import 'activity_page.dart';
import 'models/post.dart';
import 'package:intl/intl.dart';
import 'signin_page.dart';
final imageService = ImageService();
final supabase = Supabase.instance.client;

class ProfileContent extends StatefulWidget {
  final bool isMe;
  final int togetherCount;
  final DateTime? lastTogether;
  final String profileId;

  const ProfileContent({
    super.key,
    required this.isMe,
    required this.togetherCount,
    required this.lastTogether,
    required this.profileId,
  });

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  int _selectedTab = 0;
  List<Post> joinedRuns = [];
  List<Post> hostedRuns = [];
  bool _loadingRuns = false;
  // bool _showAllRuns = false;
  bool showCreated = false;
  Map<int, Set<int>> grouped = {};
  Map<String, bool> monthExpanded = {};
  Map<String, List<Post>> monthPosts = {};
  Map<String, bool> monthLoaded = {};
  Map<String, bool> monthLoading = {};
  bool _loadingJoined = false;
  bool _loadingCreatedMeta = false;
  bool _showAllJoined = false;
  // bool _showAllMonths = false;

  @override
  void initState() {
    super.initState();
    fetchRuns();
  }

  Future<void> fetchRuns() async {
    if (_loadingRuns) return;

    setState(() => _loadingRuns = true);

    try {
      final userId = widget.profileId;

      // 1. joined post ids
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

      // fetch months and years that need to be loaded for the creator activities
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

      setState(() {
        joinedRuns = joinedUpcomingPostsSorted;
        grouped = groupedCollect;
      });
    } catch (e) {
      debugPrint("fetchRuns error: $e");
    } finally {
      setState(() => _loadingRuns = false);
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

    final userId = widget.profileId;

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

  Widget _buildTopToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          _softToggle("Anstehend", !showCreated),
          const SizedBox(width: 16),
          _softToggle("Vergangen", showCreated),
        ],
      ),
    );
  }

  Widget _softToggle(String text, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() => showCreated = (text == "Vergangen"));
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
        child: Column(
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
                          : // Column(
                            //   children: (monthPosts[key] ?? [])
                            //       .map(
                            //         (p) => Opacity(
                            //           opacity: 0.75,
                            //           child: PostHistory(post: p),
                            //         ),
                            //       )
                            //       .toList(),
                            // ),
                            _buildRunsList(monthPosts[key] ?? []),
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRunsList(
    List<Post> runs, {
    int? limit,
    bool showMore = false,
  }) {
    if (runs.isEmpty) {
      final isJoined = _selectedTab == 0;

      return Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isJoined
                    ? "Keiner Aktivität beigetreten"
                    : "Noch keine Aktivität erstellt",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayRuns = limit != null ? runs.take(limit).toList() : runs;
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: displayRuns.length,
          itemBuilder: (context, index) {
            final post = displayRuns[index];
            final isLast = index == runs.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 6 : 0),
              child: RunCard(
                post: post,
                participantCount: null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActivityPage(
                        postId: post.id,
                        userDistance: post.userdistance,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        if (showMore)
          Padding(
            padding: const EdgeInsets.only(top: 4), // 👈 move it up visually
            child: TextButton(
              onPressed: () {
                setState(() => _showAllJoined = !_showAllJoined);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[500],
                overlayColor: Colors.transparent,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(vertical: 4),
              ),
              child: Text(
                _showAllJoined ? "Weniger anzeigen" : "Mehr anzeigen",
              ),
            ),
          ),
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 26),
      children: [
        const SizedBox(height: 10),
        // 👥 SOCIAL PROOF (only meaningful if NOT me)
        // if (!widget.isMe)
        //   SocialProofCard(
        //     togetherCount: widget.togetherCount,
        //     lastTogether: widget.lastTogether,
        //     username: "User",
        //   ),
        // const SizedBox(height: 20),

        // past runs
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTopToggle(),
          ],
        ),
        const SizedBox(height: 4),

        if (!showCreated)...[
          if (_loadingRuns)
            Column(
              children: List.generate(2, (_) => const RunCardShimmer()),
            )
          else
            _buildRunsList(joinedRuns, limit: _showAllJoined ? null : 2, showMore: joinedRuns.length > 2),
        ] else ...[
          if (grouped.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPastGrouped(grouped)
          ],
        ]

        // // Show endorsements
        // const SizedBox(height: 30),
        // if (widget.endorsements.isNotEmpty) ...[
        //   Text(
        //     "Was andere sagen",
        //     style: Theme.of(context).textTheme.titleMedium,
        //   ),
        //   const SizedBox(height: 8),

        //   ...widget.endorsements.map(
        //     (e) => MiniEndorsement(
        //       text: e["text"]!,
        //       author: e["author"]!,
        //     ),
        //   ),
        // ],

        // // 🧊 EMPTY STATE
        // if (widget.endorsements.isEmpty && widget.isMe) ...[
        //   const SizedBox(height: 40),
        //   Center(
        //     child: Text(
        //       "No endorsements yet.\nRun with others to build your profile.",
        //       textAlign: TextAlign.center,
        //       style: TextStyle(color: Colors.grey[600]),
        //     ),
        //   ),
        // ],

        // // Create endorsement
        // const SizedBox(height: 10),
        // if (!widget.isMe)
        //   Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       Row(
        //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //         children: [
        //           Text(
        //             "Endorsements",
        //             style: Theme.of(context).textTheme.titleMedium,
        //           ),
        //           TextButton.icon(
        //             onPressed: _writeEndorsement,
        //             icon: const Icon(Icons.add, size: 18),
        //             label: const Text("Hinzufügen"),
        //           ),
        //         ],
        //       ),
        //     ],
        //   ),

      ],
    );
  }
}

class ProfileHeader extends StatelessWidget {
  final bool isMe;
  final String? avatarUrl;
  final String? bio;
  final VoidCallback? onEditAvatar;
  final VoidCallback? onEditBio;
  final int? togetherCount;
  final DateTime? lastTogether;
  final VoidCallback onPrimaryAction;
  final int? age;
  final String? userName;
  final String? fullName;

  const ProfileHeader({
    required this.isMe,
    this.avatarUrl,
    this.bio,
    this.age,
    this.onEditAvatar,
    this.onEditBio,
    required this.fullName,
    required this.userName,
    required this.togetherCount,
    required this.lastTogether,
    required this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: NetworkImage(avatarUrl ?? "https://media.istockphoto.com/id/2221502929/de/vektor/flache-abbildung-in-graustufen-avatar-benutzerprofil-personensymbol-geschlechtsneutrale.jpg"),
                  ),

                  if (isMe)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 16),

              Expanded(
                child:
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            fullName ?? "Nutzer",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (age != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              "$age",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 2),

                      Text(
                        "@$userName",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  )
              ),
            ]
          ),
          const SizedBox(height: 16), 
          GestureDetector( 
            onTap: isMe ? onEditBio : null, 
            child: 
            Text( bio ?? "Noch keine Bio", 
              textAlign: TextAlign.center, 
              style: TextStyle( fontSize: 13, color: Colors.grey[700], height: 1.4,),
            )
          ),
          const SizedBox(height: 12),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: onEditBio,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black, // text + icon
                  side: const BorderSide(color: Colors.black), // border
                ),
                icon: Icon(Icons.edit, size: 16),
                label: Text("Profil bearbeiten"),
              ),
            ),
          if (!isMe)
            OutlinedButton(
              onPressed: onPrimaryAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black, // Text (and icon) color
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 32),
              ),
              child: const Text("Einladen"),
            ),

          const SizedBox(height: 12),
          // // 🔥 PRIMARY ACTION
          // if (!(isMe))
          //   Row(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: [
          //       OutlinedButton.icon(
          //         onPressed: onPrimaryAction,
          //         icon: const Icon(Icons.person_add_alt_1, size: 18),
          //         label: const Text("Einladen"),
          //         style: OutlinedButton.styleFrom(
          //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          //           shape: RoundedRectangleBorder(
          //             borderRadius: BorderRadius.circular(20),
          //           ),
          //         ),
          //       ),
          //     ],
          //   ),
        ],
      ),
    );
  }
}

class _ModernField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? errorText;
  final Function(String)? onChanged;

  const _ModernField({
    required this.label,
    required this.controller,
    this.maxLength = 30,
    this.maxLines = 1,
    this.keyboardType,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        counterText: "",
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.black),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final String profileId;

  const ProfilePage({
    super.key,
    required this.profileId,
  });
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with RouteAware {
  String? _avatarUrl;
  int? _age;
  String? _fullName;
  String? _userName;
  File? _profileImage;
  final supabase = Supabase.instance.client;
  bool get isMe => widget.profileId == supabase.auth.currentUser!.id;
  String? _bio;
  final ScrollController _scrollController = ScrollController();
  bool isRefreshing = false;
  int _togetherCount = 0;
  DateTime? _lastTogether;
  bool _loadingProfile = false;
  bool get _profileReady =>
    _userName != null;

  Future<void> _refreshProfile() async {
    await fetchProfile();
  }

  Future<void> fetchConnection() async {
    if (isMe) return; // no need to fetch for yourself

    try {
      final result = await supabase.rpc(
        'get_connection_stats',
        params: {
          'user_a': supabase.auth.currentUser!.id,
          'user_b': widget.profileId,
        },
      );

      // Supabase returns a List
      final data = (result as List).isNotEmpty ? result[0] : null;

      setState(() {
        _togetherCount = data?['together_count'] ?? 0;

        final rawDate = data?['last_together'];
        _lastTogether =
            rawDate != null ? DateTime.parse(rawDate) : null;
      });

    } catch (e) {
      debugPrint("Error fetching connection: $e");
    }
  }

  // upload profile image
  Future<void> uploadProfileImage(String userId, File? compressedImage) async {
    if (compressedImage == null) return;
    final path = '$userId.png'; // lowercase bucket name

    await supabase.storage.from('ProfileImages').upload(
      path,
      compressedImage,
      fileOptions: FileOptions(upsert: true),
    );
    // Get public URL as string
    final url = supabase.storage.from('ProfileImages').getPublicUrl(path);
    // Save URL in profile table
    await supabase.from('profiles').update({'avatar_url': url}).eq('id', userId);
  }

  // fetch profile image when loading the page
  Future<void> fetchProfile() async {
    if (_loadingProfile) return;
    _loadingProfile = true;
    try {
      final response = await supabase
          .from('profiles')
          .select('avatar_url, username, bio, age, full_name')
          .eq('id', widget.profileId)
          .single(); // fetch single row

      if (!mounted) return;

      setState(() {
        _bio = response['bio'] as String?;
        _avatarUrl = response['avatar_url'] as String?;
        _userName = response['username'] as String?;
        _age = response['age'] as int?;
        _fullName = response['full_name'] as String?;
      });
    } catch (e) {
        debugPrint('Error fetching profile image: $e');
    } finally {
      _loadingProfile = false;
    }
  }

  // initial fetch when page is first opened
  @override
  void initState() {
    super.initState();
    fetchProfile(); // fetch avatar from Supabase on page load
    fetchConnection();
  }

  // fetches when coming back to this page
  @override
  void didPopNext() {
    fetchProfile();
  }

  void _editAvatar() async {
    File? compressedImage;
    final File? pickedImage = await imageService.pickImage();
    final userId = supabase.auth.currentUser!.id;
    if (pickedImage != null) {
      final File? cropedImage = await imageService.cropImageWithUI(pickedImage);
      if (cropedImage != null) {
        compressedImage = await imageService.compressImage(cropedImage);
      }
      // Upload to Supabase storage then update profile image
      try {
        await uploadProfileImage(userId, compressedImage);
        // update UI
        setState(() {
          _profileImage = compressedImage;
        });
      } catch (e) {
        debugPrint('Upload failed: $e');
        // show error message in UI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload profile image.')),
        );
      }
    }
    setState(() {
      fetchProfile();
    });
  }

  void _editProfile() async {
    final nameController = TextEditingController(text: _fullName ?? "");
    final usernameController = TextEditingController(text: _userName ?? "");
    final bioController = TextEditingController(text: _bio ?? "");
    final ageController = TextEditingController(
      text: _age?.toString() ?? "",
    );

    String? usernameError;

    Future<bool> checkUsernameAvailable(String username) async {
      if (username.isEmpty) return false;

      final res = await supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .neq('id', widget.profileId);

      return (res as List).isEmpty;
    }

    final result = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Edit Profile",
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: SingleChildScrollView(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.92,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Profil bearbeiten",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // NAME
                            _ModernField(
                              label: "Name",
                              controller: nameController,
                              maxLength: 30,
                            ),

                            const SizedBox(height: 14),

                            // AGE
                            _ModernField(
                              label: "Alter",
                              controller: ageController,
                              maxLength: 3,
                              keyboardType: TextInputType.number,
                            ),

                            const SizedBox(height: 14),

                            // USERNAME + uniqueness check
                            _ModernField(
                              label: "Username",
                              controller: usernameController,
                              maxLength: 20,
                              errorText: usernameError,
                              onChanged: (val) async {
                                final available = await checkUsernameAvailable(val);

                                setModalState(() {
                                  usernameError = available || val.isEmpty
                                      ? null
                                      : "Username already taken";
                                });
                              },
                            ),

                            const SizedBox(height: 14),

                            // BIO
                            _ModernField(
                              label: "Bio",
                              controller: bioController,
                              maxLength: 120,
                              maxLines: 3,
                            ),

                            const SizedBox(height: 22),

                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      "Abbrechen",
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 0, 0, 0),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: usernameError != null
                                        ? null
                                        : () {
                                            Navigator.pop(context, {
                                              "name": nameController.text.trim(),
                                              "username": usernameController.text.trim(),
                                              "bio": bioController.text.trim(),
                                              "age": int.tryParse(ageController.text.trim()),
                                            });
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text("Speichern"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(anim),
            child: child,
          ),
        );
      },
    );

    if (result != null) {
      debugPrint("Result: $result");
      await supabase.from('profiles').update({
        'full_name': result["name"],
        'username': result["username"],
        'bio': result["bio"],
        'age': result["age"],
      }).eq('id', widget.profileId);

      setState(() {
        _fullName = result["name"];
        _userName = result["username"];
        _bio = result["bio"];
        _age = result["age"];
      });
    }
  }

  Future<void> _sendInvite(Post run) async {
    try {
      await supabase.from('notifications').insert({
        'from_user': supabase.auth.currentUser!.id,
        'to_user': widget.profileId,
        'post_id': run.id,
        'created_at': DateTime.now().toIso8601String(),
        'type': 'invite'
      });

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Einladung gesendet")),
      );
    } catch (e) {
      debugPrint("Invite error: $e");
    }
  }

  void _inviteUser() async {
    final myId = supabase.auth.currentUser!.id;

    final today = DateTime.now().toIso8601String().split('T')[0];

    final res = await supabase
        .from('posts')
        .select()
        .eq('creator_id', myId)
        .gte('date', today)
        .order('date', ascending: true);

    final now = DateTime.now();

    final runs = (res as List)
        .map((p) {
          final dateParts = (p['date'] as String).split('-');
          final timeParts = (p['time'] as String).split(':');

          final hour = int.parse(timeParts[0].padLeft(2, '0'));
          final minute = int.parse(timeParts[1].padLeft(2, '0'));

          final combined = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            hour,
            minute,
          );

          return MapEntry(
            combined,
            Post(
              id: p['id'].toString(),
              title: p['title'],
              creatorId: p['creator_id'],
              imgurl: p['image_url'],
              description: p['description'],
              activity: p['activity'],
              distance: p['distance'],
              pace: p['pace'],
              date: p['date'],
              time: p['time'],
              latitude: p['latitude'],
              longitude: p['longitude'],
              town: p['town'],
              createdAt: p['created_at'],
            ),
          );
        })
        .where((entry) => entry.key.isAfter(now))
        .map((entry) => entry.value)
        .toList();

    if (runs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Keine kommenden Runs verfügbar")),
      );
      return;
    }

    _showInviteSheet(runs);
  }

  void _showInviteSheet(List<Post> runs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const Text(
                    "Zu welcher deiner Aktivitäten einladen?",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: runs.length,
                      itemBuilder: (context, index) {
                        final run = runs[index];

                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              run.title,
                              style: const TextStyle(fontSize: 16),
                            ),
                            subtitle: Text(
                              DateFormat('dd.MM.yyyy').format(DateTime.parse(run.date!)),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            trailing: OutlinedButton(
                              onPressed: () => _sendInvite(run),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              child: const Text(
                                "Einladen",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppAppBar(
        actions: [
          if (isMe) ...[
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await supabase.auth.signOut();

                if(!context.mounted) return;

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const SignInPage(),
                  ),
                  (route) => false,
                );
              },
            ),
            // IconButton(
            //   tooltip: 'Settings',
            //   icon: const Icon(Icons.settings),
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (_) => const SettingsPage(title: "Settings"),
            //       ),
            //     );
            //   },
            // ),
          ],
        ],
      ),
      body: _profileReady ?
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: RefreshIndicator(
            color: Colors.black,
            backgroundColor: Colors.white,
            strokeWidth: 2.0,
            onRefresh: _refreshProfile,
            child: Column(
              children: [
                ProfileHeader(
                  isMe: isMe,
                  avatarUrl: _avatarUrl,
                  fullName: _fullName,
                  userName: _userName,
                  bio: _bio,
                  onEditAvatar: () => _editAvatar(),
                  onEditBio: () => _editProfile(),
                  togetherCount: _togetherCount,
                  lastTogether: _lastTogether,
                  onPrimaryAction: isMe ? () => _editProfile() : () => _inviteUser(),
                  age: _age,
                ),
                if (!isMe)
                  SocialProofCard(
                    togetherCount:_togetherCount,
                    lastTogether: _lastTogether,
                    username: "User",
                  ),

                const SizedBox(height: 16),

                Expanded(
                  child: ProfileContent(
                    isMe: isMe,
                    profileId: widget.profileId,
                    togetherCount: _togetherCount,
                    lastTogether: _lastTogether,
                  ),
                ),
              ],
            )
          ),
        )
      : const Center(
        child: CircularProgressIndicator(),
      )
    );
  }
}