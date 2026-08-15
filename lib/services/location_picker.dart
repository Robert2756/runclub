// location_picker.dart
//
// Drop-in manual location picker to sit alongside GPS.
// - LocationChip: the small location pill shown at the top of the feed.
// - LocationPickerSheet: the bottom sheet with search + "use current location".
// - LocationPrefs: tiny persistence helper (SharedPreferences).
//
// GEOCODING: uses nominatim.openstreetmap.org (OpenStreetMap, free, no key).
// Their usage policy caps this at 1 request/second TOTAL across all your
// users combined, and explicitly says not to build a production app on
// their shared servers (no SLA, can throttle/ban at any time). Fine for
// dev/testing; before shipping, either self-host Nominatim or switch to a
// paid provider (LocationIQ, Geoapify, Mapbox Geocoding). Only the
// `searchLocations` / `reverseGeocode` function bodies below need to change.
//
// Dependencies you already likely have: http, shared_preferences, geolocator.
// Add if missing:
//   flutter pub add http shared_preferences

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

// Reuse the same palette as the rest of the app.
class EnduvoColors {
  static const navy = Color(0xFF0A2647);
  static const deepBlue = Color(0xFF12406B);
  static const teal = Color(0xFF2E9DC0);
  static const gold = Color(0xFFF6C567);
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);
  static const muted = Color(0xFF6B7280);
  static const text = Color(0xFF111827);
}

enum LocationSource { gps, manual }

class LocationResult {
  final String displayName; // e.g. "Erfurt, Thuringia, Germany"
  final String shortName;   // e.g. "Erfurt"
  final double lat;
  final double lon;

  const LocationResult({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lon,
  });
}

/// ---------------------------------------------------------------------
/// PERSISTENCE
/// ---------------------------------------------------------------------
class LocationPrefs {
  static const _kLat = 'user_location_lat';
  static const _kLon = 'user_location_lon';
  static const _kName = 'user_location_name';
  static const _kSource = 'user_location_source';

  static Future<void> save({
    required double lat,
    required double lon,
    required String name,
    required LocationSource source,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, lat);
    await prefs.setDouble(_kLon, lon);
    await prefs.setString(_kName, name);
    await prefs.setString(_kSource, source.name);
  }

  static Future<({double lat, double lon, String name, LocationSource source})?>
      load() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLat);
    final lon = prefs.getDouble(_kLon);
    final name = prefs.getString(_kName);
    final sourceStr = prefs.getString(_kSource);
    if (lat == null || lon == null || name == null) return null;
    final source = sourceStr == 'manual' ? LocationSource.manual : LocationSource.gps;
    return (lat: lat, lon: lon, name: name, source: source);
  }
}

/// ---------------------------------------------------------------------
/// GEOCODING (OpenStreetMap Nominatim — free, no API key)
/// Swap these two function bodies for Google Places / Mapbox / LocationIQ
/// later if you want richer autocomplete or production-grade rate limits;
/// the rest of the UI doesn't need to change.
/// ---------------------------------------------------------------------
Future<List<LocationResult>> searchLocations(String query) async {
  if (query.trim().length < 2) return [];

  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': query,
    'format': 'jsonv2',
    'addressdetails': '1',
    'limit': '6',
  });

  final response = await http.get(
    uri,
    headers: {
      // Nominatim's usage policy requires a descriptive UA per app.
      'User-Agent': 'YourAppName/1.0 (contact@yourapp.com)',
    },
  ).timeout(const Duration(seconds: 6));

  if (response.statusCode != 200) return [];

  final List<dynamic> data = json.decode(response.body);
  return data.map((item) {
    final address = item['address'] ?? {};
    final short = address['city'] ??
        address['town'] ??
        address['village'] ??
        address['municipality'] ??
        (item['display_name'] as String).split(',').first;

    return LocationResult(
      displayName: item['display_name'],
      shortName: short,
      lat: double.parse(item['lat']),
      lon: double.parse(item['lon']),
    );
  }).toList();
}

/// Reverse-geocodes a lat/lon into a short place name (e.g. "Erfurt").
/// Used so the GPS flow can show a real town name instead of a generic
/// "Current location" / "Nearby" label. Returns null on any failure —
/// callers should fall back to a generic label rather than surfacing
/// an error for what's a nice-to-have label.
Future<String?> reverseGeocode(double lat, double lon) async {
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '$lat',
      'lon': '$lon',
      'format': 'jsonv2',
      'zoom': '10', // city-level detail, not full street address
    });

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'YourAppName/1.0 (contact@yourapp.com)',
      },
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) return null;

    final data = json.decode(response.body);
    final address = data['address'] ?? {};
    return address['city'] ??
        address['town'] ??
        address['village'] ??
        address['municipality'] ??
        address['county'];
  } catch (_) {
    return null;
  }
}

