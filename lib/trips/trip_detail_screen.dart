import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config.dart';
import '../data/db.dart';
import '../data/delivery.dart';
import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Scaffold(
      appBar: CtHeader(title: widget.initial.reference ?? 'Delivery'),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          final trip = (snap.data?.isNotEmpty ?? false)
              ? Delivery.fromMap(snap.data!.first)
              : widget.initial;
          return ListView(
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
          );
        },
      ),
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
