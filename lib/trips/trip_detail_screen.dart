import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config.dart';
import '../data/db.dart';
import '../data/delivery.dart';
import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';
import 'nav_screen.dart';

/// How close (metres) the driver must be to the pickup / drop-off for the
/// Confirm pick-up / Mark delivered actions to unlock.
const double kActionGeofenceMeters = 2000;

/// One delivery, live. Map on top (pickup, drop-off, truck), journey and
/// customer details below. Streams the row so status/position changes from
/// the dispatcher or the trip itself appear without a refresh.
class TripDetailScreen extends StatefulWidget {
  final Delivery initial;
  const TripDetailScreen({super.key, required this.initial});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late final Stream<List<Map<String, dynamic>>> _stream;
  GoogleMapController? _map;
  bool _busy = false;

  // Driver's live position, used to geofence the pick-up / deliver actions.
  StreamSubscription<Position>? _posSub;
  LatLng? _me;
  bool _locBlocked = false; // GPS off or permission denied

  @override
  void initState() {
    super.initState();
    _stream = supabase
        .from('deliveries')
        .stream(primaryKey: ['id']).eq('id', widget.initial.id);
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locBlocked = true);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locBlocked = true);
        return;
      }
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).listen((p) {
        if (mounted) setState(() => _me = LatLng(p.latitude, p.longitude));
      });
    } catch (_) {
      if (mounted) setState(() => _locBlocked = true);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  /// Applies a status/timestamp change to this delivery. The realtime stream
  /// reflects the new state, so there's nothing to set locally.
  Future<bool> _apply(String id, Map<String, dynamic> patch) async {
    setState(() => _busy = true);
    try {
      await supabase.from('deliveries').update(patch).eq('id', id);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update. Try again.')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(Delivery trip) async {
    final ok = await _apply(trip.id, {
      'status': 'en_route',
      'started_at': _now(),
    });
    if (ok && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NavScreen(initial: trip)),
      );
    }
  }

  Future<void> _pickup(Delivery trip) =>
      _apply(trip.id, {'picked_up_at': _now()});

  Future<void> _deliver(Delivery trip) async {
    // Guard: goods must be picked up and a drop-off must exist first.
    if (!trip.isPickedUp) {
      _snack('Confirm pick-up before marking delivered.');
      return;
    }
    if (!trip.hasDest && trip.destLabel == null) {
      _snack('No drop-off set for this delivery yet.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as delivered?'),
        content: const Text(
          'Confirm the goods have been handed over at the drop-off. '
          'This completes the trip.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark delivered'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _apply(trip.id, {'status': 'delivered', 'delivered_at': _now()});
  }

  void _openNav(Delivery trip) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NavScreen(initial: trip)),
      );

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final trip = (snap.data?.isNotEmpty ?? false)
            ? Delivery.fromMap(snap.data!.first)
            : widget.initial;
        return Scaffold(
          appBar: CtHeader(title: trip.reference ?? 'Delivery'),
          bottomNavigationBar: _ActionBar(
            trip: trip,
            busy: _busy,
            me: _me,
            locBlocked: _locBlocked,
            onStart: () => _start(trip),
            onPickup: () => _pickup(trip),
            onDeliver: () => _deliver(trip),
            onNavigate: () => _openNav(trip),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
                CtSpace.md, CtSpace.sm, CtSpace.md, CtSpace.xl),
            children: [
              _MapCard(trip: trip, onMapCreated: (m) => _map = m),
              const SizedBox(height: CtSpace.md),
              CtCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            trip.goods ?? 'Delivery',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                        ),
                        CtStatusPill(trip.status),
                      ],
                    ),
                    const Divider(height: CtSpace.lg),
                    _Row(
                      icon: Icons.circle,
                      iconColor: c.primary,
                      label: 'Pick up',
                      value: trip.originLabel ?? 'Not set',
                    ),
                    const SizedBox(height: CtSpace.md),
                    _Row(
                      icon: Icons.place_rounded,
                      iconColor: c.accent,
                      label: 'Drop off',
                      value: trip.destLabel ?? 'Customer has not set it yet',
                    ),
                    if (trip.customerName != null ||
                        trip.customerPhone != null) ...[
                      const Divider(height: CtSpace.lg),
                      _Row(
                        icon: Icons.person_outline_rounded,
                        iconColor: c.muted2,
                        label: 'Customer',
                        value: [
                          if (trip.customerName != null) trip.customerName!,
                          if (trip.customerPhone != null) trip.customerPhone!,
                        ].join(' · '),
                      ),
                    ],
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

