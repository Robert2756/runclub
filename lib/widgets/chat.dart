import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../profile_page.dart';

final supabase = Supabase.instance.client;
final Map<String, Profile> _profileCache = {};

/// ----------------------
/// MODEL
/// ----------------------

enum MessageType { text, system, action }

class Message {
  final String id;
  final String userId;
  final MessageType type;
  final String? content;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.userId,
    required this.type,
    this.content,
    this.meta,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      userId: json['user_id'],
      type: _parseType(json['type']),
      content: json['content'],
      meta: json['meta'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  static MessageType _parseType(String type) {
    switch (type) {
      case 'system':
        return MessageType.system;
      case 'action':
        return MessageType.action;
      default:
        return MessageType.text;
    }
  }
}

/// ----------------------
/// MAIN CHAT WIDGET
/// ----------------------

class ActivityChat extends StatefulWidget {
  final String activityId;
  final ScrollController externalController;

  const ActivityChat({
    super.key,
    required this.activityId,
    required this.externalController,
  });

  @override
  State<ActivityChat> createState() => _ActivityChatState();
}

class _ActivityChatState extends State<ActivityChat> {
  final List<Message> _messages = [];
  final TextEditingController _inputController = TextEditingController();

  late final RealtimeChannel _channel;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _joined = false;
  bool _checkingJoin = true;
  bool _loadingJoin = false;

  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    widget.externalController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    _inputController.dispose();
    widget.externalController.removeListener(_onScroll);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await checkIfJoined();

    if (_joined) {
      await _initChat();
    }
  }

  Future<void> checkIfJoined() async {
    final userId = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('activity_participants')
        .select('id')
        .eq('post_id', widget.activityId)
        .eq('user_id', userId)
        .maybeSingle();

    setState(() {
      _joined = res != null;
      _checkingJoin = false;
    });
  }

  Future<void> _initChat() async {
    await _fetchInitialMessages();
    _subscribeRealtime();
  }

  /// ----------------------
  /// FETCHING
  /// ----------------------

