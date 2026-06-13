import 'package:flutter/material.dart';
import 'models/post.dart';
import 'widgets/chat.dart';

class ActivityChatPage extends StatefulWidget {
  final Post post;
  final bool initialJoined;
  final bool initialRequested;

  const ActivityChatPage({
    super.key,
    required this.post,
    required this.initialJoined,
    required this.initialRequested,
  });

  @override
  State<ActivityChatPage> createState() => ActivityChatPageState();
}

class ActivityChatPageState extends State<ActivityChatPage> {
  late bool _joined;
  late bool _requested;

  @override
  void initState() {
    super.initState();
    _joined = widget.initialJoined;
    _requested = widget.initialRequested;
  }

  Widget _buildBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
          ),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          ActivityChat(
            post: widget.post,
            initialJoined: _joined,
            initialRequested: _requested,
            isActive: true,
            markUnread: () {},
            joinMode: widget.post.joinMode,
            onActiveRead: null,
          ),

          // BACK BUTTON
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            child: _buildBackButton(context),
          ),
        ],
      ),
    );
  }
}