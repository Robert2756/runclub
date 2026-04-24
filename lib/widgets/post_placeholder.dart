import 'package:flutter/material.dart';

class PostPlaceholder extends StatefulWidget {
  const PostPlaceholder({super.key});

  @override
  State<PostPlaceholder> createState() => _PostPlaceholderState();
}

class _PostPlaceholderState extends State<PostPlaceholder>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _buildContent(),
      ),
    );
  }
}

Widget _buildContent() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // --- top profile / title section ---
      Padding(
        padding: const EdgeInsets.fromLTRB(15, 5, 15, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PROFILE ROW
            Row(
              children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Container(width: 90, height: 14, color: Colors.grey[300]),
                const Spacer(),
                Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle)),
              ],
            ),
            const SizedBox(height: 10),
            Container(width: double.infinity, height: 20, color: Colors.grey[300]), // TITLE
            const SizedBox(height: 6),
            Container(width: 220, height: 15, color: Colors.grey[300]), // SUBTITLE
            const SizedBox(height: 5),
            Row(
              children: List.generate(3, (index) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle)),
              )),
            ),
          ],
        ),
      ),

      const SizedBox(height: 5),

      // --- IMAGE / MAP ---
      Stack(
        children: [
          ClipRRect(
            child: AspectRatio(
              aspectRatio: 1 / 1, // 4 / 3,
              child: Container(color: Colors.grey[300]),
            ),
          ),
        ],
      ),

      const SizedBox(height: 8),
      SizedBox(
        height: 100, // define a fixed height for the remaining section
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 6, 15, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: double.infinity,
                height: 15,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(5), // change 5 to your preferred radius
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                height: 15,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(5), // change 5 to your preferred radius
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                height: 15,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(5), // change 5 to your preferred radius
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}