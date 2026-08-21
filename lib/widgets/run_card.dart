import 'package:flutter/material.dart';
import '../models/post.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
final supabase = Supabase.instance.client;

class RunCard extends StatefulWidget {
  final Post post;
  final int? participantCount;
  final VoidCallback onTap;
  final bool locked;

  const RunCard({
    super.key,
    required this.post,
    required this.onTap,
    this.participantCount,
    this.locked = false,
  });

  @override
  State<RunCard> createState() => _RunCardState();
}

class _RunCardState extends State<RunCard> {
  bool _imageLoaded = false;

  Post get post => widget.post;

  bool get isPast {
    final dt = DateTime.tryParse("${widget.post.date} ${post.time}") ?? DateTime.now();
    return dt.isBefore(DateTime.now());
  }

  Widget _lockedChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 10, color: Colors.grey[700]),
          const SizedBox(width: 3),
          Text(
            "Privat",
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      post.imgurl != null && post.imgurl!.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  post.imgurl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    final isLoading = progress != null;
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        child,
                                        if (isLoading)
                                          Shimmer.fromColors(
                                            baseColor: Colors.grey.shade300,
                                            highlightColor: Colors.grey.shade100,
                                            child: Container(color: Colors.grey.shade300),
                                          ),
                                      ],
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image_not_supported_outlined),
                                  ),
                                ),
                              ],
                            )
                          : _buildMiniMap(),
                      if (widget.locked)
                        Container(
                          color: Colors.black.withOpacity(0.4),
                          child: const Center(
                            child: Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
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
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Text(
                          post.town ?? "Unbekannter Ort",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),

                        const Spacer(),

                        if (widget.locked)
                          _lockedChip()
                        else if (post.creatorId == supabase.auth.currentUser!.id)
                          _statusChip(),
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
        initialZoom: 10,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
            'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0',
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
        "Erstellt",
        style: TextStyle(
          fontSize: 10,
          color: isPast ? Colors.black87 : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class RunCardShimmer extends StatelessWidget {
  const RunCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        period: const Duration(milliseconds: 1200),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // 🧱 IMAGE / MAP BLOCK
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              const SizedBox(width: 12),

              // 📊 TEXT BLOCK
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TITLE + CHIP ROW
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 50,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // LOCATION
                    Container(
                      width: 120,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // META ROW
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 40,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // CHEVRON
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}