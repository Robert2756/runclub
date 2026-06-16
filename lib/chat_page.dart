import 'package:flutter/material.dart';
import 'models/post.dart';
import 'widgets/chat.dart';

class ActivityChatPage extends StatefulWidget {
  final Post post;
  final bool initialJoined;
  final bool initialRequested;
  final int participantsCount;

  const ActivityChatPage({
    super.key,
    required this.post,
    required this.initialJoined,
    required this.initialRequested,
    required this.participantsCount,
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

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 5,
      ),
      color: Colors.white,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.pop(context),
            ),

            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundImage: widget.post.imgurl != null
                  ? NetworkImage(widget.post.imgurl!)
                  : null,
              child: widget.post.imgurl == null
                  ? const Icon(Icons.directions_run)
                  : null,
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  Text(
                    "${widget.participantsCount} ${widget.participantsCount == 1 ? "Person" : "Personen"}",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Padding(
            //   padding: const EdgeInsets.only(left: 12),
            //   child: _buildBackButton(context),
            // ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: ActivityChat(
              post: widget.post,
              initialJoined: _joined,
              initialRequested: _requested,
              isActive: true,
              markUnread: () {},
              joinMode: widget.post.joinMode,
              onActiveRead: null,
            ),
          )
        ],
      ),
    );
  }
}