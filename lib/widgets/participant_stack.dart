import 'package:flutter/material.dart';

Widget buildParticipantStack(List<String> avatars) {
  const double size = 30;
  const double overlap = 18;

  int visibleCount = avatars.length > 3 ? 3 : avatars.length;
  int remaining = avatars.length - visibleCount;

  return SizedBox(
    width: size + (visibleCount - 1) * overlap + (remaining > 0 ? overlap : 0),
    height: size,
    child: Stack(
      children: [
        for (int i = 0; i < visibleCount; i++)
          Positioned(
            left: i * overlap,
            child: CircleAvatar(
              radius: size / 2,
              backgroundImage: NetworkImage(avatars[i]),
            ),
          ),

        if (remaining > 0)
          Positioned(
            left: visibleCount * overlap,
            child: CircleAvatar(
              radius: size / 2,
              backgroundColor: Colors.grey[200],
              child: Text(
                "+$remaining",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}