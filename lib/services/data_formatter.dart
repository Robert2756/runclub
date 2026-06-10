import 'package:intl/intl.dart';

class DataFormatter {
  String formatPace(int secondsPerKm) {
    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;
    final secString = seconds.toString().padLeft(2, '0');
    return "$minutes:$secString/km";
  }

  String formatDistance(int distanceInMeter) {
    final km = distanceInMeter / 1000;
    String text = km.toStringAsFixed(2);

    if (text.endsWith('00')) {
      text = text.substring(0, text.length - 1); // 5.00 → 5.0
    } else if (text.endsWith('0')) {
      text = text.substring(0, text.length - 1); // 5.20 → 5.2
    }
    return text;
  }

  String timeUntil(String date, String time) {
    final event = DateTime.parse("${date}T$time");
    final now = DateTime.now();

    final diff = event.difference(now);

    if (diff.isNegative) {
      return "Gestartet";
    }

    if (diff.inDays >= 1) {
      return "${diff.inDays} Tag${diff.inDays == 1 ? "" : "e"}";
    }

    if (diff.inHours >= 1) {
      return "${diff.inHours} Stunde${diff.inHours == 1 ? "" : "n"}";
    }

    return "${diff.inMinutes} min";
  }

  String formatWeekdayWithTime(String date, String time) {
    // Parse the date + time
    final dt = DateTime.parse("${date}T$time");

    // German weekday names
    const weekdays = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];

    // Dart weekday: Monday = 1, Sunday = 7
    final weekdayName = weekdays[dt.weekday - 1];

    // Format hour and minute with leading zero if needed
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    return "$weekdayName $hour:$minute";
  }

  String formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  String formatActivityDate(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final difference = target.difference(today).inDays;

    if (difference == 0) {
      return "Heute";
    }

    if (difference == 1) {
      return "Morgen";
    }

    if (difference > 1 && difference < 7) {
      return DateFormat('EEEE', 'de_DE').format(date); // Montag
    }

    return DateFormat('d MMM', 'de_DE').format(date); // 12 May
  }

  String formatTimeAgo(DateTime lastTogether) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(lastTogether);

    if (diff.inMinutes < 60) {
      final m = diff.inMinutes < 1 ? 1 : diff.inMinutes;
      return "$m Minute${m == 1 ? '' : 'n'}";
    }

    if (diff.inHours < 24) {
      final h = diff.inHours;
      return "$h Stunde${h == 1 ? '' : 'n'}";
    }

    if (diff.inDays < 7) {
      final d = diff.inDays;
      return "$d Tag${d == 1 ? '' : 'en'}";
    }

    if (diff.inDays < 30) {
      final w = (diff.inDays / 7).floor();
      return "$w Woche${w == 1 ? '' : 'n'}";
    }

    if (diff.inDays < 365) {
      final mo = (diff.inDays / 30).floor();
      return "$mo Monat${mo == 1 ? '' : 'en'}";
    }

    final y = (diff.inDays / 365).floor();
    return "$y Jahr${y == 1 ? '' : 'en'}";
  }

  String activityRelativeTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final diffDays = target.difference(today).inDays;

    if (diffDays == 0) return "heute";
    if (diffDays == 1) return "morgen";
    if (diffDays == -1) return "gestern";

    if (diffDays > 1) return "in $diffDays Tagen";
    if (diffDays <= 1) return "vor ${diffDays.abs()} Tagen";

    return "-";
  }

  String activityRelativeTimeOnlyDays(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final diffDays = target.difference(today).inDays;

    if (diffDays == 0) return "heute";
    if (diffDays == 1) return "in 1 Tag";

    if (diffDays > 1) return "in $diffDays Tagen";
    if (diffDays <= 1) return "vor ${diffDays.abs()} Tagen";

    return "-";
  }

}