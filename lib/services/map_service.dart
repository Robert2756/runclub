import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';

class MapService {
  Future<LatLng?> getCoordinatesFromTown(String town) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$town&format=json&limit=1');

    final response = await http.get(url, headers: {
      'User-Agent': 'YourAppNameHere', // required by Nominatim
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        return LatLng(lat, lon);
      }
    }
    return null;
  }

  Future<String?> getTownFromCoordinates(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        // This gives the city/town
        return placemarks.first.locality; // or subAdministrativeArea
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
    }
    return null;
  }
}