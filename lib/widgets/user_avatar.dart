import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String userId;
  final double radius;

  const UserAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.userId,
    this.radius = 20,
  });

  Color avatarColor(String userId) {
    const colors = [
      Color(0xFFE57373),
      Color(0xFF64B5F6),
      Color(0xFF81C784),
      Color(0xFFFFB74D),
      Color(0xFFBA68C8),
      Color(0xFF4DB6AC),
      Color(0xFFA1887F),
      Color(0xFF7986CB),
      Color(0xFFFF8A65),
      Color(0xFF90A4AE),
    ];

    return colors[userId.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          imageUrl != null ? Colors.grey[300] : avatarColor(userId),
      backgroundImage:
          imageUrl != null ? NetworkImage(imageUrl!) : null,
      child: imageUrl == null
          ? Text(
              name[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: radius,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}