/// ---------------------------------------------------------------------
/// CHIP — put this in your feed header / app bar
/// ---------------------------------------------------------------------
class LocationChip extends StatelessWidget {
  final String label;
  final LocationSource source;
  final VoidCallback onTap;

  const LocationChip({
    super.key,
    required this.label,
    required this.source,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: EnduvoColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: EnduvoColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              source == LocationSource.manual
                  ? Icons.edit_location_alt_rounded
                  : Icons.my_location_rounded,
              size: 15,
              color: EnduvoColors.deepBlue,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: EnduvoColors.text,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: EnduvoColors.muted),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// BOTTOM SHEET — search + "use current location"
/// ---------------------------------------------------------------------
/// Usage:
///   final result = await showModalBottomSheet<LocationPickerResult>(
///     context: context,
///     isScrollControlled: true,
///     backgroundColor: Colors.transparent,
///     builder: (_) => const LocationPickerSheet(),
///   );
///   if (result != null) { ... apply result.lat/lon/name/source ... }

class LocationPickerResult {
  final double lat;
  final double lon;
  final String name;
  final LocationSource source;

  LocationPickerResult({
    required this.lat,
    required this.lon,
    required this.name,
    required this.source,
  });
}

class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<LocationResult> _results = [];
  bool _searching = false;
  bool _gpsLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Autofocus feels natural for a search sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (query.trim().isEmpty) {
        setState(() => _results = []);
        return;
      }
      setState(() {
        _searching = true;
        _error = null;
      });
      try {
        final results = await searchLocations(query);
        if (!mounted) return;
        setState(() {
          _results = results;
          _searching = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = "Suche gerade nicht möglich — bitte Verbindung prüfen.";
          _searching = false;
        });
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _gpsLoading = true;
      _error = null;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _gpsLoading = false;
          _error = 'Standortzugriff wurde verweigert.';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Try to resolve a real town name for the label. If it fails or
      // takes too long, fall back to a generic label rather than block
      // the whole flow on a "nice to have".
      String label = 'In der Nähe';
      try {
        final town = await reverseGeocode(position.latitude, position.longitude)
            .timeout(const Duration(seconds: 3));
        if (town != null && town.isNotEmpty) label = town;
      } catch (_) {
        // Keep the generic fallback label.
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        LocationPickerResult(
          lat: position.latitude,
          lon: position.longitude,
          name: label,
          source: LocationSource.gps,
        ),
      );
    } catch (e) {
      setState(() {
        _gpsLoading = false;
        _error = "Standort konnte nicht ermittelt werden.";
      });
    }
  }

  void _selectResult(LocationResult r) {
    Navigator.of(context).pop(
      LocationPickerResult(
        lat: r.lat,
        lon: r.lon,
        name: r.shortName,
        source: LocationSource.manual,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read once per build — DraggableScrollableSheet itself stays fixed
    // relative to the *unobstructed* screen height. We only pad the
    // scrollable content at the bottom for the keyboard, instead of
    // resizing/animating the whole sheet. That's what was causing the
    // jump: animating the outer container's padding AND the sheet's own
    // fractional sizing at the same time, on two different clocks, so
    // they fought each other whenever the keyboard's animation curve
    // (iOS/Android use different durations) didn't match the fixed
    // 150ms AnimatedPadding.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: EnduvoColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: EnduvoColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Text(
                      'Standort festlegen',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: EnduvoColors.text,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: EnduvoColors.muted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: EnduvoColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EnduvoColors.border),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onQueryChanged,
                    style: const TextStyle(color: EnduvoColors.text),
                    decoration: InputDecoration(
                      hintText: 'Stadt, Ort oder Adresse suchen',
                      hintStyle: const TextStyle(color: EnduvoColors.muted),
                      prefixIcon: const Icon(Icons.search_rounded, color: EnduvoColors.muted, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  // Bottom inset lives here, on the scroll content, not on
                  // an outer wrapper — this is the actual fix for the jump.
                  padding: EdgeInsets.only(bottom: 24 + bottomInset),
                  children: [
                    ListTile(
                      leading: _gpsLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: EnduvoColors.deepBlue,
                              ),
                            )
                          : const Icon(Icons.my_location_rounded, color: EnduvoColors.deepBlue),
                      title: const Text(
                        'Aktuellen Standort verwenden',
                        style: TextStyle(fontWeight: FontWeight.w600, color: EnduvoColors.text),
                      ),
                      onTap: _gpsLoading ? null : _useCurrentLocation,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(height: 1, color: EnduvoColors.border),
                    ),
                    if (_searching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: EnduvoColors.deepBlue,
                            ),
                          ),
                        ),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    else
                      ..._results.map((r) => ListTile(
                            leading: const Icon(Icons.place_outlined, color: EnduvoColors.muted),
                            title: Text(
                              r.shortName,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: EnduvoColors.text),
                            ),
                            subtitle: Text(
                              r.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: EnduvoColors.muted),
                            ),
                            onTap: () => _selectResult(r),
                          )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
