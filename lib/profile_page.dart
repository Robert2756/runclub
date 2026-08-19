import 'dart:async';
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

class EnduvoColors {
  static const navy = Color(0xFF0A2647);
  static const deepBlue = Color(0xFF12406B);
  static const teal = Color(0xFF2E9DC0);
  static const gold = Color(0xFFF6C567);

  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFF6F8FB);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);
  static const muted = Color(0xFF6B7280);
  static const text = Color(0xFF111827);
}

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

    final start = DateTime(year, month, 1).toUtc();
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59).toUtc();
    final nowUtc = DateTime.now().toUtc();

    // Never query past "now" — a month can be partially in the future
    // (the current month), and this tab must only ever show activities
    // that have already happened.
    final effectiveEnd = endOfMonth.isBefore(nowUtc) ? endOfMonth : nowUtc;

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
        .lt('starts_at', effectiveEnd.toIso8601String()); // lt, matching the "past" query above

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
              fontSize: 15,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active
                  ? EnduvoColors.text
                  : EnduvoColors.muted,
            ),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 2,
            width: active ? 20 : 0,
            decoration: BoxDecoration(
              color: active
                ? EnduvoColors.text
                : EnduvoColors.muted,
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

  Widget _buildSoftEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: EnduvoColors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnduvoColors.background,
              ),
              child: Icon(
                icon,
                size: 20,
                color: EnduvoColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: EnduvoColors.muted,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
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

      return _buildSoftEmptyState(
        icon: isJoined
            ? Icons.calendar_today_outlined
            : Icons.history_rounded,
        message: isJoined
            ? "Keiner Aktivität beigetreten"
            : "Noch keine Aktivität erstellt",
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 10),
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
            // const SizedBox(height: 8),
            _buildPastGrouped(grouped)
          ] else ...[
            // const SizedBox(height: 12),
            _buildSoftEmptyState(
              icon: Icons.history_rounded,
              message: "Noch keine vergangenen Aktivitäten",
            ),
          ],
        ]
      ],
    );
  }
}

class _ExpandableChip extends StatefulWidget {
  final IconData? icon;
  final String text;
  final TextStyle textStyle;
  final Color backgroundColor;
  final EdgeInsets padding;

  const _ExpandableChip({
    required this.text,
    required this.textStyle,
    this.icon,
    this.backgroundColor = const Color(0xFFEEEEEE),
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  });

  @override
  State<_ExpandableChip> createState() => _ExpandableChipState();
}

