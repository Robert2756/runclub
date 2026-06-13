import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../profile_page.dart';
import '../models/post.dart';

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
  final bool initialJoined;
  final bool initialRequested;
  final ValueChanged<bool>? onJoinChanged;
  final ValueChanged<bool>? onRequestedChanged;
  final VoidCallback? onActiveRead;
  final bool isActive;
  final VoidCallback markUnread;
  final String? joinMode;
  final Post? post;

  const ActivityChat({
    super.key,
    required this.initialJoined,
    required this.initialRequested,
    this.onJoinChanged,
    this.onRequestedChanged,
    this.onActiveRead,
    required this.isActive,
    required this.markUnread,
    required this.joinMode,
    required this.post
  });

  @override
  State<ActivityChat> createState() => _ActivityChatState();
}

class _ActivityChatState extends State<ActivityChat> {
  final List<Message> _messages = [];
  final TextEditingController _inputController = TextEditingController();

  late bool _joined;
  late bool _requested;
  RealtimeChannel? _channel;

  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _loadingJoin = false;

  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _joined = widget.initialJoined;
    _requested = widget.initialRequested;
    _bootstrap();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!_joined || _requested) return;
    await _initChat();
  }

  Future<void> _initChat() async {
    await _fetchInitialMessages();
    _subscribeRealtime();
  }

  /// ----------------------
  /// FETCHING
  /// ----------------------

  Future<void> _fetchInitialMessages() async {
    if (!_joined || _requested) return;

    final res = await supabase
        .from('activity_messages')
        .select()
        .eq('activity_id', widget.post!.id)
        .order('created_at', ascending: false)
        .limit(_pageSize);

    if (widget.isActive) {
      widget.markUnread();
    }

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
        .eq('activity_id', widget.post!.id)
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
    if (!_joined || _requested) return;
    _channel = supabase.channel('activity-${widget.post!.id}');

    _channel?.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'activity_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'activity_id',
        value: widget.post!.id,
      ),
      callback: (payload) async {
        final msg = Message.fromJson(payload.newRecord);

        setState(() => _messages.insert(0, msg));

        // if currently viewing chat
        if (widget.isActive && _joined) {
          widget.onActiveRead?.call();
        }
      },
    ).subscribe();
  }

  /// ----------------------
  /// SEND MESSAGE
  /// ----------------------

  Future<void> _sendMessage() async {
    if (!_joined || _requested) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();

    final userId = supabase.auth.currentUser!.id;

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
        'activity_id': widget.post!.id,
        'user_id': userId,
        'type': 'text',
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Failed sending message: $e");
    }
  }

  Future<void> toggleJoin() async {
    if (_loadingJoin) return;
    setState(() => _loadingJoin = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      if (widget.joinMode == "Instant") {
        // activity join mode "Instant"
        await supabase.from('activity_participants').insert({
          'post_id': widget.post!.id,
          'user_id': userId,
          'last_read_at': null,
          'status': "joined" ,
          'joined_at': DateTime.now().toIso8601String(),
        });
        await supabase.from('notifications').insert({
          'from_user': userId,
          'to_user': widget.post!.creatorId,
          'post_id': widget.post!.id,
          'created_at': DateTime.now().toIso8601String(),
          'type': 'join'
        });

        setState(() {
          _joined = true;
          widget.onJoinChanged?.call(true);
        });

        await _bootstrap();
        widget.markUnread();
      } else if (widget.joinMode == "Request") {
        // activity join mode "Request"
        await supabase.from('activity_participants').insert({
          'post_id': widget.post!.id,
          'user_id': userId,
          'last_read_at': null,
          'status': "requested"
        });
        // notify creator
        await supabase.from('notifications').insert({
          'from_user': userId,
          'to_user': widget.post!.creatorId,
          'post_id': widget.post!.id,
          'created_at': DateTime.now().toIso8601String(),
          'type': 'request'
        });
        setState(() {
          _requested = true;
          widget.onRequestedChanged?.call(true);
        });
      }
    } catch (e) {
      debugPrint("Request or Join failed: $e");
    } finally {
      if (mounted) {
        setState(() => _loadingJoin = false);
      }
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


            Text(
              (widget.joinMode == "Instant")
                ? "Beitreten um Chat zu sehen"
                : (widget.joinMode == "Request")
                  ? _requested
                    ? "Auf Anfrage warten um Chat zu sehen"
                    : "Anfragen um Chat zu sehen"
                  :"",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 8),

            Text(
              "Nur Mitglieder können in dieser Aktivität Nachrichten senden und lesen.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: (_loadingJoin || _requested) ? null : toggleJoin, // disable button while loading
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: _joined ? Colors.green : Colors.black,
              ),
              child: 
                Text(
                  (widget.joinMode == "Instant")
                    ? _joined 
                      ? "Beigetreten"
                      : "Beitreten"
                    : (widget.joinMode == "Request")
                      ? _joined 
                        ? "Beigetreten"
                        : _requested
                          ? "Angefragt"
                          : "Anfragen"
                      : "",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              // child: _loadingJoin
              //   ? const SizedBox(
              //       width: 16,
              //       height: 16,
              //       child: CircularProgressIndicator(
              //         color: Colors.white,
              //         strokeWidth: 2,
              //       ),
              //     )
              //   : Text(
              //       _joined ? "Joined" : "Join",
              //       style: const TextStyle(
              //         fontWeight: FontWeight.w600,
              //         color: Colors.white,
              //       ),
              //     ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_joined || _requested) {
      return _buildJoinGate();
    }
    if (_loading || _loadingJoin) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // _buildStatusStrip(),

        Expanded(
          child: ListView.builder(
            // physics: const ClampingScrollPhysics(),
            physics: const BouncingScrollPhysics(),
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
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade300),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                decoration: const InputDecoration(
                  hintText: "Nachricht an alle Teilnehmer...",
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.black),
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