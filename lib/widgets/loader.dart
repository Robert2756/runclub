import 'package:flutter/material.dart';

class FeedRefreshSpinner extends StatelessWidget {
  const FeedRefreshSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          color: Colors.black,
        ),
      ),
    );
  }
}