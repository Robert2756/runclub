// location_picker.dart
//
// Drop-in manual location picker to sit alongside GPS.
// - LocationChip: the small "📍 City ▾" pill shown at the top of the feed.
// - LocationPickerSheet: the bottom sheet with search + "use current location".
// - LocationPrefs: tiny persistence helper (SharedPreferences).
//
// Dependencies you already likely have: http, shared_preferences, latlong2, geolocator.
// Add if missing:
//   flutter pub add http shared_preferences

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

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
/// Swap this function's body for Google Places / Mapbox later if you
/// want richer autocomplete; the rest of the UI doesn't need to change.
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
      // Nominatim's usage policy asks for a descriptive UA per app.
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
          color: const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              source == LocationSource.manual
                  ? Icons.edit_location_alt_rounded
                  : Icons.my_location_rounded,
              size: 15,
              color: Colors.black87,
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
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.black54),
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
          _error = "Couldn't search right now — check your connection.";
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
          _error = 'Location permission denied.';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        LocationPickerResult(
          lat: position.latitude,
          lon: position.longitude,
          name: 'Current location',
          source: LocationSource.gps,
        ),
      );
    } catch (e) {
      setState(() {
        _gpsLoading = false;
        _error = "Couldn't get your location.";
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Set location',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onQueryChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search city, town, or address',
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.black45),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      ListTile(
                        leading: _gpsLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded, color: Colors.black87),
                        title: const Text(
                          'Use current location',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: _gpsLoading ? null : _useCurrentLocation,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(height: 1, color: Color(0x0A000000)),
                      ),
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                              leading: const Icon(Icons.place_outlined, color: Colors.black54),
                              title: Text(
                                r.shortName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                r.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
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
      ),
    );
  }
}