/// The map: pickup (brand blue), drop-off (accent orange), truck (azure) when
/// a position exists. Camera fits every marker. Falls back to a friendly
/// placeholder when the delivery has no coordinates yet.
class _MapCard extends StatelessWidget {
  final Delivery trip;
  final void Function(GoogleMapController) onMapCreated;
  const _MapCard({required this.trip, required this.onMapCreated});

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    if (!Config.mapsEnabled) {
      return _mapFrame(
        context,
        ColoredBox(
          color: c.s2,
          child: const CtMessage(
            icon: Icons.map_outlined,
            title: 'Map not configured',
            body: 'Add a Google Maps key to see pickup and drop-off on a map.',
          ),
        ),
      );
    }
    final points = <LatLng>[
      if (trip.hasOrigin) LatLng(trip.originLat!, trip.originLng!),
      if (trip.hasDest) LatLng(trip.destLat!, trip.destLng!),
      if (trip.hasPosition) LatLng(trip.lastLat!, trip.lastLng!),
    ];

    Widget inner;
    if (points.isEmpty) {
      inner = ColoredBox(
        color: c.s2,
        child: CtMessage(
          icon: Icons.map_outlined,
          title: 'No locations yet',
          body: 'The map appears when this delivery has coordinates.',
        ),
      );
    } else {
      final markers = <Marker>{
        if (trip.hasOrigin)
          Marker(
            markerId: const MarkerId('pickup'),
            position: LatLng(trip.originLat!, trip.originLng!),
            infoWindow: const InfoWindow(title: 'Pick up'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
          ),
        if (trip.hasDest)
          Marker(
            markerId: const MarkerId('dropoff'),
            position: LatLng(trip.destLat!, trip.destLng!),
            infoWindow: const InfoWindow(title: 'Drop off'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
          ),
        if (trip.hasPosition)
          Marker(
            markerId: const MarkerId('truck'),
            position: LatLng(trip.lastLat!, trip.lastLng!),
            infoWindow: const InfoWindow(title: 'Current position'),
          ),
      };
      inner = GoogleMap(
        initialCameraPosition: CameraPosition(target: points.first, zoom: 12),
        markers: markers,
        polylines: {
          if (trip.hasOrigin && trip.hasDest)
            Polyline(
              polylineId: const PolylineId('journey'),
              points: [
                LatLng(trip.originLat!, trip.originLng!),
                LatLng(trip.destLat!, trip.destLng!),
              ],
              color: c.primary,
              width: 4,
              patterns: [PatternItem.dash(24), PatternItem.gap(12)],
            ),
        },
        onMapCreated: (m) {
          onMapCreated(m);
          if (points.length > 1) {
            var minLat = points.first.latitude, maxLat = minLat;
            var minLng = points.first.longitude, maxLng = minLng;
            for (final p in points) {
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
              56,
            ));
          }
        },
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
      );
    }

    return _mapFrame(context, inner);
  }

  Widget _mapFrame(BuildContext context, Widget child) {
    final c = context.ct;
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CtRadius.xl),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// The sticky bottom bar whose action depends on where the trip is:
///  - not started        → Start trip (also opens navigation)
///  - en route, no pickup → Navigate + Confirm pick-up
///  - en route, picked up → Navigate + Mark delivered (needs a drop-off)
///  - delivered           → a "Delivered" confirmation
///  - cancelled           → nothing
class _ActionBar extends StatelessWidget {
  final Delivery trip;
  final bool busy;
  final LatLng? me;
  final bool locBlocked;
  final VoidCallback onStart;
  final VoidCallback onPickup;
  final VoidCallback onDeliver;
  final VoidCallback onNavigate;

