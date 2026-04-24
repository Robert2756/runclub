import 'package:flutter/material.dart';

class SocialProofCard extends StatelessWidget {
  final int togetherCount;
  final DateTime? lastTogether;
  final String username;

  const SocialProofCard({
    super.key,
    required this.togetherCount,
    required this.lastTogether,
    required this.username,
  });

  String _formatLast(DateTime? date) {
    if (date == null) return "noch kein gemeinsamer Lauf";

    final diff = DateTime.now().difference(date).inDays;

    if (diff == 0) return "heute zusammen gelaufen";
    if (diff == 1) return "gestern zusammen gelaufen";
    if (diff < 14) return "vor $diff Tagen zuletzt zusammen gelaufen";
    if (diff < 60) return "vor ${(diff / 7).round()} Wochen zuletzt gesehen";
    return "länger her";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_outline, size: 18),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  togetherCount == 0
                      ? "Noch keine gemeinsamen Läufe"
                      : "Ihr habt euch $togetherCount× getroffen",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatLast(lastTogether),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MiniEndorsement extends StatelessWidget {
  final String text;
  final String author;

  const MiniEndorsement({
    super.key,
    required this.text,
    required this.author,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          children: [
            TextSpan(text: "⭐ $text "),
            TextSpan(
              text: "– $author",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}