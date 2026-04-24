import 'package:flutter/material.dart';
import 'post_history.dart';
import '../models/post.dart';
import 'package:intl/intl.dart';

class NextCard extends StatelessWidget {
  final Post post;

  const NextCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final dateTime = DateTime.parse(post.date!);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Next Run",
              style: TextStyle(color: Colors.white70)),

            const SizedBox(height: 8),

            Text(post.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              )),

            const SizedBox(height: 8),

            Text(
              DateFormat('EEEE, HH:mm', 'de_DE').format(dateTime),
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () {
                // navigate to detail
              },
              child: const Text("Open Run"),
            )
          ],
        ),
      ),
    );
  }
}

class UpcomingCard extends StatelessWidget {
  final List<Post> posts;

  const UpcomingCard({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: posts.map((p) => PostHistory(post: p)).toList(),
    );
  }
}