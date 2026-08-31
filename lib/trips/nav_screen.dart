import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config.dart';
import '../data/db.dart';
import '../data/delivery.dart';
import '../data/directions.dart';
import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';

/// Turn-by-turn navigation, in the app. A tilted camera follows the driver's
/// GPS along the road route to the current target (pickup until picked up, then
/// drop-off), with a maneuver banner up top and an ETA bar at the bottom — the
/// Google-Maps feel, without leaving the app. The live position is also written
/// back to the delivery so the web dashboard tracks the truck.
class NavScreen extends StatefulWidget {
  final Delivery initial;
  const NavScreen({super.key, required this.initial});

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  late final Stream<List<Map<String, dynamic>>> _tripStream;
  GoogleMapController? _map;

  StreamSubscription<Position>? _posSub;
  Position? _me;
  LatLng? _prev; // for a bearing fallback when GPS heading is unknown
  double _bearing = 0;
  String? _locError;

  RouteResult? _route;
  bool _straight = false; // Routes API unavailable → direct line
  bool _routing = false;
  ({double lat, double lng})? _routedTo;
  int _stepIndex = 0;

  bool _follow = true;
  DateTime? _lastReroute;

  // Throttle writing the live position back to the delivery.
  DateTime? _lastWrite;
  LatLng? _lastWritten;

