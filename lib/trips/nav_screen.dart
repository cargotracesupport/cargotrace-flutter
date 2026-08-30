import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/db.dart';
import '../data/delivery.dart';
import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';

/// Full-screen navigation view for an in-progress trip. Shows the route
/// (pickup, drop-off, and the driver's live position) filling the screen, and
/// hands off to the Google Maps app for real turn-by-turn directions.
///
/// True in-app turn-by-turn isn't provided by google_maps_flutter, so the
/// "Start navigation" button opens the same route in Google Maps — the standard
/// approach for a Flutter app.
class NavScreen extends StatefulWidget {
  final Delivery initial;
  const NavScreen({super.key, required this.initial});

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  late final Stream<List<Map<String, dynamic>>> _stream;
  GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    _stream = supabase
        .from('deliveries')
        .stream(primaryKey: ['id']).eq('id', widget.initial.id);
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  /// Opens the current target in the Google Maps app (falls back to the web
  /// maps URL if the app isn't installed).
  Future<void> _openInMaps(Delivery trip) async {
    final t = trip.navTarget;
    if (t == null) return;
    final dest = '${t.lat},${t.lng}';
    // Google Maps iOS app scheme, then a universal https link as fallback.
    final candidates = [
      Uri.parse('comgooglemaps://?daddr=$dest&directionsmode=driving'),
      Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving'),
    ];
    for (final uri in candidates) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No maps app available to navigate.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          final trip = (snap.data?.isNotEmpty ?? false)
              ? Delivery.fromMap(snap.data!.first)
              : widget.initial;
          return Stack(
            children: [
              Positioned.fill(child: _base(trip)),
              // Back button.
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                child: _RoundBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              // Bottom action sheet.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Sheet(
                  trip: trip,
                  onNavigate: () => _openInMaps(trip),
                ),
              ),
            ],
          );
        },
      ),
      backgroundColor: c.s2,
    );
  }

  Widget _base(Delivery trip) {
    final c = context.ct;
    if (!Config.mapsEnabled) {
      return ColoredBox(
        color: c.s2,
        child: const CtMessage(
          icon: Icons.map_outlined,
          title: 'Map not configured',
          body: 'Add a Google Maps key to see the route.',
        ),
      );
    }
    final target = trip.navTarget;
    final points = <LatLng>[
      if (trip.hasOrigin) LatLng(trip.originLat!, trip.originLng!),
      if (trip.hasDest) LatLng(trip.destLat!, trip.destLng!),
      if (trip.hasPosition) LatLng(trip.lastLat!, trip.lastLng!),
    ];
    if (points.isEmpty) {
      return ColoredBox(
        color: c.s2,
        child: const CtMessage(
          icon: Icons.map_outlined,
          title: 'No route yet',
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
      if (trip.hasPosition)
        Marker(
          markerId: const MarkerId('truck'),
          position: LatLng(trip.lastLat!, trip.lastLng!),
          infoWindow: const InfoWindow(title: 'You'),
        ),
    };
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: target == null
            ? points.first
            : LatLng(target.lat, target.lng),
        zoom: 13,
      ),
      markers: markers,
      polylines: {
        if (trip.hasOrigin && trip.hasDest)
          Polyline(
            polylineId: const PolylineId('route'),
            points: [
              LatLng(trip.originLat!, trip.originLng!),
              LatLng(trip.destLat!, trip.destLng!),
            ],
            color: context.ct.primary,
            width: 5,
            patterns: [PatternItem.dash(24), PatternItem.gap(12)],
          ),
      },
      onMapCreated: (m) {
        _map = m;
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
            72,
          ));
        }
      },
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
    );
  }
}

class _Sheet extends StatelessWidget {
  final Delivery trip;
  final VoidCallback onNavigate;
  const _Sheet({required this.trip, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final headingToPickup = !trip.isPickedUp;
    final label = headingToPickup ? 'Heading to pick-up' : 'Heading to drop-off';
    final address =
        (headingToPickup ? trip.originLabel : trip.destLabel) ?? 'Destination';
    return Container(
      decoration: BoxDecoration(
        color: c.s1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(CtRadius.xl)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F1E46).withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(CtSpace.md, CtSpace.md, CtSpace.md,
          CtSpace.md + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                headingToPickup ? Icons.circle : Icons.place_rounded,
                size: 16,
                color: headingToPickup ? c.primary : c.accent,
              ),
              const SizedBox(width: CtSpace.sm),
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
                    Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.text,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CtSpace.md),
          CtPrimaryButton(
            label: 'Start navigation',
            icon: Icons.navigation_rounded,
            onPressed: trip.navTarget == null ? null : onNavigate,
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
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: c.text, size: 22),
        ),
      ),
    );
  }
}
