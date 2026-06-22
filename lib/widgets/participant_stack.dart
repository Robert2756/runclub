import 'package:flutter/material.dart';

Widget buildParticipantStack(List<String>? avatars, int avatarsLength) {
  const double size = 30;
  const double overlap = 18;

  int visibleCount = avatarsLength > 3 ? 3 : avatarsLength;
  int remaining = avatarsLength - visibleCount;

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (avatarsLength > 0) ... [
        SizedBox(
          width: size +
              (visibleCount - 1) * overlap +
              (remaining > 0 ? overlap : 0),
          height: size,
          child: Stack(
            children: [
              for (int i = 0; i < visibleCount; i++)
                Positioned(
                  left: i * overlap,
                  child: CircleAvatar(
                    radius: size / 2,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                        avatars != null &&
                                avatars.length > i &&
                                avatars[i].isNotEmpty
                            ? NetworkImage(avatars[i])
                            : null,
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
        ),
        const SizedBox(width: 6),
      ],

      Text(
        avatarsLength > 0
        ? "$avatarsLength dabei"
        : "Noch niemand dabei",
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}