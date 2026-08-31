import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// One turn in a route: the instruction to show, a maneuver kind (for the
/// arrow), how far this step runs, and where it ends (used to advance to the
/// next step as the driver reaches it).
class RouteStep {
  final String instruction;
  final String maneuver;
  final int distanceMeters;
  final LatLng end;
  const RouteStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.end,
  });
}

/// A driving route: the road polyline, ETA/distance, and turn-by-turn steps.
class RouteResult {
  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;
  final List<RouteStep> steps;
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });

  String get distanceText => _distance(distanceMeters);
  String get durationText => _duration(durationSeconds);
}

/// Fetches a driving route [origin] → [dest] from the Google **Routes API**
/// (the legacy Directions API is blocked for new projects). Returns null on any
/// failure — no key, network error, blocked key, or empty result — so callers
/// fall back to a straight line and stay in-app.
///
/// The Maps key is restricted to the iOS app, so REST calls must present the
/// bundle id via `X-Ios-Bundle-Identifier` to pass that restriction.
Future<RouteResult?> fetchDrivingRoute(LatLng origin, LatLng dest) async {
  if (!Config.mapsEnabled) return null;
  final uri =
      Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
  try {
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': Config.googleMapsKey,
        'X-Ios-Bundle-Identifier': Config.iosBundleId,
        'X-Goog-FieldMask': [
          'routes.duration',
          'routes.distanceMeters',
          'routes.polyline.encodedPolyline',
          'routes.legs.steps.navigationInstruction',
          'routes.legs.steps.distanceMeters',
          'routes.legs.steps.endLocation',
        ].join(','),
      },
      body: jsonEncode({
        'origin': {
          'location': {
            'latLng': {'latitude': origin.latitude, 'longitude': origin.longitude}
          }
        },
        'destination': {
          'location': {
            'latLng': {'latitude': dest.latitude, 'longitude': dest.longitude}
          }
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
        'polylineEncoding': 'ENCODED_POLYLINE',
        'languageCode': 'en-US',
        'units': 'METRIC',
      }),
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return null;
    final route = routes.first as Map<String, dynamic>;

    final encoded =
        (route['polyline'] as Map<String, dynamic>?)?['encodedPolyline'] as String?;
    if (encoded == null) return null;

    final steps = <RouteStep>[];
    final legs = route['legs'] as List?;
    if (legs != null && legs.isNotEmpty) {
      for (final s in ((legs.first as Map<String, dynamic>)['steps'] as List? ??
          const [])) {
        final step = s as Map<String, dynamic>;
        final nav = step['navigationInstruction'] as Map<String, dynamic>?;
        final end = step['endLocation'] as Map<String, dynamic>?;
        final ll = end?['latLng'] as Map<String, dynamic>?;
        if (ll == null) continue;
        steps.add(RouteStep(
          instruction: (nav?['instructions'] as String?) ?? '',
          maneuver: (nav?['maneuver'] as String?) ?? '',
          distanceMeters: (step['distanceMeters'] as num?)?.toInt() ?? 0,
          end: LatLng(
              (ll['latitude'] as num).toDouble(), (ll['longitude'] as num).toDouble()),
        ));
      }
    }

    return RouteResult(
      points: decodePolyline(encoded),
      distanceMeters: (route['distanceMeters'] as num?)?.toInt() ?? 0,
      durationSeconds: _parseDuration(route['duration'] as String?),
      steps: steps,
    );
  } catch (_) {
    return null;
  }
}

/// Routes API durations come as e.g. "1234s".
int _parseDuration(String? d) {
  if (d == null) return 0;
  return int.tryParse(d.replaceAll('s', '')) ?? 0;
}

String _duration(int seconds) {
  if (seconds <= 0) return '';
  final m = (seconds / 60).round();
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final rem = m % 60;
  return rem == 0 ? '$h hr' : '$h hr $rem min';
}

String _distance(int meters) {
  if (meters <= 0) return '';
  if (meters < 950) return '$meters m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
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