class _ExpandableChipState extends State<_ExpandableChip>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _autoHideTimer;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  void _toggle() {
    if (_overlayEntry != null) {
      _hide();
    } else {
      _show();
    }
  }

  void _show() {
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(builder: (_) => _buildOverlay());
    overlay.insert(_overlayEntry!);
    _controller.forward(from: 0);

    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 3), _hide);
  }

  Future<void> _hide() async {
    _autoHideTimer?.cancel();
    if (_overlayEntry == null) return;
    await _controller.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlay() {
    return Stack(
      children: [
        // Invisible full-screen layer so tapping anywhere else dismisses it.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hide,
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, -24),
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.bottomLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _overlayEntry?.remove();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: widget.textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
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
  final String? town;
  final bool isUploadingAvatar;

  const ProfileHeader({
    required this.isMe,
    this.avatarUrl,
    this.bio,
    this.age,
    this.town,
    this.onEditAvatar,
    this.onEditBio,
    this.isUploadingAvatar = false,
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
                  Builder(
                    builder: (context) {
                      final resolvedUrl = avatarUrl ??
                          "https://media.istockphoto.com/id/2221502929/de/vektor/flache-abbildung-in-graustufen-avatar-benutzerprofil-personensymbol-geschlechtsneutrale.jpg";
                      // Unique enough per profile screen: tied to
                      // whether it's "my" avatar and the current image
                      // URL, so different profiles/pictures don't
                      // collide with an in-flight Hero from another one.
                      final heroTag = 'profile-avatar-$isMe-$resolvedUrl';

                      return GestureDetector(
                        // Tapping the picture (not the edit icon) opens
                        // the full-screen viewer, for me and for other
                        // users alike. Disabled mid-upload so it can't
                        // open on a stale/in-flight image.
                        onTap: isUploadingAvatar
                            ? null
                            : () => _openAvatarViewer(
                                  context,
                                  resolvedUrl,
                                  heroTag,
                                ),
                        child: Hero(
                          tag: heroTag,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: NetworkImage(resolvedUrl),
                          ),
                        ),
                      );
                    },
                  ),

                  // Spinner overlay while a new avatar is uploading.
                  // Clipped to a circle so it matches the avatar shape
                  // instead of spilling into a square corner.
                  if (isUploadingAvatar)
                    Positioned.fill(
                      child: ClipOval(
                        child: Container(
                          color: Colors.black.withOpacity(0.35),
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (isMe)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        // Disabled while an upload is already in
                        // flight so it can't be triggered twice.
                        onTap: isUploadingAvatar ? null : onEditAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: EnduvoColors.text,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
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
                          Flexible(
                            child: Text(
                              fullName ?? "Nutzer",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: EnduvoColors.text,
                              ),
                            ),
                          ),
                          if (age != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              "$age",
                              style: const TextStyle(
                                fontSize: 14,
                                color: EnduvoColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 2),

                      Row(
                        children: [
                          if (town != null && town!.isNotEmpty)
                            // Town gets 3 parts of the shared space; tap
                            // reveals the full name via _ExpandableChip.
                            Flexible(
                              flex: 3,
                              child: _ExpandableChip(
                                icon: Icons.location_on_outlined,
                                text: town!,
                                textStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),

                          const SizedBox(width: 6),

                          // Username gets 2 parts, same tap-to-reveal
                          // behavior as the town chip — kept visually
                          // as plain text (no pill background) to match
                          // the original look, just tappable now.
                          Flexible(
                            flex: 2,
                            child: _ExpandableChip(
                              text: "@$userName",
                              textStyle: const TextStyle(
                                fontSize: 13,
                                color: EnduvoColors.muted,
                              ),
                              backgroundColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      )
                    ],
                  )
              ),
            ]
          ),
          const SizedBox(height: 16), 
          GestureDetector( 
            onTap: isMe ? onEditBio : null, 
            child: 
            Text(
              bio ?? "Noch keine Bio",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: EnduvoColors.muted,
                height: 1.45,
              ),
            )
          ),
          const SizedBox(height: 12),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: onEditBio,
                style: OutlinedButton.styleFrom(
                  foregroundColor: EnduvoColors.text,
                  side: const BorderSide(
                    color: EnduvoColors.border,
                  ),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                ),
                label: const Text(
                  "Profil bearbeiten",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          if (!isMe)
            OutlinedButton(
              onPressed: onPrimaryAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: EnduvoColors.text,
                side: const BorderSide(
                  color: EnduvoColors.border,
                ),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Einladen",
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          const SizedBox(height: 12),
        ],
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
  String? _town;
  String? _fullName;
  String? _userName;
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
  bool _uploadingAvatar = false;
  int _avatarCacheBuster = 0;
  String? get _displayAvatarUrl =>
    _avatarUrl == null ? null : '$_avatarUrl?v=$_avatarCacheBuster';

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
  Future<void> uploadProfileImage(
    String userId,
    File? compressedImage,
  ) async {
    if (compressedImage == null) return;

    // Get the currently stored avatar URL first.
    final oldProfile = await supabase
        .from('profiles')
        .select('avatar_url')
        .eq('id', userId)
        .single();

    final oldUrl = oldProfile['avatar_url'] as String?;

    // Use a unique filename so caches can never serve the old image.
    final newPath =
        '$userId-${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      // 1. Upload the new image first.
      await supabase.storage.from('ProfileImages').upload(
        newPath,
        compressedImage,
        fileOptions: const FileOptions(
          contentType: 'image/png',
        ),
      );

      // 2. Get the new public URL.
      final newUrl = supabase.storage
          .from('ProfileImages')
          .getPublicUrl(newPath);

      // 3. Update the database.
      await supabase
          .from('profiles')
          .update({'avatar_url': newUrl})
          .eq('id', userId);

      // 4. Only now delete the old image.
      if (oldUrl != null && oldUrl.isNotEmpty) {
        try {
          final oldUri = Uri.parse(oldUrl);

          // Extract the path after /ProfileImages/
          final marker = '/ProfileImages/';
          final index = oldUri.path.indexOf(marker);

          if (index != -1) {
            final oldPath = oldUri.path.substring(
              index + marker.length,
            );

            await supabase.storage
                .from('ProfileImages')
                .remove([oldPath]);
          }
        } catch (e) {
          // The new avatar is already working, so don't fail
          // the whole operation just because cleanup failed.
          debugPrint('Could not delete old avatar: $e');
        }
      }
    } catch (e) {
      // If upload or DB update fails, the old avatar remains untouched.
      debugPrint('Profile image upload failed: $e');
      rethrow;
    }
  }

  // fetch profile image when loading the page
  Future<void> fetchProfile() async {
    if (_loadingProfile) return;
    _loadingProfile = true;
    try {
      final response = await supabase
          .from('profiles')
          .select('avatar_url, username, bio, age, full_name, town')
          .eq('id', widget.profileId)
          .single(); // fetch single row

      if (!mounted) return;

      setState(() {
        _bio = response['bio'] as String?;
        _avatarUrl = response['avatar_url'] as String?;
        _userName = response['username'] as String?;
        _age = response['age'] as int?;
        _fullName = response['full_name'] as String?;
        _town = response['town'] as String?;
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
    // User cancelled the picker: nothing to do, nothing to spin.
    final File? pickedImage = await imageService.pickImage();
    if (pickedImage == null) return;

    final userId = supabase.auth.currentUser!.id;

    final File? croppedImage = await imageService.cropImageWithUI(pickedImage);
    if (croppedImage == null) return; // cancelled the crop step

    final File? compressedImage = await imageService.compressImage(croppedImage);

    setState(() => _uploadingAvatar = true);

    try {
      await uploadProfileImage(userId, compressedImage);
      await fetchProfile();

      if (!mounted) return;
      setState(() {
        // Bump the cache buster so the (same) public URL is treated
        // as a new image and actually reloads.
        _avatarCacheBuster++;
      });
    } catch (e) {
      debugPrint('Upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload profile image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _editProfile() async {
    final nameController = TextEditingController(text: _fullName ?? "");
    final usernameController = TextEditingController(text: _userName ?? "");
    final bioController = TextEditingController(text: _bio ?? "");
    final ageController = TextEditingController(
      text: _age?.toString() ?? "",
    );
    final townController = TextEditingController(text: _town ?? "");

    String? usernameError;
    bool isSaving = false;

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
                          color: EnduvoColors.background,
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

                            // // USERNAME + uniqueness check
                            // _ModernField(
                            //   label: "Username",
                            //   controller: usernameController,
                            //   maxLength: 20,
                            //   errorText: usernameError,
                            //   onChanged: (val) async {
                            //     final available = await checkUsernameAvailable(val);

                            //     setModalState(() {
                            //       usernameError = available || val.isEmpty
                            //           ? null
                            //           : "Username already taken";
                            //     });
                            //   },
                            // ),

                            // USERNAME — locked
                            _ModernField(
                              label: "Username",
                              controller: usernameController,
                              maxLength: 20,
                              enabled: false,
                              suffixIcon: const Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: EnduvoColors.muted,
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Town
                            _ModernField(
                              label: "Stadt",
                              controller: townController,
                              maxLength: 30,
                            ),

                            const SizedBox(height: 14),

                            // BIO
                            _ModernField(
                              label: "Bio",
                              controller: bioController,
                              maxLength: 120,
                              maxLines: 3,
                            ),

                            const SizedBox(height: 14),

                            // AGE
                            _ModernField(
                              label: "Alter",
                              controller: ageController,
                              maxLength: 3,
                              keyboardType: TextInputType.number,
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
                                    onPressed: (usernameError != null || isSaving)
                                        ? null
                                        : () async {
                                            setModalState(() {
                                              isSaving = true;
                                            });

                                            final updatedProfile = {
                                              "name": nameController.text.trim(),
                                              "bio": bioController.text.trim(),
                                              "age": int.tryParse(ageController.text.trim()),
                                              "town": townController.text.trim(),
                                            };

                                            try {
                                              await supabase.from('profiles').update({
                                                'full_name': updatedProfile["name"],
                                                'bio': updatedProfile["bio"],
                                                'age': updatedProfile["age"],
                                                'town': updatedProfile["town"],
                                              }).eq('id', widget.profileId);

                                              setState(() {
                                                _fullName = updatedProfile["name"].toString();
                                                _bio = updatedProfile["bio"].toString();
                                                _age = int.tryParse(updatedProfile["age"].toString());
                                                _town = updatedProfile["town"].toString();
                                              });

                                              // Update the profile page data from Supabase
                                              await fetchProfile();

                                              if (context.mounted) {
                                                Navigator.pop(context);
                                              }

                                            } catch (e) {
                                              debugPrint("Profile update error: $e");

                                              setModalState(() {
                                                isSaving = false;
                                              });
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: isSaving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text("Speichern"),
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
    final profileId = widget.profileId;

    final today = DateTime.now().toIso8601String().split('T')[0];

    final res = await supabase.rpc(
      'get_invitable_posts',
      params: {
        'p_creator_id': myId,
        'p_profile_id': profileId,
        'p_today': today,
      },
    );

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
        const SnackBar(content: Text("Keine freie Aktivität vorhanden")),
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
      backgroundColor: EnduvoColors.background, // Colors.white,
      appBar: AppAppBar(
        actions: [
          if (isMe) ...[
            IconButton(
              tooltip: 'Abmelden',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final shouldSignOut = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text(
                        'Abmelden?',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      content: const Text(
                        'Möchtest du dich wirklich von deinem Konto abmelden?',
                        style: TextStyle(
                          color: Colors.black87,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Abbrechen'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Abmelden'),
                        ),
                      ],
                    );
                  },
                );

                if (shouldSignOut != true) return;

                try {
                  await supabase.auth.signOut();
                } catch (e) {
                  debugPrint('Logout failed: $e');

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Abmelden fehlgeschlagen. Bitte erneut versuchen.'),
                    ),
                  );
                }
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
body: _profileReady
    ? SafeArea(
        child: RefreshIndicator(
          color: Colors.black,
          backgroundColor: Colors.white,
          strokeWidth: 2.0,
          onRefresh: _refreshProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ProfileHeader(
                    isMe: isMe,
                    avatarUrl: _displayAvatarUrl,
                    fullName: _fullName,
                    userName: _userName,
                    town: _town,
                    bio: _bio,
                    onEditAvatar: _editAvatar,
                    onEditBio: _editProfile,
                    togetherCount: _togetherCount,
                    lastTogether: _lastTogether,
                    onPrimaryAction: isMe ? _editProfile : _inviteUser,
                    age: _age,
                    isUploadingAvatar: _uploadingAvatar,
                  ),
                  if (!isMe) ...[
                    const SizedBox(height: 12),
                    SocialProofCard(
                      togetherCount: _togetherCount,
                      lastTogether: _lastTogether,
                      username: "User",
                    ),
                  ],
                  const SizedBox(height: 16),
                  ProfileContent(
                    isMe: isMe,
                    profileId: widget.profileId,
                    togetherCount: _togetherCount,
                    lastTogether: _lastTogether,
                  ),
                ],
              ),
            ),
          ),
        ),
      )
    : const Center(child: CircularProgressIndicator()),
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
  final Widget? suffixIcon;
  final Color? borderColor;
  final bool enabled;

  const _ModernField({
    required this.label,
    required this.controller,
    this.maxLength = 30,
    this.maxLines = 1,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.suffixIcon,
    this.borderColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBorderColor =
        borderColor ?? EnduvoColors.border;
    final resolvedFocusColor =
        borderColor ?? EnduvoColors.deepBlue;

    return TextField(
      controller: controller,
      enabled: enabled,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        suffixIcon: suffixIcon,
        counterText: "",
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: resolvedBorderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: resolvedBorderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: resolvedFocusColor,
            width: 1.4,
          ),
        ),
        labelStyle: const TextStyle(
          color: EnduvoColors.muted,
        ),
      ),
    );
  }
}


/// Opens a full-screen viewer for the given avatar image, flying in from
/// wherever the tapped avatar is via a Hero animation.
void _openAvatarViewer(BuildContext context, String url, Object heroTag) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AvatarViewer(url: url, heroTag: heroTag);
      },
    ),
  );
}

/// Full-screen avatar viewer: fades/dims in, the avatar itself morphs
/// from a circle into a rounded rectangle via the Hero flight, supports
/// pinch-to-zoom, and dismisses either by tapping the backdrop or by
/// dragging the image down/up (with live opacity + scale feedback,
/// similar to Instagram/Twitter's photo viewers).
class _AvatarViewer extends StatefulWidget {
  final String url;
  final Object heroTag;

  const _AvatarViewer({required this.url, required this.heroTag});

  @override
  State<_AvatarViewer> createState() => _AvatarViewerState();
}

class _AvatarViewerState extends State<_AvatarViewer> {
  double _dragOffset = 0;
  double _dragProgress = 0; // 0 = not dragging, 1 = dismiss threshold

  static const double _dismissThreshold = 140;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
      _dragProgress =
          (_dragOffset.abs() / _dismissThreshold).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() > _dismissThreshold ||
        details.velocity.pixelsPerSecond.dy.abs() > 800) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _dragOffset = 0;
      _dragProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final backdropOpacity = 0.9 * (1 - _dragProgress * 0.6);
    final imageScale = 1 - _dragProgress * 0.12;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Material(
        color: Colors.black.withOpacity(backdropOpacity),
        child: SafeArea(
          child: Center(
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Transform.scale(
                scale: imageScale,
                child: Hero(
                  tag: widget.heroTag,
                  flightShuttleBuilder: (
                    flightContext,
                    animation,
                    direction,
                    fromContext,
                    toContext,
                  ) {
                    final forward = direction == HeroFlightDirection.push;
                    final radiusTween = forward
                        ? Tween<double>(begin: 50, end: 24)
                        : Tween<double>(begin: 24, end: 50);
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) => ClipRRect(
                        borderRadius: BorderRadius.circular(
                          radiusTween.evaluate(animation),
                        ),
                        child: child,
                      ),
                      child: Image.network(widget.url, fit: BoxFit.cover),
                    );
                  },
                  child: GestureDetector(
                    // Absorb taps on the image itself so pinch/zoom
                    // gestures don't also trigger the dismiss-on-tap
                    // behind it.
                    onTap: () {},
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Image.network(
                          widget.url,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