  Future<void> _fetchInitialMessages() async {
    if (!_joined) return;

    final res = await supabase
        .from('activity_messages')
        .select()
        .eq('activity_id', widget.activityId)
        .order('created_at', ascending: false)
        .limit(_pageSize);

    final messages =
        (res as List).map((e) => Message.fromJson(e)).toList();

    final userIds = messages.map((m) => m.userId).toList();

    await _fetchProfiles(userIds);

    setState(() {
      _messages.addAll(messages);
      _loading = false;
      _hasMore = res.length == _pageSize;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;

    setState(() => _loadingMore = true);

    final last = _messages.last;

    final res = await supabase
        .from('activity_messages')
        .select()
        .eq('activity_id', widget.activityId)
        .lt('created_at', last.createdAt.toIso8601String())
        .order('created_at', ascending: false)
        .limit(_pageSize);

    final newMessages =
        (res as List).map((e) => Message.fromJson(e)).toList();

    setState(() {
      _messages.addAll(newMessages);
      _loadingMore = false;
      _hasMore = newMessages.length == _pageSize;
    });
  }

  void _onScroll() {
    if (widget.externalController.position.pixels >=
        widget.externalController.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  Future<void> _fetchProfiles(List<String> userIds) async {
    final uniqueIds = userIds.toSet().toList();

    final res = await supabase
        .from('profiles')
        .select('id, avatar_url, username')
        .inFilter('id', uniqueIds);

    for (final row in res) {
      _profileCache[row['id']] = Profile(
        id: row['id'],
        avatarUrl: row['avatar_url'],
        username: row['username'],
      );
    }
  }

  /// ----------------------
  /// REALTIME
  /// ----------------------

  void _subscribeRealtime() {
    if (!_joined) return;
    _channel = supabase.channel('activity-${widget.activityId}');

    _channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'activity_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'activity_id',
        value: widget.activityId,
      ),
      callback: (payload) {
        final msg = Message.fromJson(payload.newRecord);
        setState(() => _messages.insert(0, msg));
      },
    ).subscribe();
  }

  /// ----------------------
  /// SEND MESSAGE
  /// ----------------------

  Future<void> _sendMessage() async {
    if (!_joined) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();

    final userId = supabase.auth.currentUser!.id;
    debugPrint("DEBUG: $text");

    final temp = Message(
      id: "temp-${DateTime.now().millisecondsSinceEpoch}",
      userId: userId,
      type: MessageType.text,
      content: text,
      createdAt: DateTime.now(),
    );

    setState(() => _messages.insert(0, temp));

    try {
      await supabase.from('activity_messages').insert({
        'activity_id': widget.activityId,
        'user_id': userId,
        'type': 'text',
        'content': text,
      });
    } catch (e) {
      debugPrint("Failed sending message: $e");
    }
  }

    Future<void> toggleJoin() async {
      if (_loadingJoin) return; // prevent multiple taps
      setState(() => _loadingJoin = true);

      try {
        if (!_joined) {
          // join activity
          await supabase.from('activity_participants').insert({
            'post_id': widget.activityId,
            'user_id': supabase.auth.currentUser!.id,
          });
        } else {
          // optionally leave activity
          await supabase.from('activity_participants')
              .delete()
              .eq('post_id', widget.activityId)
              .eq('user_id', supabase.auth.currentUser!.id);
        }

        // toggle joined state -> update button UI immediately
        setState(() => _joined = !_joined);

        // // imediately refresh participant avatars after joining/leaving
        // await fetchParticipantAvatars();

      } catch (e) {
        debugPrint('Error toggling join: $e');
        // optionally show a SnackBar or toast
      } finally {
        setState(() => _loadingJoin = false);
      }
    }

  /// ----------------------
  /// UI
  /// ----------------------
  
  Widget _buildJoinGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),

            const Text(
              "Join to access chat",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 8),

            Text(
              "Only participants can see and send messages in this activity.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _loadingJoin ? null : toggleJoin, // disable button while loading
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: _joined ? Colors.green : Colors.black,
              ),
              child: _loadingJoin
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _joined ? "Joined" : "Join",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingJoin) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_joined) {
      return _buildJoinGate();
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // _buildStatusStrip(),

        Expanded(
          child: ListView.builder(
            controller: widget.externalController,
            // physics: const ClampingScrollPhysics(),
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _messages.length,
            itemBuilder: (_, i) => _buildMessage(_messages[i]),
          ),
        ),

        _buildInput(),
      ],
    );
  }

  Widget _buildMessage(Message msg) {
    final profile = _profileCache[msg.userId];
    switch (msg.type) {
      case MessageType.system:
        return _SystemMessage(msg);
      case MessageType.action:
        return _ActionMessage(msg);
      case MessageType.text:
        return _TextMessage(
          msg: msg,
          profile: profile,);
    }
  }

  Widget _buildInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            // IconButton(
            //   icon: const Icon(Icons.add_circle_outline),
            //   onPressed: () {
            //     // later: quick actions
            //   },
            // ),
            Expanded(
              child: TextField(
                controller: _inputController,
                decoration: const InputDecoration(
                  hintText: "Write something useful…",
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------
/// MESSAGE WIDGETS
/// ----------------------

class _TextMessage extends StatelessWidget {
  final Message msg;
  final Profile? profile;

  const _TextMessage({
    required this.msg,
    required this.profile,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = msg.userId == supabase.auth.currentUser!.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) _avatar(context),
          const SizedBox(width: 6),

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? Colors.black : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                msg.content ?? "",
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),

          // const SizedBox(width: 8),
          // if (isMe) _avatar(context),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(
              profileId: msg.userId,
            ),
          ),
        );
      },
      child: CircleAvatar(
        radius: 12,
        backgroundImage: profile?.avatarUrl != null
            ? NetworkImage(profile!.avatarUrl!)
            : const NetworkImage(
                "https://www.gravatar.com/avatar/?d=mp",
              ),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final Message msg;

  const _SystemMessage(this.msg);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          msg.content ?? "",
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ActionMessage extends StatelessWidget {
  final Message msg;

  const _ActionMessage(this.msg);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg.content ?? "",
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}