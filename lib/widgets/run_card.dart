import 'package:flutter/material.dart';
import '../models/post.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RunCard extends StatelessWidget {
  final Post post;
  final int? participantCount;
  final VoidCallback onTap;

  const RunCard({
    super.key,
    required this.post,
    required this.onTap,
    this.participantCount,
  });

  bool get isPast {
    final dt = DateTime.tryParse("${post.date} ${post.time}") ?? DateTime.now();
    return dt.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final dateTime = DateTime.tryParse("${post.date} ${post.time}") ?? DateTime.now();

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPast ? Colors.grey[100] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPast ? Colors.grey.shade300 : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              // 🧭 VISUAL ANCHOR (image or map)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: post.imgurl != null
                      ? Image.network(
                          post.imgurl!,
                          fit: BoxFit.cover,
                        )
                      : _buildMiniMap(),
                ),
              ),

              const SizedBox(width: 12),

              // 📊 CONTENT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TITLE + STATUS
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isPast ? Colors.grey[700] : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusChip(),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // LOCATION + DISTANCE
                    Text(
                      "${post.town ?? "Unknown"} • ${post.distance ?? "-"} km",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),

                    const SizedBox(height: 6),

                    // META ROW
                    Row(
                      children: [
                        // Text(
                        //   DateFormat('EEE, HH:mm', 'de_DE').format(dateTime),
                        //   style: TextStyle(
                        //     fontSize: 12,
                        //     color: Colors.grey[700],
                        //   ),
                        // ),

                        const SizedBox(width: 8),

                        if (participantCount != null)
                          Text(
                            "• $participantCount going",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),

                        const Spacer(),

                        // if (!isPast)
                        //   Container(
                        //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        //     decoration: BoxDecoration(
                        //       color: Colors.black,
                        //       borderRadius: BorderRadius.circular(12),
                        //     ),
                        //     child: const Text(
                        //       "Active",
                        //       style: TextStyle(
                        //         fontSize: 10,
                        //         color: Colors.white,
                        //         fontWeight: FontWeight.w600,
                        //       ),
                        //     ),
                        //   ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // 🗺 mini map fallback (same style as your PostHistory)
  Widget _buildMiniMap() {
    final location = (post.latitude != null && post.longitude != null)
        ? LatLng(post.latitude!, post.longitude!)
        : const LatLng(0, 0);

    return FlutterMap(
      options: MapOptions(
        initialCenter: location,
        initialZoom: 11,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://api.maptiler.com/maps/basic-v2-light/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0',
          userAgentPackageName: 'com.robert.app',
        ),
      ],
    );
  }

  Widget _statusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPast ? Colors.grey.shade200 : Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPast ? "Vorbei" : "Geplant",
        style: TextStyle(
          fontSize: 10,
          color: isPast ? Colors.black87 : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}