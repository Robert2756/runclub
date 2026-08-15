import 'dart:io';
import 'services/map_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'widgets/select_data.dart';
import 'services/data_formatter.dart';
import 'services/image_service.dart';
import 'widgets/map_pointer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/post.dart';
final supabase = Supabase.instance.client;
final FocusNode descriptionFocus = FocusNode();
final FocusNode titleFocus = FocusNode();
final FocusNode locationFocus = FocusNode();
final FocusNode meetingPointFocus = FocusNode();

class EnduvoColors {
  static const navy = Color(0xFF0A2647);
  static const deepBlue = Color(0xFF12406B);
  static const teal = Color(0xFF2E9DC0);
  static const gold = Color(0xFFF6C567);

  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFF6F8FB);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);
  static const muted = Color(0xFF6B7280);
  static const text = Color(0xFF111827);
}

class _BasicSection extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController dateController;
  final TextEditingController timeController;
  final String activity;
  final ValueChanged<String> onActivityChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final DateTime? date;
  final TimeOfDay? time;
  final String? missingField;
  final ValueChanged<int?> onPaceChanged;
  final ValueChanged<int?> onSpeedChanged;
  final bool isBlockedByLimit;

  const _BasicSection({
    required this.titleController,
    required this.descriptionController,
    required this.dateController,
    required this.timeController,
    required this.activity,
    required this.onActivityChanged,
    required this.onPickDate,
    required this.onPickTime,
    required this.date,
    required this.time,
    required this.missingField,
    required this.onPaceChanged,
    required this.onSpeedChanged,
    required this.isBlockedByLimit,
  });

  InputDecoration _fieldDecoration({
    required String hintText,
    bool isError = false,
    int? maxLength,
  }) {
    return InputDecoration(
      hintText: hintText,
      counterText: maxLength != null ? null : "",
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      filled: true,
      fillColor: EnduvoColors.surface,
      hintStyle: const TextStyle(
        color: EnduvoColors.muted,
        fontSize: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isError
              ? Colors.redAccent
              : EnduvoColors.border,
          width: isError ? 1.4 : 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isError
              ? Colors.redAccent
              : EnduvoColors.deepBlue,
          width: 1.4,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: EnduvoColors.border,
        ),
      ),
    );
  }

  Widget _activityField(BuildContext context) {
    return InkWell(
      onTap: () async {
        descriptionFocus.unfocus();
        titleFocus.unfocus();
        locationFocus.unfocus();
        meetingPointFocus.unfocus();

        await _showActivityDialog(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          color: EnduvoColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: EnduvoColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getActivityIcon(activity),
              size: 20,
              color: EnduvoColors.text,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                activity.isEmpty
                    ? "Aktivität wählen"
                    : activity,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: activity.isEmpty
                      ? EnduvoColors.muted
                      : EnduvoColors.text,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 21,
              color: EnduvoColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActivityDialog(BuildContext context) async {
    final activities = ["Laufen", "Radfahren"];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Aktivität wählen",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: EnduvoColors.text,
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 320,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final item = activities[index];
                      final isSelected = item == activity;

                      return Theme(
                        data: Theme.of(context).copyWith(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          focusColor: Colors.transparent,
                        ),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 3,
                          ),
                          leading: Icon(
                            _getActivityIcon(item),
                            color: EnduvoColors.text,
                          ),
                          title: Text(
                            item,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: EnduvoColors.text,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: EnduvoColors.deepBlue,
                                )
                              : null,
                          selected: false,
                          tileColor: Colors.transparent,
                          onTap: () {
                            if (item != activity) {
                              onPaceChanged(null);
                              onSpeedChanged(null);
                            }

                            onActivityChanged(item);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getActivityIcon(String activity) {
    switch (activity) {
      case "Laufen":
        return Icons.directions_run;
      case "Radfahren":
        return Icons.directions_bike;
      case "Walk":
        return Icons.directions_walk;
      case "Trail":
        return Icons.terrain;
      default:
        return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isBlockedByLimit)
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9EC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF2D48A),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: Color(0xFF8A5A00),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Du hast bereits 2 aktive Aktivitäten. Erstelle eine neue, sobald eine beendet ist.",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6D4C00),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // TITLE
        TextField(
          controller: titleController,
          focusNode: titleFocus,
          maxLength: 80,
          decoration: _fieldDecoration(
            hintText: "Titel deiner Aktivität",
            isError: missingField == "title",
            maxLength: 80,
          ),
        ),

        const SizedBox(height: 10),

        // DESCRIPTION
        TextField(
          controller: descriptionController,
          focusNode: descriptionFocus,
          maxLines: 3,
          maxLength: 500,
          decoration: _fieldDecoration(
            hintText: "Beschreibung...",
            maxLength: 500,
          ),
        ),

        const SizedBox(height: 18),

        // ACTIVITY
        _activityField(context),

        const SizedBox(height: 12),

        // DATE + TIME
        Row(
          children: [
            Expanded(
              child: _bigSelector(
                context: context,
                icon: Icons.calendar_today_outlined,
                label: date == null
                    ? "Datum wählen"
                    : "${date!.day.toString().padLeft(2, '0')}.${date!.month.toString().padLeft(2, '0')}.${date!.year}",
                onTap: onPickDate,
                isError: missingField == "date",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bigSelector(
                context: context,
                icon: Icons.access_time_outlined,
                label: time == null
                    ? "Zeit wählen"
                    : time!.format(context),
                onTap: onPickTime,
                isError: missingField == "time",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bigSelector({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isError = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError
                ? Colors.redAccent
                : EnduvoColors.border,
            width: isError ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: EnduvoColors.text,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: label.contains("wählen")
                      ? EnduvoColors.muted
                      : EnduvoColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final String activity;

  final int? distance;
  final int? paceSeconds;
  final int? speed;

  final ValueChanged<int?> onDistanceChanged;
  final VoidCallback onPickDistance;

  final ValueChanged<int?> onPaceChanged;
  final ValueChanged<int?> onSpeedChanged;

  const _DetailsSection({
    required this.activity,
    required this.distance,
    required this.paceSeconds,
    required this.speed,
    required this.onDistanceChanged,
    required this.onPickDistance,
    required this.onPaceChanged,
    required this.onSpeedChanged,
  });

  Widget _selectorTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final isPlaceholder = value.isEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: EnduvoColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: EnduvoColors.muted,
                      ),
                    ),
                    if (value.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: EnduvoColors.text,
                        ),
                      ),
                    ],
                    if (isPlaceholder)
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text(
                          "Nicht angegeben",
                          style: TextStyle(
                            fontSize: 14,
                            color: EnduvoColors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: EnduvoColors.muted,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _selectorTile(
          label: "Distanz",
          value: distance == null
              ? ""
              : DataFormatter().formatDistance(distance!),
          onTap: () async {
            descriptionFocus.unfocus();
            titleFocus.unfocus();
            locationFocus.unfocus();
            meetingPointFocus.unfocus();

            final result =
                await SelectDataCustom().showDistanceDialog(context);

            if (result != null) {
              onDistanceChanged(result);
            }
          },
        ),

        const SizedBox(height: 10),

        _selectorTile(
          label: activity == "Laufen"
              ? "Pace"
              : "Geschwindigkeit",
          value: activity == "Laufen"
              ? paceSeconds == null
                  ? ""
                  : DataFormatter().formatPace(paceSeconds!)
              : speed == null
                  ? ""
                  : "$speed km/h",
          onTap: () async {
            descriptionFocus.unfocus();
            titleFocus.unfocus();
            locationFocus.unfocus();
            meetingPointFocus.unfocus();

            if (activity == "Laufen") {
              final result =
                  await SelectDataCustom().showPaceDialog(context);

              if (result != null) {
                onPaceChanged(result);
              }
            } else {
              final result =
                  await SelectDataCustom().showSpeedDialog(context);

              if (result != null) {
                onSpeedChanged(result);
              }
            }
          },
        ),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  final MapController mapController;
  final LatLng? mapCenter;
  final ValueChanged<LatLng> onLocationChanged;
  final String mapUrl;

  final TextEditingController townController;
  final TextEditingController meetingPointController;

  final VoidCallback onHelpPressed;
  final ValueChanged<String> onTownSubmitted;
  final bool mapReady;

  final VoidCallback onMapReady;
  final String activity;

  const _LocationSection({
    required this.mapController,
    required this.mapCenter,
    required this.onLocationChanged,
    required this.mapUrl,
    required this.townController,
    required this.meetingPointController,
    required this.onHelpPressed,
    required this.onTownSubmitted,
    required this.mapReady,
    required this.onMapReady,
    required this.activity,
  });

  Widget _buildTownField(BuildContext context) {
    return TextField(
      controller: townController,
      textInputAction: TextInputAction.search,
      onSubmitted: onTownSubmitted,
      decoration: InputDecoration(
        hintText: "Ort suchen (z.B. Erfurt)",
        hintStyle: const TextStyle(
          color: EnduvoColors.muted,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        filled: true,
        fillColor: Colors.white,

        prefixIcon: IconButton(
          icon: const Icon(
            Icons.help_outline,
            size: 19,
            color: EnduvoColors.muted,
          ),
          onPressed: () {
            showDialog(
              barrierColor: Colors.black.withOpacity(0.15),
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: const Text(
                  "Ort",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                content: const Text(
                  "Hier kannst du grob den Ort deiner Aktivität auf der Karte auswählen. Beim Angeben von konkreten Treffpunkten, versuch möglichst öffentliche Orte zu wählen.",
                ),
              ),
            );
          },
        ),

        suffixIcon: IconButton(
          icon: const Icon(
            Icons.arrow_forward_rounded,
            color: EnduvoColors.text,
          ),
          onPressed: () =>
              onTownSubmitted(townController.text),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: EnduvoColors.border,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: EnduvoColors.deepBlue,
            width: 1.4,
          ),
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter:
              mapCenter ?? const LatLng(51.509364, -0.128928),
          initialZoom: 13,
          onMapReady: () {
            onMapReady();
          },
          onPositionChanged: (position, hasGesture) {
            Future.delayed(
              const Duration(milliseconds: 300),
              () {
                onMapReady();
              },
            );
          },
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onTap: (tapPosition, point) {
            onLocationChanged(point);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: mapUrl,
            userAgentPackageName: 'com.robert.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: mapCenter ??
                    const LatLng(
                      51.509364,
                      -0.128928,
                    ),
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      activity == "Radfahren"
                          ? Icons.directions_bike
                          : Icons.directions_run,
                      color: EnduvoColors.text,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTownField(context),

        const SizedBox(height: 14),

        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              _buildMap(),

              if (!mapReady)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.04),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(
                          EnduvoColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        TextField(
          controller: meetingPointController,
          focusNode: meetingPointFocus,
          maxLength: 80,
          decoration: InputDecoration(
            hintText:
                "Konkreter Treffpunkt, z.B. Eingang Park, ...",
            hintStyle: const TextStyle(
              color: EnduvoColors.muted,
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            filled: true,
            fillColor: Colors.white,

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: EnduvoColors.border,
              ),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: EnduvoColors.deepBlue,
                width: 1.4,
              ),
            ),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaSection extends StatelessWidget {
  final File? image;
  final VoidCallback onPickImage;

  const _MediaSection({
    required this.image,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(14),
          border: image == null
              ? Border.all(
                  color: EnduvoColors.border,
                )
              : null,
        ),
        child: image == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: EnduvoColors.muted,
                      size: 25,
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      "Fotos hinzufügen",
                      style: TextStyle(
                        color: EnduvoColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Beiträge mit Bildern erhalten mehr Aufmerksamkeit",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: EnduvoColors.muted,
                      ),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(
                          image!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Foto ändern",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: EnduvoColors.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "Tippen zum Ersetzen",
                            style: TextStyle(
                              fontSize: 13,
                              color: EnduvoColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: EnduvoColors.muted,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

enum JoinMode {
  instant,
  request,
  inviteOnly,
}

enum GroupRestriction {
  everyone,
  flinta,
}

class _SettingsSection extends StatelessWidget {
  final JoinMode joinMode;
  final ValueChanged<JoinMode> onJoinModeChanged;

  const _SettingsSection({
    required this.joinMode,
    required this.onJoinModeChanged,
  });

  String joinModeStringToGermanUI(String mode) {
    switch (mode) {
      case 'Instant':
        return 'Offen';
      case 'Request':
        return 'Anfrage';
      case 'Invite':
        return 'Einladung';
      default:
        return mode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _sectionTitle("Beitritt"),

        const SizedBox(height: 8),

        _segmentedSelector<JoinMode>(
          value: joinMode,
          options: const {
            JoinMode.instant: "Instant",
            JoinMode.request: "Request",
            JoinMode.inviteOnly: "Invite",
          },
          onChanged: onJoinModeChanged,
        ),

        const SizedBox(height: 7),

        _description(
          joinMode == JoinMode.instant
              ? "Jeder kann sofort beitreten"
              : joinMode == JoinMode.request
                  ? "Beitritt nur auf Anfrage möglich"
                  : "Nur eingeladene Leute können beitreten",
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        "Beitritt",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: EnduvoColors.muted,
        ),
      ),
    );
  }

  Widget _description(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: EnduvoColors.muted,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _segmentedSelector<T>({
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: options.entries.map((entry) {
          final selected = entry.key == value;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    joinModeStringToGermanUI(entry.value),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? EnduvoColors.text
                          : EnduvoColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ExpandableCard extends StatefulWidget {
  final String title;
  final Widget child;
  final bool isError;

  const ExpandableCard({
    super.key,
    required this.title,
    required this.child,
    this.isError = false,
  });

  @override
  State<ExpandableCard> createState() =>
      _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isError
              ? Colors.redAccent
              : EnduvoColors.border,
          width: widget.isError ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => open = !open),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: EnduvoColors.text,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 21,
                      color: EnduvoColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16,
              ),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

class _TopToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _TopToast({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<Offset> slide;
  late Animation<double> fade;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    slide = Tween<Offset>(
      begin: const Offset(0, -1), // comes from top
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );

    fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);

    controller.forward();

    Future.delayed(const Duration(seconds: 2), () async {
      await controller.reverse();
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: fade,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum SoftWarning {
  media,
  stats,
  distance,
  pace,
  speed,
  none,
}

class CreatePostPageV2 extends StatefulWidget {
  const CreatePostPageV2({super.key});

  @override
  State<CreatePostPageV2> createState() => _CreatePostPageV2State();
}

class _CreatePostPageV2State extends State<CreatePostPageV2> {

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final dateController = TextEditingController();
  final timeController = TextEditingController();
  final ImageService imageService = ImageService();
  final MapController mapController = MapController();
  final townController = TextEditingController();
  final meetingPointController = TextEditingController();
  JoinMode joinMode = JoinMode.request;
  final mapService = MapService();
  bool mapReady = false;
  // final mapUrl = 'https://api.maptiler.com/maps/basic-v2-light/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  final mapUrl = 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  String? postTown;
  LatLng? mapCenter;
  File? postImage = null;
  int? distance;
  int? paceSeconds;
  int? speed;

  String activity = "Laufen";
  DateTime? date;
  TimeOfDay? time;
  DateTime? startsAt;

  bool canSubmit = false;        // form valid
  bool isLoading = false;        // request state
  bool isBlockedByLimit = false; // future premium rule
  String? missingMessage;
  String? missingField;
  bool isLimitLoading = true;

  void _validate() {
    String? error;

    if (titleController.text.trim().isEmpty) {
      error = "Titel fehlt";
    } else if (date == null) {
      error = "Datum fehlt";
    } else if (time == null) {
      error = "Zeit fehlt";
    } else if (mapCenter == null) {
      error = "Standort fehlt";
    }

    setState(() {
      canSubmit = error == null;
      missingMessage = error;
    });
  }

  SoftWarning _getSoftWarning() {
    final mediaMissing = postImage == null;
    final statsMissing = activity == "Laufen" ? (paceSeconds == null && distance == null) : (speed == null && distance == null);
    final distanceMissing = distance == null;
    final paceMissing = activity == "Laufen" && paceSeconds == null;
    final speedMissing = activity == "Radfahren" && speed == null;

    if (mediaMissing && statsMissing) return SoftWarning.stats; 
    if (statsMissing) return SoftWarning.stats;
    if (distanceMissing) return SoftWarning.distance;
    if (paceMissing) return SoftWarning.pace;
    if (speedMissing) return SoftWarning.speed;
    if (mediaMissing) return SoftWarning.media;

    return SoftWarning.none;
  }

  String _softWarningText(SoftWarning warning) {
    switch (warning) {
      case SoftWarning.media:
        return "Kein Bild hinzugefügt. Trotzdem veröffentlichen?";
      case SoftWarning.stats:
        return "Keine Distanz oder Tempo angegeben. Trotzdem veröffentlichen?";
      case SoftWarning.distance:
        return "Keine Distanz angegeben. Trotzdem veröffentlichen?";
      case SoftWarning.pace:
        return "Kein Tempo angegeben. Trotzdem veröffentlichen?";
      case SoftWarning.speed:
        return "Keine Geschwindigkeit angegeben. Trotzdem veröffentlichen?";
      case SoftWarning.none:
        return "";
    }
  }

  Future<Post?> addPostToDatabase() async {
    String? url;

    if (date != null && time != null) {
      startsAt = DateTime(
        date!.year,
        date!.month,
        date!.day,
        time!.hour,
        time!.minute,
      ).toUtc();
    }

    // insert post
    try {
      final response = await supabase
        .from('posts')
        .insert({
          'title': titleController.text,
          'description': descriptionController.text,
          'activity': activity == "Laufen" ? "Run" : "Bike",
          'distance': distance,
          'pace': paceSeconds,
          'speed': speed,
          'date': date?.toIso8601String(),
          'time': time != null ? formatTimeOfDay(time!) : null,
          'image_url': null, // will update later after upload
          'join_mode': joinModeToString(joinMode), //joinRequestActive,
          'latitude': mapCenter?.latitude ?? 0.0,
          'longitude': mapCenter?.longitude ?? 0.0,
          'town': postTown ?? '',
          'creator_id': supabase.auth.currentUser!.id,
          'starts_at': startsAt?.toIso8601String(),
          'meeting_point': meetingPointController.text,
        })
        .select()
        .single();

      // upload image to supabase storage
      debugPrint("result: $response");
      final postId = response['id'].toString();
      final path = '$postId.png';
      if (postImage != null) {
        await supabase.storage.from('PostImages').upload(
          path, 
          postImage!,
          fileOptions: FileOptions(upsert: true),
        );
        // link url in corresponding post
        url = supabase.storage.from('PostImages').getPublicUrl(path);
        await supabase.from('posts').update({'image_url': url}).eq('id', postId);
      }

      // post creator is joined automatically
      await supabase.from('activity_participants').insert({
        'post_id': postId,
        'user_id': supabase.auth.currentUser!.id,
        'last_read_at': null,
        'status': "joined",
        'joined_at': DateTime.now().toIso8601String(),
      });

      // collect post for return
      final loadedPost = Post(
        id: response['id'].toString(),
        title: response['title'],
        creatorId: response['creator_id'],
        imgurl: url,
        description: response['description'],
        activity: response['activity'],
        distance: response['distance'],
        pace: response['pace'],
        speed: response['speed'],
        // date: response['date'],
        // time: response['time'],
        latitude: (response['latitude'] as num?)?.toDouble(),
        longitude: response['longitude']?.toDouble(),
        town: response['town'],
        createdAt: response['created_at'],
        joinMode: response['join_mode'],
        // userdistance: widget.userDistance,
        startsAt: response['starts_at']
      );

      return loadedPost;
    } catch (e) {
      debugPrint("Error adding post to database $e");
      return null;
    }
  }

  Future<File?> pickAndProcessImage() async {
    File? image = await imageService.pickImage();
    if (image == null) return null;

    image = await imageService.cropImageWithUI(image);
    if (image == null) return null;

    image = await imageService.compressImage(image);

    return image;
  }

  Future<void> _pickImage() async {
    final image = await pickAndProcessImage();

    if (image != null) {
      setState(() {
        postImage = image;
      });
    }
  }

  String formatTimeOfDay(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}:00";
  }

  String joinModeToString(JoinMode mode) {
    switch (mode) {
      case JoinMode.instant:
        return 'Instant';
      case JoinMode.request:
        return 'Request';
      case JoinMode.inviteOnly:
        return 'Invite';
    }
  }

  String? _getValidationError() {
    if (titleController.text.trim().isEmpty) return "title";
    if (date == null) return "date";
    if (time == null) return "time";
    if (mapCenter == null) return "location";
    return null;
  }

  OverlayEntry? _currentToast;

  void _showMissingFields(String message) {
    _currentToast?.remove(); // 👈 kill existing one

    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return _TopToast(
          message: _humanReadable(message),
          onDismiss: () {
            entry.remove();
            if (_currentToast == entry) {
              _currentToast = null;
            }
          },
        );
      },
    );

    _currentToast = entry;
    overlay.insert(entry);
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Limit erreicht"),
        content: const Text(
          "Du kannst nur 2 aktive Posts haben.\n"
          "Upgrade auf Premium für 2,99€, um unbegrenzt zu posten.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Später"),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: go to paywall
            },
            child: const Text("Upgrade"),
          ),
        ],
      ),
    );
  }

  String _humanReadable(String key) {
    switch (key) {
      case "title": return "Titel fehlt";
      case "date": return "Datum fehlt";
      case "time": return "Zeit fehlt";
      case "location": return "Standort fehlt";
      case "timeTooSoon": return "Startzeit muss mindestens 1h in der Zukunft liegen";
      default: return "Eingabe fehlt";
    }
  }

  DateTime? _getPlannedDateTime() {
    if (date == null || time == null) return null;

    return DateTime(
      date!.year,
      date!.month,
      date!.day,
      time!.hour,
      time!.minute,
    );
  }

  bool _isAtLeastOneHourInFuture() {
    final planned = _getPlannedDateTime();
    if (planned == null) return false;

    return planned.isAfter(DateTime.now().add(const Duration(hours: 1)));
  }

  Future<bool> _confirmWithout() async {
    final warning = _getSoftWarning();

    if (warning == SoftWarning.none) return true;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Text(
          _softWarningText(warning),
          style: const TextStyle(fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.only(right: 12, bottom: 8),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Abbruch"),
          ),

          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("OK"),
          ),
        ],
      ),
    );

    return proceed ?? false;
  }

  Future<int> checkNumberActivePosts() async {
    try {
      final response = await supabase
          .from('posts')
          .select(
            'creator_id',
          )
          .eq('creator_id', supabase.auth.currentUser!.id)
          .gt('date', DateTime.now().toIso8601String())
          .count();

      return response.count;
    } catch (e) {
      print("Error fetching active posts count: $e");
      return 0;
    }
  }

  Future<void> _loadLimit() async {
    final numberActivePosts = await checkNumberActivePosts();

    if (!mounted) return;

    setState(() {
      isBlockedByLimit = numberActivePosts >= 2;
      isLimitLoading = false;
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    dateController.dispose();
    timeController.dispose();
    townController.dispose();
    meetingPointController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mapReady) {
        setState(() => mapReady = true);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadLimit();
    // titleController.addListener(_validate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnduvoColors.background,

      appBar: AppBar(
        backgroundColor: EnduvoColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: EnduvoColors.text,
          ),
          onPressed: () => Navigator.pop(context),
        ),

        title: const Text(
          "Aktivität planen",
          style: TextStyle(
            color: EnduvoColors.text,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),

        centerTitle: true,
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24,
        ),
        children: [

          // BASIC
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: EnduvoColors.border,
              ),
            ),
            child: _BasicSection(
              isBlockedByLimit: isBlockedByLimit,
              titleController: titleController,
              descriptionController: descriptionController,
              dateController: dateController,
              timeController: timeController,
              activity: activity,

              onPaceChanged: (val) {
                setState(() => paceSeconds = val);
                _validate();
              },

              onSpeedChanged: (val) {
                setState(() => speed = val);
                _validate();
              },

              onActivityChanged: (val) {
                setState(() => activity = val);
              },

              onPickDate: () async {
                descriptionFocus.unfocus();
                titleFocus.unfocus();
                locationFocus.unfocus();
                meetingPointFocus.unfocus();

                final result = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: EnduvoColors.text,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: EnduvoColors.text,
                        ),
                        dialogTheme:
                            const DialogThemeData(
                          surfaceTintColor:
                              Colors.transparent,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );

                if (result != null) {
                  setState(() => date = result);
                  _validate();
                }
              },

              onPickTime: () async {
                descriptionFocus.unfocus();
                titleFocus.unfocus();
                locationFocus.unfocus();
                meetingPointFocus.unfocus();

                final result = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: EnduvoColors.text,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: EnduvoColors.text,
                        ),
                        dialogTheme:
                            const DialogThemeData(
                          surfaceTintColor:
                              Colors.transparent,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );

                if (result != null) {
                  setState(() => time = result);
                  _validate();
                }
              },

              date: date,
              time: time,
              missingField: missingField,
            ),
          ),

          const SizedBox(height: 12),

          // DETAILS
          ExpandableCard(
            title: "Details",
            child: _DetailsSection(
              activity: activity,
              distance: distance,
              paceSeconds: paceSeconds,
              speed: speed,

              onDistanceChanged: (val) {
                setState(() => distance = val);
                _validate();
              },

              onPaceChanged: (val) {
                setState(() => paceSeconds = val);
                _validate();
              },

              onSpeedChanged: (val) {
                setState(() => speed = val);
                _validate();
              },

              onPickDistance: () {},
            ),
          ),

          // LOCATION
          ExpandableCard(
            title: "Standort",
            isError: missingField == "location",
            child: _LocationSection(
              activity: activity,
              mapController: mapController,
              mapCenter: mapCenter,
              mapUrl: mapUrl,
              mapReady: mapReady,

              onMapReady: () {
                if (!mapReady) {
                  setState(() => mapReady = true);
                }
              },

              townController: townController,
              meetingPointController:
                  meetingPointController,

              onTownSubmitted: (value) async {
                if (value.isEmpty) return;

                setState(() {
                  mapReady = false;
                });

                final coords =
                    await mapService.getCoordinatesFromTown(
                  value,
                );

                final town =
                    await mapService.getTownFromCoordinates(
                  coords!.latitude,
                  coords.longitude,
                );

                setState(() {
                  mapCenter = coords;
                  postTown = town;
                });

                mapController.move(coords, 13);
              },

              onLocationChanged: (point) {
                setState(() {
                  mapCenter = point;
                });
              },

              onHelpPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                    title: const Text(
                      "Standort Hilfe",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    content: const Text(
                      "Tippe einen Ort ein oder setze den Pin direkt auf der Karte.",
                    ),
                  ),
                );
              },
            ),
          ),

          // MEDIA
          ExpandableCard(
            title: "Medien",
            child: _MediaSection(
              image: postImage,
              onPickImage: () {
                _pickImage();
              },
            ),
          ),

          // SETTINGS
          ExpandableCard(
            title: "Sichtbarkeit",
            child: _SettingsSection(
              joinMode: joinMode,
              onJoinModeChanged: (val) {
                setState(() => joinMode = val);
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Container(
          color: EnduvoColors.background,
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16,
          ),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed:
                  isBlockedByLimit || isLoading
                      ? null
                      : () async {

                          // =====================================================
                          // EVERYTHING BELOW HERE IS YOUR EXISTING LOGIC
                          // =====================================================

                          if (isBlockedByLimit) {
                            return;
                          }

                          final validationError =
                              _getValidationError();

                          if (validationError != null) {
                            setState(() {
                              missingField =
                                  validationError;
                            });

                            _showMissingFields(
                              validationError,
                            );

                            return;
                          }

                          if (!_isAtLeastOneHourInFuture()) {
                            setState(() {
                              missingField = "time";
                            });

                            _showMissingFields(
                              "timeTooSoon",
                            );

                            return;
                          }

                          if (postImage == null) {
                            final proceed =
                                await _confirmWithout();

                            if (!proceed) return;
                          }

                          setState(() {
                            missingField = null;
                          });

                          setState(() {
                            isLoading = true;
                          });

                          Post? returnPost =
                              await addPostToDatabase();

                          setState(() {
                            isLoading = false;
                          });

                          if (!mounted) return;

                          if (returnPost != null) {
                            Navigator.pop(
                              context,
                              returnPost,
                            );
                          } else {
                            showDialog(
                              context: context,
                              builder: (ctx) =>
                                  AlertDialog(
                                backgroundColor:
                                    Colors.white,
                                surfaceTintColor:
                                    Colors.transparent,
                                elevation: 0,
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    18,
                                  ),
                                ),
                                title: const Text(
                                  "Fehler",
                                  style: TextStyle(
                                    color:
                                        EnduvoColors.text,
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                content: const Text(
                                  "Post konnte nicht erstellt werden",
                                  style: TextStyle(
                                    color:
                                        EnduvoColors.text,
                                    fontSize: 15,
                                  ),
                                ),
                                actionsPadding:
                                    const EdgeInsets
                                        .fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                actions: [
                                  TextButton(
                                    style:
                                        TextButton.styleFrom(
                                      foregroundColor:
                                          EnduvoColors.text,
                                    ),
                                    onPressed: () =>
                                        Navigator.of(ctx)
                                            .pop(),
                                    child: const Text(
                                      "OK",
                                      style: TextStyle(
                                        fontWeight:
                                            FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },

              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isBlockedByLimit
                        ? const Color(0xFFB5B5B5)
                        : EnduvoColors.text,
                disabledBackgroundColor:
                    EnduvoColors.text.withOpacity(0.35),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              child: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Aktivität planen",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}