  const _ActionBar({
    required this.trip,
    required this.busy,
    required this.me,
    required this.locBlocked,
    required this.onStart,
    required this.onPickup,
    required this.onDeliver,
    required this.onNavigate,
  });

  static String _dist(double m) =>
      m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  /// Whether an on-site action is allowed, given the target's coordinates.
  /// Returns a hint to show when it isn't. When the target has no coordinates
  /// the action can't be geofenced, so it's allowed.
  ({bool ok, String? hint}) _geofence({
    required bool hasCoords,
    double? lat,
    double? lng,
    required String place,
  }) {
    if (!hasCoords) return (ok: true, hint: null);
    if (locBlocked) {
      return (ok: false, hint: 'Turn on location to confirm at the $place.');
    }
    if (me == null) return (ok: false, hint: 'Getting your location…');
    final d = Geolocator.distanceBetween(
        me!.latitude, me!.longitude, lat!, lng!);
    if (d > kActionGeofenceMeters) {
      return (
        ok: false,
        hint: "You're ${_dist(d)} from the $place — get within "
            '${(kActionGeofenceMeters / 1000).toStringAsFixed(0)} km.',
      );
    }
    return (ok: true, hint: null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ct;

    if (trip.status == 'cancelled') return const SizedBox.shrink();

    Widget content;
    if (trip.isDone) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: c.green, size: 22),
          const SizedBox(width: CtSpace.sm),
          Text(
            'Delivered',
            style: TextStyle(
              color: c.green,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      );
    } else if (!trip.isEnRoute) {
      // pending / assigned / awaiting_dropoff — not started yet.
      content = CtPrimaryButton(
        label: 'Start trip',
        icon: Icons.play_arrow_rounded,
        loading: busy,
        onPressed: onStart,
      );
    } else if (!trip.isPickedUp) {
      final g = _geofence(
        hasCoords: trip.hasOrigin,
        lat: trip.originLat,
        lng: trip.originLng,
        place: 'pick-up',
      );
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _NavButton(onTap: busy ? null : onNavigate)),
              const SizedBox(width: CtSpace.sm),
              Expanded(
                child: CtPrimaryButton(
                  label: 'Confirm pick-up',
                  loading: busy,
                  onPressed: g.ok ? onPickup : null,
                ),
              ),
            ],
          ),
          if (g.hint != null) _Hint(g.hint!),
        ],
      );
    } else {
      final hasDrop = trip.hasDest || trip.destLabel != null;
      final g = _geofence(
        hasCoords: trip.hasDest,
        lat: trip.destLat,
        lng: trip.destLng,
        place: 'drop-off',
      );
      final canDeliver = hasDrop && g.ok;
      final hint = !hasDrop
          ? 'Waiting for the customer to set a drop-off.'
          : g.hint;
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _NavButton(onTap: busy ? null : onNavigate)),
              const SizedBox(width: CtSpace.sm),
              Expanded(
                child: CtPrimaryButton(
                  label: 'Mark delivered',
                  loading: busy,
                  onPressed: canDeliver ? onDeliver : null,
                ),
              ),
            ],
          ),
          if (hint != null) _Hint(hint),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.s1,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(CtSpace.md),
          child: content,
        ),
      ),
    );
  }
}

/// A small centred hint line under the action buttons (e.g. geofence distance).
class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Padding(
      padding: const EdgeInsets.only(top: CtSpace.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.my_location_rounded, size: 13, color: c.muted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined secondary button matching the primary's 52dp height.
class _NavButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _NavButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.navigation_rounded, size: 18),
      label: const Text('Navigate'),
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        minimumSize: const Size(0, 52),
        side: BorderSide(color: c.primary.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CtRadius.lg),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: CtSpace.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: c.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 14, color: c.text, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
