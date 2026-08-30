import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// A driving route from the Google Directions API: the road polyline plus
/// human-readable distance/duration for the ETA banner.
class RouteResult {
  final List<LatLng> points;
  final String? distanceText;
  final String? durationText;
  const RouteResult({
    required this.points,
    this.distanceText,
    this.durationText,
  });
}

/// Fetches a driving route [origin] → [dest]. Returns null when there's no key,
/// the network fails, or the Directions API isn't enabled on the key
/// (status != 'OK') — callers fall back to a straight line, staying in-app.
Future<RouteResult?> fetchDrivingRoute(LatLng origin, LatLng dest) async {
  if (!Config.mapsEnabled) return null;
  final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
    'origin': '${origin.latitude},${origin.longitude}',
    'destination': '${dest.latitude},${dest.longitude}',
    'mode': 'driving',
    'key': Config.googleMapsKey,
  });
  try {
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;
    final routes = data['routes'] as List;
    if (routes.isEmpty) return null;
    final route = routes.first as Map<String, dynamic>;
    final overview =
        (route['overview_polyline'] as Map<String, dynamic>)['points'] as String;
    final leg = (route['legs'] as List).first as Map<String, dynamic>;
    return RouteResult(
      points: decodePolyline(overview),
      distanceText: (leg['distance'] as Map<String, dynamic>?)?['text'] as String?,
      durationText: (leg['duration'] as Map<String, dynamic>?)?['text'] as String?,
    );
  } catch (_) {
    return null;
  }
}

/// Decodes a Google encoded polyline string into coordinates.
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  int index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    int shift = 0, result = 0, b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
