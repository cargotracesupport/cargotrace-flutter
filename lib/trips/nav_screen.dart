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

/// In-app navigation for an in-progress trip. Shows the driver's live position
/// following the road route to the current target (pickup until picked up, then
/// drop-off), with an ETA banner — all inside the app, no hand-off to another
/// maps app. The live position is also written back to the delivery so the web
/// dashboard tracks the truck.
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
  String? _locError;

  RouteResult? _route;
  bool _routeStraight = false; // true when Directions failed → direct line
  ({double lat, double lng})? _routedTo; // target the current route was built for

  bool _follow = true;

  // Throttle writes of the live position back to the delivery.
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
          accuracy: LocationAccuracy.high,
          distanceFilter: 8,
        ),
      ).listen(_onPosition);
    } catch (_) {
      setState(() => _locError = 'Could not start location.');
    }
  }

  void _onPosition(Position p) {
    setState(() => _me = p);
    final here = LatLng(p.latitude, p.longitude);
    if (_follow) {
      _map?.animateCamera(CameraUpdate.newLatLng(here));
    }
    // Routing is driven from build()'s post-frame callback, which always has
    // the latest target from the trip stream.
    _maybeWriteBack(here);
  }

  /// (Re)fetch the road route when we first have a position or when the target
  /// changes (pickup → drop-off). Falls back to a straight line in-app.
  Future<void> _maybeRoute(Delivery trip) async {
    final target = trip.navTarget;
    if (target == null || _me == null) return;
    final already = _routedTo;
    if (already != null &&
        already.lat == target.lat &&
        already.lng == target.lng &&
        _route != null) {
      return;
    }
    _routedTo = target;
    final origin = LatLng(_me!.latitude, _me!.longitude);
    final dest = LatLng(target.lat, target.lng);
    final r = await fetchDrivingRoute(origin, dest);
    if (!mounted) return;
    setState(() {
      if (r != null) {
        _route = r;
        _routeStraight = false;
      } else {
        _route = RouteResult(points: [origin, dest]);
        _routeStraight = true;
      }
    });
  }

  Future<void> _maybeWriteBack(LatLng here) async {
    final now = DateTime.now();
    final farEnough = _lastWritten == null ||
        Geolocator.distanceBetween(_lastWritten!.latitude,
                _lastWritten!.longitude, here.latitude, here.longitude) >
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
      // Best-effort tracking; ignore transient write failures.
    }
  }

  void _recenter() {
    setState(() => _follow = true);
    if (_me != null) {
      _map?.animateCamera(
        CameraUpdate.newLatLngZoom(
            LatLng(_me!.latitude, _me!.longitude), 16),
      );
    }
  }

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
          // Keep the route in sync with the live target.
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _maybeRoute(trip));
          return Stack(
            children: [
              Positioned.fill(child: _mapOrMessage(trip)),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                child: _RoundBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 64,
                right: 12,
                child: _EtaBanner(
                  trip: trip,
                  route: _route,
                  straight: _routeStraight,
                  locError: _locError,
                ),
              ),
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 24,
                child: _RoundBtn(
                  icon: _follow
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  onTap: _recenter,
                ),
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
          width: 6,
          patterns: _routeStraight
              ? [PatternItem.dash(24), PatternItem.gap(12)]
              : const [],
        ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _me != null
            ? LatLng(_me!.latitude, _me!.longitude)
            : LatLng(target.lat, target.lng),
        zoom: 15,
      ),
      markers: markers,
      polylines: polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      // Any manual gesture stops the camera chasing the driver.
      onCameraMoveStarted: () {
        if (_follow) setState(() => _follow = false);
      },
      onMapCreated: (m) {
        _map = m;
        if (_me == null) {
          // No fix yet — frame pickup + drop-off so the route is visible.
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

/// Top banner: where the driver is heading and the ETA/distance from the route.
class _EtaBanner extends StatelessWidget {
  final Delivery trip;
  final RouteResult? route;
  final bool straight;
  final String? locError;
  const _EtaBanner({
    required this.trip,
    required this.route,
    required this.straight,
    required this.locError,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final headingToPickup = !trip.isPickedUp;
    final label = headingToPickup ? 'To pick-up' : 'To drop-off';
    final address =
        (headingToPickup ? trip.originLabel : trip.destLabel) ?? 'Destination';

    String? eta;
    if (route != null && !straight && route!.durationText != null) {
      eta = '${route!.durationText}  ·  ${route!.distanceText}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: CtSpace.md, vertical: CtSpace.sm + 2),
      decoration: BoxDecoration(
        color: c.s1,
        borderRadius: BorderRadius.circular(CtRadius.lg),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F1E46).withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            headingToPickup ? Icons.navigation_rounded : Icons.place_rounded,
            color: headingToPickup ? c.primary : c.accent,
            size: 22,
          ),
          const SizedBox(width: CtSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: c.muted,
                      ),
                    ),
                    if (eta != null) ...[
                      const SizedBox(width: CtSpace.sm),
                      Text(
                        eta,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: c.green,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  locError ?? address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: locError != null ? c.red : c.text,
                    height: 1.3,
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
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: c.text, size: 22),
        ),
      ),
    );
  }
}