  @override
  void initState() {
    super.initState();
    _tripStream = supabase
        .from('deliveries')
        .stream(primaryKey: ['id']).eq('id', widget.initial.id);
    _startLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _startLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _locError = 'Turn on location to navigate.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _locError = 'Location permission is needed to navigate.');
        return;
      }
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen(_onPosition);
    } catch (_) {
      setState(() => _locError = 'Could not start location.');
    }
  }

  void _onPosition(Position p) {
    final here = LatLng(p.latitude, p.longitude);
    // Bearing: trust the GPS heading while moving, else derive from movement.
    double bearing = _bearing;
    if (p.heading.isFinite && p.heading >= 0 && p.speed > 0.6) {
      bearing = p.heading;
    } else if (_prev != null) {
      final b = Geolocator.bearingBetween(
          _prev!.latitude, _prev!.longitude, here.latitude, here.longitude);
      if (b.isFinite) bearing = (b + 360) % 360;
    }
    setState(() {
      _me = p;
      _bearing = bearing;
    });
    _prev = here;

    if (_follow) {
      _map?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: here,
        zoom: 17,
        tilt: 55,
        bearing: bearing,
      )));
    }
    _advanceStep(here);
    _maybeReroute(here);
    _maybeWriteBack(here);
  }

  void _advanceStep(LatLng here) {
    final steps = _route?.steps;
    if (steps == null || steps.isEmpty) return;
    while (_stepIndex < steps.length - 1 &&
        Geolocator.distanceBetween(here.latitude, here.longitude,
                steps[_stepIndex].end.latitude, steps[_stepIndex].end.longitude) <
            25) {
      setState(() => _stepIndex++);
    }
  }

  Future<void> _maybeRoute(Delivery trip) async {
    final target = trip.navTarget;
    if (target == null || _me == null || _routing) return;
    final at = _routedTo;
    if (at != null && at.lat == target.lat && at.lng == target.lng && _route != null) {
      return;
    }
    _routing = true;
    _routedTo = target;
    final origin = LatLng(_me!.latitude, _me!.longitude);
    final dest = LatLng(target.lat, target.lng);
    final r = await fetchDrivingRoute(origin, dest);
    if (!mounted) {
      _routing = false;
      return;
    }
    setState(() {
      _stepIndex = 0;
      if (r != null && r.points.length > 1) {
        _route = r;
        _straight = false;
      } else {
        _route = RouteResult(
            points: [origin, dest],
            distanceMeters: 0,
            durationSeconds: 0,
            steps: const []);
        _straight = true;
      }
    });
    _routing = false;
  }

  /// If the driver strays far from the drawn route, fetch a fresh one.
  Future<void> _maybeReroute(LatLng here) async {
    final route = _route;
    if (route == null || _straight || _routing || route.points.length < 2) return;
    var min = double.infinity;
    for (final p in route.points) {
      final d = Geolocator.distanceBetween(
          here.latitude, here.longitude, p.latitude, p.longitude);
      if (d < min) min = d;
    }
    final now = DateTime.now();
    if (min > 70 &&
        (_lastReroute == null || now.difference(_lastReroute!).inSeconds > 8)) {
      _lastReroute = now;
      _routedTo = null; // force a refetch to the same target from here
      _maybeRoute(_latestTrip);
    }
  }

  Future<void> _maybeWriteBack(LatLng here) async {
    final now = DateTime.now();
    final farEnough = _lastWritten == null ||
        Geolocator.distanceBetween(_lastWritten!.latitude, _lastWritten!.longitude,
                here.latitude, here.longitude) >
            60;
    final oldEnough =
        _lastWrite == null || now.difference(_lastWrite!).inSeconds > 15;
    if (!(farEnough && oldEnough)) return;
    _lastWrite = now;
    _lastWritten = here;
    try {
      await supabase.from('deliveries').update({
        'last_lat': here.latitude,
        'last_lng': here.longitude,
      }).eq('id', widget.initial.id);
    } catch (_) {
      // Best-effort tracking.
    }
  }

  void _recenter() {
    setState(() => _follow = true);
    if (_me != null) {
      _map?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(_me!.latitude, _me!.longitude),
        zoom: 17,
        tilt: 55,
        bearing: _bearing,
      )));
    }
  }

  Delivery _latestTrip = _placeholder;
  static final Delivery _placeholder =
      const Delivery(id: '', status: 'pending');

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Scaffold(
      backgroundColor: c.s2,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _tripStream,
        builder: (context, snap) {
          final trip = (snap.data?.isNotEmpty ?? false)
              ? Delivery.fromMap(snap.data!.first)
              : widget.initial;
          _latestTrip = trip;
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRoute(trip));
          return Stack(
            children: [
              Positioned.fill(child: _mapOrMessage(trip)),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: _ManeuverBanner(
                  trip: trip,
                  route: _route,
                  straight: _straight,
                  stepIndex: _stepIndex,
                  me: _me,
                  locError: _locError,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 120 + MediaQuery.of(context).padding.bottom,
                child: _RoundBtn(
                  icon: _follow
                      ? Icons.navigation_rounded
                      : Icons.navigation_outlined,
                  onTap: _recenter,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _EtaBar(trip: trip, route: _route, straight: _straight),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _mapOrMessage(Delivery trip) {
    final c = context.ct;
    if (!Config.mapsEnabled) {
      return ColoredBox(
        color: c.s2,
        child: const CtMessage(
          icon: Icons.map_outlined,
          title: 'Map not configured',
          body: 'Add a Google Maps key to navigate.',
        ),
      );
    }
    final target = trip.navTarget;
    if (target == null) {
      return ColoredBox(
        color: c.s2,
        child: const CtMessage(
          icon: Icons.wrong_location_outlined,
          title: 'No destination yet',
          body: 'This delivery has no coordinates to navigate to.',
        ),
      );
    }

    final markers = <Marker>{
      if (trip.hasOrigin)
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(trip.originLat!, trip.originLng!),
          infoWindow: const InfoWindow(title: 'Pick up'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      if (trip.hasDest)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(trip.destLat!, trip.destLng!),
          infoWindow: const InfoWindow(title: 'Drop off'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
    };

    final polylines = <Polyline>{
      if (_route != null && _route!.points.length > 1)
        Polyline(
          polylineId: const PolylineId('route'),
          points: _route!.points,
          color: c.primary,
          width: 7,
          patterns: _straight
              ? [PatternItem.dash(24), PatternItem.gap(12)]
              : const [],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
    };

    return GoogleMap(
      initialCameraPosition: _me != null
          ? CameraPosition(
              target: LatLng(_me!.latitude, _me!.longitude),
              zoom: 17,
              tilt: 55,
              bearing: _bearing)
          : CameraPosition(target: LatLng(target.lat, target.lng), zoom: 15),
      markers: markers,
      polylines: polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      onCameraMoveStarted: () {
        // A manual pan drops follow; recenter re-enables it.
        if (_follow) setState(() => _follow = false);
      },
      onMapCreated: (m) {
        _map = m;
        if (_me == null) {
          final pts = <LatLng>[
            if (trip.hasOrigin) LatLng(trip.originLat!, trip.originLng!),
            if (trip.hasDest) LatLng(trip.destLat!, trip.destLng!),
          ];
          if (pts.length > 1) {
            var minLat = pts.first.latitude, maxLat = minLat;
            var minLng = pts.first.longitude, maxLng = minLng;
            for (final p in pts) {
              if (p.latitude < minLat) minLat = p.latitude;
              if (p.latitude > maxLat) maxLat = p.latitude;
              if (p.longitude < minLng) minLng = p.longitude;
              if (p.longitude > maxLng) maxLng = p.longitude;
            }
            m.animateCamera(CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng),
              ),
              72,
            ));
          }
        }
      },
    );
  }
}

/// Maps a Routes API maneuver to an arrow icon.
IconData _maneuverIcon(String m) {
  final k = m.toUpperCase();
  if (k.contains('UTURN')) return Icons.u_turn_left_rounded;
  if (k.contains('LEFT') && k.contains('SLIGHT')) return Icons.turn_slight_left_rounded;
  if (k.contains('RIGHT') && k.contains('SLIGHT')) return Icons.turn_slight_right_rounded;
  if (k.contains('LEFT')) return Icons.turn_left_rounded;
  if (k.contains('RIGHT')) return Icons.turn_right_rounded;
  if (k.contains('ROUNDABOUT') || k.contains('CIRCLE')) return Icons.roundabout_left_rounded;
  if (k.contains('MERGE') || k.contains('FORK')) return Icons.merge_rounded;
  if (k.contains('DEPART') || k.contains('STRAIGHT') || k.isEmpty) {
    return Icons.straight_rounded;
  }
  if (k.contains('DESTINATION') || k.contains('ARRIVE')) return Icons.flag_rounded;
  return Icons.navigation_rounded;
}

/// Top banner: the current maneuver arrow, instruction, and distance to the
/// next turn. Falls back to the target address when there are no steps (direct
/// line) or before the first fix. Also carries the back button.
class _ManeuverBanner extends StatelessWidget {
  final Delivery trip;
  final RouteResult? route;
  final bool straight;
  final int stepIndex;
  final Position? me;
  final String? locError;
  final VoidCallback onBack;
  const _ManeuverBanner({
    required this.trip,
    required this.route,
    required this.straight,
    required this.stepIndex,
    required this.me,
    required this.locError,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final steps = route?.steps ?? const [];
    final hasStep = !straight && steps.isNotEmpty && stepIndex < steps.length;

    String title;
    String? sub;
    IconData icon;
    if (locError != null) {
      icon = Icons.location_disabled_rounded;
      title = locError!;
    } else if (hasStep) {
      final step = steps[stepIndex];
      icon = _maneuverIcon(step.maneuver);
      title = step.instruction.isEmpty ? 'Continue' : step.instruction;
      if (me != null) {
        final d = Geolocator.distanceBetween(me!.latitude, me!.longitude,
                step.end.latitude, step.end.longitude)
            .round();
        sub = d < 950 ? 'In $d m' : 'In ${(d / 1000).toStringAsFixed(1)} km';
      }
    } else {
      final toPickup = !trip.isPickedUp;
      icon = Icons.navigation_rounded;
      title = (toPickup ? trip.originLabel : trip.destLabel) ?? 'Destination';
      sub = toPickup ? 'To pick-up' : 'To drop-off';
    }

    return Material(
      color: c.primary,
      borderRadius: BorderRadius.circular(CtRadius.lg),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: CtSpace.sm + 2, vertical: CtSpace.sm + 2),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back_rounded, color: c.onAccent),
              visualDensity: VisualDensity.compact,
            ),
            Icon(icon, color: c.onAccent, size: 34),
            const SizedBox(width: CtSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sub != null)
                    Text(
                      sub,
                      style: TextStyle(
                        color: c.onAccent.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.onAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom bar: ETA and remaining distance for the current leg.
class _EtaBar extends StatelessWidget {
  final Delivery trip;
  final RouteResult? route;
  final bool straight;
  const _EtaBar({required this.trip, required this.route, required this.straight});

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final hasEta = route != null && !straight && route!.durationSeconds > 0;
    return Container(
      decoration: BoxDecoration(
        color: c.s1,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(CtRadius.xl)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F1E46).withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(CtSpace.lg, CtSpace.md, CtSpace.lg,
          CtSpace.md + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Icon(trip.isPickedUp ? Icons.place_rounded : Icons.inventory_2_rounded,
              color: trip.isPickedUp ? c.accent : c.primary, size: 22),
          const SizedBox(width: CtSpace.sm),
          Expanded(
            child: Text(
              trip.isPickedUp ? 'To drop-off' : 'To pick-up',
              style: TextStyle(
                  color: c.muted2, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (hasEta)
            Text(
              '${route!.durationText}  ·  ${route!.distanceText}',
              style: TextStyle(
                color: c.green,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            Text(
              straight ? 'Direct line' : '…',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Material(
      color: c.s1,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: c.primary, size: 24),
        ),
      ),
    );
  }
}
