import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class GoogleMapsService {
  // Mobile-key setup: one key per platform, restricted by bundle id / SHA-1 in
  // Google Cloud. The Maps SDK handles the bundle check automatically for map
  // widgets, but raw HTTPS calls (Geocoding, Directions) must send the bundle
  // header themselves — that's what [_platformHeaders] below is for.
  static const String _iosKey = 'AIzaSyCBu5pafJrGpsxVm0HlZQzzc2vwl_jJEsU';
  static const String _androidKey = ''; // filled in later

  static String get _apiKey {
    if (Platform.isIOS) return _iosKey;
    if (Platform.isAndroid) return _androidKey;
    return _iosKey;
  }

  static Map<String, String> get _platformHeaders {
    if (Platform.isIOS) {
      return {'X-Ios-Bundle-Identifier': 'com.bestmart.giddarbaha'};
    }
    if (Platform.isAndroid) {
      return {'X-Android-Package': 'com.bestmart.bestmart'};
    }
    return {};
  }

  /// Reverse-geocode a coordinate into a single human-readable line.
  static Future<String?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'latlng': '$lat,$lng',
      'key': _apiKey,
    });
    final res = await http.get(uri, headers: _platformHeaders);
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['status'] != 'OK') return null;
    final results = body['results'] as List<dynamic>;
    if (results.isEmpty) return null;
    return (results.first as Map<String, dynamic>)['formatted_address'] as String?;
  }

  /// Fetch a driving route polyline + duration/distance between two points.
  /// Returns null on failure — callers should fall back to a straight line.
  /// Logs the failure reason via `dart:developer` so Xcode console surfaces
  /// Google's `status` / `error_message` instead of failing silently.
  static Future<DirectionsResult?> fetchDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'driving',
      'key': _apiKey,
    });
    final res = await http.get(uri, headers: _platformHeaders);
    if (res.statusCode != 200) {
      developer.log('[Directions] HTTP ${res.statusCode}: ${res.body}',
          name: 'gmaps');
      return null;
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['status'] != 'OK') {
      developer.log(
        '[Directions] status=${body['status']} error=${body['error_message']}',
        name: 'gmaps',
      );
      return null;
    }
    final routes = body['routes'] as List<dynamic>;
    if (routes.isEmpty) {
      developer.log('[Directions] empty routes', name: 'gmaps');
      return null;
    }
    final route = routes.first as Map<String, dynamic>;
    final overview = route['overview_polyline'] as Map<String, dynamic>;
    final encoded = overview['points'] as String;
    final leg = (route['legs'] as List).first as Map<String, dynamic>;
    final durationSec = (leg['duration'] as Map<String, dynamic>)['value'] as int;
    final distanceMeters = (leg['distance'] as Map<String, dynamic>)['value'] as int;
    return DirectionsResult(
      points: decodePolyline(encoded),
      durationSeconds: durationSec,
      distanceMeters: distanceMeters,
    );
  }

  // Google's polyline-encoding algorithm, ported. Returns a densified list of
  // LatLngs suitable for a google_maps_flutter Polyline.
  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;
    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lat += dlat;
      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}

class DirectionsResult {
  final List<LatLng> points;
  final int durationSeconds;
  final int distanceMeters;

  const DirectionsResult({
    required this.points,
    required this.durationSeconds,
    required this.distanceMeters,
  });
}
