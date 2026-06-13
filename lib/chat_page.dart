import 'package:flutter/material.dart';
import 'models/post.dart';
import 'widgets/chat.dart';

class ActivityChatPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: ActivityChat(
        post: post,
        initialJoined: initialJoined,
        initialRequested: initialRequested,
        isActive: true,
        markUnread: () {},
        joinMode: post.joinMode,
        onActiveRead: null,
      ),
    );
  }
}